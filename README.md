# Relivox 🌐

> Offline peer-to-peer mesh communication for
> zero-network environments.

Relivox enables real-time text, voice, and image messaging
between Android devices using Bluetooth + Wi-Fi Direct
(Google Nearby Connections API) — **no internet, no servers,
no infrastructure required.**

## Features

| Sprint | Feature |
|--------|---------|
| S1 | SOS Panic Button — broadcasts emergency alert across mesh |
| S1 | Medical Info Card — pre-filled emergency health data |
| S2 | ACK confirmation chain — delivery receipts over mesh |
| S2 | Hop-aware ticks — relay depth indicator per message |
| S3 | Adaptive TTL — message lifetime based on hop count |
| S3 | Smart relay — avoids redundant forwarding |
| S3 | Mesh mode advertising — multi-strategy BLE + WiFi |
| S4 | Store-and-forward — retry queue with exponential backoff |
| S4 | Peer list propagation — indirect peer discovery |
| S5 | Foreground service — mesh relay survives screen lock |
| S5 | Push-to-talk voice — hold to record, release to send |
| S6 | Offline image sharing — compressed gallery pickup |

## Directory Structure

```text
lib/
├── blocs/          # BLoC state management
│   ├── chat/       # Per-peer chat events/state
│   ├── chats/      # Conversations list
│   ├── discovery/  # Nearby peer discovery
│   ├── mic/        # Medical Info Card (MIC)
│   ├── settings/   # App settings
│   └── sos/        # SOS alert flow
├── models/         # Message, Peer, MedicalInfo
├── protocols/      # GossipManager — mesh relay engine
├── services/       # CommunicationService, DatabaseService,
│                   # VoiceService, ImageService,
│                   # ForegroundService, IdentityService
└── ui/
    ├── screens/    # ChatScreen, ChatsScreen, SplashScreen
    └── widgets/    # VoiceMessageBubble, ImageMessageBubble
```

## Tech Stack

- **Flutter 3.x** — cross-platform UI
- **Google Nearby Connections** — Bluetooth + Wi-Fi Direct
- **SQLite (sqflite)** — local message persistence
- **flutter_bloc** — BLoC state management
- **flutter_foreground_task** — background relay service
- **record + just_audio** — voice recording and playback
- **image_picker + flutter_image_compress** — image sharing
- **cryptography** — message signing

## Build & Run

```bash
# Prerequisites: Flutter 3.x, Android SDK
flutter pub get
flutter run                    # debug on connected device
flutter build apk --debug      # build APK
```

**Requires Android 6.0+ (API 23+)**
Grant permissions on first launch:
- Bluetooth, Location, Microphone, Notifications, Storage

## Offline Protocol

Each message carries:
- `ttl` — decremented at every relay hop (stops loops)
- `hops` — incremented at every relay hop (visible to UI)
- `seq` — per-sender sequence number (deduplication)
- `signature` — sender identity verification

Messages with `ttl=0` are dropped (except `emergency` type).
