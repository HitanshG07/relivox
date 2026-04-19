import 'package:flutter/material.dart';

/// Display constants for per-message hop-count delivery badges.
class HopTickConstants {
  HopTickConstants._();

  // ── Labels ───────────────────────────────────────────
  static const String directLabel = '✓ direct';
  static const String oneHopLabel = '⇢ 1 hop';

  /// Returns the correct label for N hops (N >= 2).
  static String nHopLabel(int n) => '⇢ $n hops';

  // ── Font size ─────────────────────────────────────────
  static const double badgeFontSize = 10.0;

  // ── Colours ──────────────────────────────────────────
  /// hops == 0: direct, shown in muted grey
  static const Color directColor = Color(0xFF9E9E9E);

  /// hops == 1: one relay, shown in calm blue
  static const Color oneHopColor = Color(0xFF2196F3);

  /// hops >= 2: multi-relay, shown in amber/orange
  static const Color multiHopColor = Color(0xFFFF9800);
}
