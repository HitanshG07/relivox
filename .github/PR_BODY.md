## Relivox v1.0 — Complete Offline P2P Mesh

This PR merges the complete `feature/chats-screen`
development branch into `main`.

### What's Included

| Sprint | SHA | Feature |
|--------|-----|---------|
| S1-P1 | 937dd96 | SOS Panic Button |
| S1-P2 | b93971c | Medical Info Card |
| S2-P3 | 8557e852 | ACK Chain Counter |
| S2-P14 | cc7406f9 | Hop-Aware Ticks |
| S3-P4/5/6 | 17ddb8b8 | Mesh Intelligence (TTL + relay + mode) |
| S4-P7/8 | 03a4db59 | Store-Forward Hardening + Peer Propagation |
| S5-P9/10 | 39a63a45 | Foreground Service + Push-to-Talk Voice |
| S6-P12 | TBD | Offline Image Sharing |

### Files Changed
- `lib/protocols/gossip_manager.dart` — mesh relay engine
- `lib/services/` — 7 service singletons
- `lib/blocs/` — 6 BLoC modules
- `lib/ui/` — screens + widgets
- `android/app/src/main/AndroidManifest.xml` — permissions
- `pubspec.yaml` — dependencies

### Testing
- `flutter analyze` → No issues found
- `flutter build apk --debug` → exit 0
- Tested on physical Android devices (API 30+)

### Reviewer Notes
- `main` branch has not been touched during development
- All commits are atomic, scoped, and verified
- No secrets or sensitive data in repository
