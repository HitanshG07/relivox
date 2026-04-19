/// Mesh intelligence thresholds for Sprint 3.
class MeshConstants {
  MeshConstants._();

  // ── Phase 4: Multi-strategy advertising ──────────────
  /// Peer count at which mode switches from STAR → CLUSTER
  static const int clusterThreshold = 3;

  // ── Phase 5: Adaptive TTL ─────────────────────────────
  /// TTL for sparse mesh (1–2 peers)
  static const int ttlSparse = 3;

  /// TTL for normal mesh (3–5 peers) — same as current default
  static const int ttlNormal = 5;

  /// TTL for dense mesh (6–9 peers)
  static const int ttlDense = 7;

  /// TTL for very dense mesh (10+ peers)
  static const int ttlMaxDense = 10;

  /// Peer count threshold: sparse → normal
  static const int sparseLimit = 3;

  /// Peer count threshold: normal → dense
  static const int denseLimit = 6;

  /// Peer count threshold: dense → very dense
  static const int maxDenseLimit = 10;

  // ── Phase 6: Smart relay ──────────────────────────────
  /// Grace period in ms — skip newly connected peers for
  /// normal messages to reduce duplicate floods
  static const int newPeerGracePeriodMs = 2000;
}
