import 'dart:convert';
import 'package:uuid/uuid.dart';
import 'package:equatable/equatable.dart';

// Message type taxonomy
enum MessageType { text, emergency, ack, control }

extension MessageTypeX on MessageType {
  bool get isNormal    => this == MessageType.text;
  bool get isEmergency => this == MessageType.emergency;
}

// Priority levels for protocol handling and UI emphasis
enum MessagePriority { normal, high }

// Delivery status tracked locally per device
enum DeliveryStatus { sending, sent, acked, failed }

class Message extends Equatable {
  static const String broadcastId = 'BROADCAST';
  final String id;
  final MessageType type;
  final String senderId;
  final String receiverId;
  final String? senderPubKey;
  final String timestamp; // ISO8601 UTC string
  final int ttl;
  final int hops;
  final int seq;
  final MessagePriority priority;
  final String payload;
  final String? signature;
  final DeliveryStatus deliveryStatus;

  const Message({
    required this.id,
    required this.type,
    required this.senderId,
    this.receiverId = '',
    this.senderPubKey,
    required this.timestamp,
    required this.ttl,
    required this.hops,
    required this.seq,
    required this.priority,
    required this.payload,
    this.signature,
    this.deliveryStatus = DeliveryStatus.sending,
  });

  /// Creates a new outbound message with a fresh UUID and current timestamp.
  factory Message.create({
    required String senderId,
    required String payload,
    MessageType type = MessageType.text,
    MessagePriority priority = MessagePriority.normal,
    String? senderPubKey,
    int ttl = 5,
    int seq = 0,
  }) {
    return Message(
      id: const Uuid().v4(),
      type: type,
      senderId: senderId,
      senderPubKey: senderPubKey,
      timestamp: DateTime.now().toUtc().toIso8601String(),
      ttl: ttl,
      hops: 0,
      seq: seq,
      priority: priority,
      payload: payload,
      deliveryStatus: DeliveryStatus.sending,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type.name,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_pubkey': senderPubKey,
        'timestamp': timestamp,
        'ttl': ttl,
        'hops': hops,
        'seq': seq,
        'priority': priority.name,
        'payload': payload,
        'signature': signature,
        'delivery_status': deliveryStatus.name,
      };

  factory Message.fromMap(Map<String, dynamic> map) => Message(
        id: map['id'] as String,
        type: MessageType.values.byName(map['type'] as String),
        senderId: map['sender_id'] as String,
        receiverId: map['receiver_id'] as String? ?? '',
        senderPubKey: map['sender_pubkey'] as String?,
        timestamp: map['timestamp'] as String,
        ttl: map['ttl'] as int,
        hops: map['hops'] as int,
        seq: map['seq'] as int,
        priority: MessagePriority.values.byName(map['priority'] as String),
        payload: map['payload'] as String,
        signature: map['signature'] as String?,
        deliveryStatus: DeliveryStatus.values.byName(
            map['delivery_status'] as String? ?? DeliveryStatus.sent.name),
      );

  /// Wire format: serialises for transmission over P2P channel.
  /// Only includes fields needed by receiver; deliveryStatus is local only.
  Map<String, dynamic> toWireMap() => {
        'id': id,
        'type': type.name,
        'sender_id': senderId,
        'receiver_id': receiverId,
        'sender_pubkey': senderPubKey,
        'timestamp': timestamp,
        'ttl': ttl,
        'hops': hops,
        'seq': seq,
        'priority': priority.name,
        'payload': payload,
        'signature': signature,
      };

  String toWireJson() => json.encode(toWireMap());

  factory Message.fromWireJson(String source) {
    final map = json.decode(source) as Map<String, dynamic>;
    return Message(
      id: map['id'] as String,
      type: MessageType.values.byName(map['type'] as String),
      senderId: map['sender_id'] as String,
      receiverId: map['receiver_id'] as String? ?? '',
      senderPubKey: map['sender_pubkey'] as String?,
      timestamp: map['timestamp'] as String,
      ttl: map['ttl'] as int,
      hops: map['hops'] as int,
      seq: map['seq'] as int,
      priority: MessagePriority.values.byName(map['priority'] as String),
      payload: map['payload'] as String,
      signature: map['signature'] as String?,
      deliveryStatus: DeliveryStatus.sent,
    );
  }

  Message copyWith({
    int? ttl,
    int? hops,
    DeliveryStatus? deliveryStatus,
    String? signature,
    String? receiverId,
  }) =>
      Message(
        id: id,
        type: type,
        senderId: senderId,
        receiverId: receiverId ?? this.receiverId,
        senderPubKey: senderPubKey,
        timestamp: timestamp,
        ttl: ttl ?? this.ttl,
        hops: hops ?? this.hops,
        seq: seq,
        priority: priority,
        payload: payload,
        signature: signature ?? this.signature,
        deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      );

  DateTime get parsedTimestamp => DateTime.parse(timestamp);

  /// Alias for payload — used by new notification
  /// and settings systems.
  String get content => payload;

  @override
  List<Object?> get props => [id, senderId, seq];
}
