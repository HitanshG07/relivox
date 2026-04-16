import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:logger/logger.dart';
import '../models/message.dart';

final _log = Logger(printer: PrettyPrinter(methodCount: 0));

/// SQLite persistence layer for Relivox.
/// Schema version 1 → 2 migrations are handled inside _onUpgrade.
class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static const _dbName = 'relivox.db';
  static const _dbVersion = 2;
  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE messages (
        id              TEXT PRIMARY KEY,
        type            TEXT NOT NULL,
        sender_id       TEXT NOT NULL,
        receiver_id     TEXT NOT NULL DEFAULT '',
        sender_pubkey   TEXT,
        timestamp       TEXT NOT NULL,
        ttl             INTEGER NOT NULL,
        hops            INTEGER NOT NULL,
        seq             INTEGER NOT NULL,
        priority        TEXT NOT NULL,
        payload         TEXT NOT NULL,
        signature       TEXT,
        delivery_status TEXT NOT NULL DEFAULT 'sent'
      )
    ''');

    await db.execute('''
      CREATE TABLE pending_outbound (
        id              TEXT PRIMARY KEY,
        type            TEXT NOT NULL,
        sender_id       TEXT NOT NULL,
        receiver_id     TEXT NOT NULL DEFAULT '',
        sender_pubkey   TEXT,
        timestamp       TEXT NOT NULL,
        ttl             INTEGER NOT NULL,
        hops            INTEGER NOT NULL,
        seq             INTEGER NOT NULL,
        priority        TEXT NOT NULL,
        payload         TEXT NOT NULL,
        signature       TEXT,
        delivery_status TEXT NOT NULL DEFAULT 'sending',
        retry_count     INTEGER NOT NULL DEFAULT 0,
        next_retry_ms   INTEGER NOT NULL DEFAULT 0
      )
    ''');

    _log.i('Database schema v$version created');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    _log.i('Upgrading DB from $oldVersion to $newVersion');
    if (oldVersion < 2) {
      await db.execute("ALTER TABLE messages ADD COLUMN receiver_id TEXT NOT NULL DEFAULT ''");
      await db.execute("ALTER TABLE pending_outbound ADD COLUMN receiver_id TEXT NOT NULL DEFAULT ''");
      _log.i('Added receiver_id column to tables');
    }
  }

  // ── Messages (received + sent archive) ──────────────────────────────────────

  Future<void> upsertMessage(Message msg) async {
    final d = await db;
    await d.insert('messages', msg.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Message>> getAllMessages() async {
    final d = await db;
    final rows = await d.query('messages', orderBy: 'timestamp DESC');
    return rows.map((r) => Message.fromMap(r)).toList();
  }

  Future<void> updateDeliveryStatus(String id, DeliveryStatus status) async {
    final d = await db;
    await d.update(
      'messages',
      {'delivery_status': status.name},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clearMessages() async {
    final d = await db;
    await d.delete('messages');
  }

  // ── Pending outbound (retry queue) ──────────────────────────────────────────

  Future<void> insertPending(Message msg) async {
    final d = await db;
    final map = Map<String, dynamic>.from(msg.toMap());
    map['retry_count'] = 0;
    map['next_retry_ms'] = 0;
    await d.insert('pending_outbound', map,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getDuePending() async {
    final d = await db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return d.query(
      'pending_outbound',
      where: 'next_retry_ms <= ?',
      whereArgs: [nowMs],
    );
  }

  Future<void> incrementRetry(String id, int retryCount) async {
    final d = await db;
    // Exponential backoff: 2^retry * 1000ms, capped at 30s
    final delayMs = (1000 * (1 << retryCount.clamp(0, 5))).clamp(0, 30000);
    final nextMs = DateTime.now().millisecondsSinceEpoch + delayMs;
    await d.update(
      'pending_outbound',
      {'retry_count': retryCount + 1, 'next_retry_ms': nextMs},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deletePending(String id) async {
    final d = await db;
    await d.delete('pending_outbound', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearPending() async {
    final d = await db;
    await d.delete('pending_outbound');
  }

  // ── Part 3 Additions ──────────────────────────────────────────────────────

  Future<void> savePendingMessage(Message msg) async {
    await insertPending(msg);
  }

  Future<void> removePendingMessage(String id) async {
    await deletePending(id);
  }

  Future<List<Message>> getPendingMessages() async {
    final d = await db;
    final rows = await d.query('pending_outbound');
    return rows.map((r) => Message.fromMap(r)).toList();
  }

  /// Returns the most recent non-ACK message for each unique
  /// conversation partner. Used to build the Chats list.
  Future<List<Message>> getConversationSummaries() async {
    final d = await db;
    // Get all non-ack messages ordered newest first
    final rows = await d.query(
      'messages',
      where: "type != 'ack'",
      orderBy: 'timestamp DESC',
    );
    final messages = rows.map((r) => Message.fromMap(r)).toList();

    // Deduplicate: keep only first (newest) message per peer
    final seen = <String>{};
    final result = <Message>[];
    for (final msg in messages) {
      // faster logic: use the non-local ID
      final key = msg.receiverId.isEmpty || msg.receiverId == '__BROADCAST__'
          ? msg.senderId
          : msg.receiverId;
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(msg);
      }
    }
    return result;
  }
}
