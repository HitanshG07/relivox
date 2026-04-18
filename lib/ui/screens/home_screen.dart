import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/discovery/discovery_bloc.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../services/communication_service.dart';
import '../../models/message.dart';
import '../../models/peer.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'chats_screen.dart';
import '../../services/database_service.dart';
import 'package:url_launcher/url_launcher.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13132B),
        title: Text(
          _currentIndex == 0 ? 'Chats' : 'Relivox Mesh',
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          BlocBuilder<DiscoveryBloc, DiscoveryState>(
            builder: (context, state) {
              final hasAlerts = state.broadcastEmergencyLog.isNotEmpty;
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.notifications_active,
                      color: hasAlerts ? Colors.redAccent : Colors.white38,
                    ),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BroadcastLogScreen(
                          log: state.broadcastEmergencyLog,
                        ),
                      ),
                    ),
                  ),
                  if (hasAlerts)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
          if (_currentIndex == 1)
            BlocBuilder<DiscoveryBloc, DiscoveryState>(
              builder: (context, state) {
                return IconButton(
                  icon: state.isRefreshing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white54,
                          ),
                        )
                      : const Icon(Icons.refresh, color: Colors.white70),
                  onPressed: state.isRefreshing
                      ? null
                      : () => context
                          .read<DiscoveryBloc>()
                          .add(ManualRefreshEvent()),
                );
              },
            ),

        ],
      ),
      body: Column(
        children: [
          const _EmergencyBanner(),
          if (_currentIndex == 1) const _DiscoveryHeader(),
          Expanded(
            child: _currentIndex == 0
                ? const ChatsScreen()
                : BlocBuilder<DiscoveryBloc, DiscoveryState>(
                    builder: (context, state) {
                      if (state.peers.isEmpty) {
                        return const _EmptyDiscovery();
                      }
                      return ListView.builder(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: state.peers.length,
                        itemBuilder: (context, i) =>
                            _PeerTile(peer: state.peers[i]),
                      );
                    },
                  ),
          ),
          if (_currentIndex == 1) const _BroadcastTrigger(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF13132B),
        selectedItemColor: const Color(0xFF6C63FF),
        unselectedItemColor: Colors.white38,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.radar),
            activeIcon: Icon(Icons.radar),
            label: 'Devices',
          ),
        ],
      ),
    );
  }
}

class _EmergencyBanner extends StatelessWidget {
  const _EmergencyBanner();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      builder: (context, state) {
        final msg = state.latestBroadcastEmergency;
        if (msg == null) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.redAccent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.redAccent.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.campaign, color: Colors.white, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FutureBuilder<String?>(
                      future: DatabaseService().getDisplayName(msg.senderId),
                      builder: (context, snapshot) {
                        final name = (snapshot.data != null && snapshot.data!.isNotEmpty)
                            ? snapshot.data!
                            : msg.senderId.substring(msg.senderId.length - 4).toUpperCase();
                        return Text(
                          'BROADCAST ALERT from $name',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 2),
                    Builder(builder: (context) {
                      // Split payload: clean text above, geo URI below
                      final geoMatch =
                          RegExp(r'geo:[^\s]+').firstMatch(msg.payload);
                      final cleanText = msg.payload
                          .replaceAll(
                              RegExp(r'\nTap to open offline map:\ngeo:[^\s]+'),
                              '')
                          .trim();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cleanText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (geoMatch != null) ...[
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final uri =
                                    Uri.parse(geoMatch.group(0)!);
                                if (await canLaunchUrl(uri)) {
                                  launchUrl(uri);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.15),
                                  borderRadius:
                                      BorderRadius.circular(8),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.map,
                                        color: Colors.white,
                                        size: 16),
                                    SizedBox(width: 6),
                                    Text(
                                      '📍 Open Offline Map',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      );
                    }),

                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => context.read<DiscoveryBloc>().add(ClearBroadcastEmergencyEvent()),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BroadcastTrigger extends StatelessWidget {
  const _BroadcastTrigger();

  // Step 1 — show type selector bottom sheet
  void _showTypeSelector(BuildContext context) {
    final types = [
      ('FIRE', '🔥', 'Fire / Hazard',      Colors.deepOrange),
      ('MEDC', '🚑', 'Medical Emergency',  Colors.redAccent),
      ('TRAP', '🆘', 'Trapped / Immobile', Colors.orange),
      ('GEN',  '⚠️', 'General Emergency',  Colors.yellow),
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13132B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What type of emergency?',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...types.map((t) {
              final (code, emoji, label, color) = t;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(emoji, style: const TextStyle(fontSize: 28)),
                title: Text(
                  label,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  // Microtask ensures bottom sheet is fully dismissed
                  // before the dialog tries to mount on the navigator stack
                  Future.microtask(
                    () => _showMessageDialog(context, code, '$emoji $label'),
                  );
                },

              );
            }),
          ],
        ),
      ),
    );
  }

  // Step 2 — show message text field with type already chosen
  void _showMessageDialog(
      BuildContext context, String typeCode, String typeLabel) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF13132B),
        title: Text(
          typeLabel,
          style: const TextStyle(color: Colors.redAccent),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Add details (optional)...',
            hintStyle: TextStyle(color: Colors.white24),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white24),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('CANCEL',
                style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              final text = controller.text.trim().isNotEmpty
                  ? controller.text.trim()
                  : typeLabel; // fallback if user types nothing
              context.read<CommunicationService>().sendUserMessage(
                    text,
                    Message.broadcastId,
                    MessageType.emergency,
                    emergencyType: typeCode, // ← passes FIRE/MEDC/TRAP/GEN
                  );
              Navigator.pop(ctx);
            },
            child: const Text('SEND TO ALL',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => _showTypeSelector(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.campaign),
          label: const Text('📢 SEND BROADCAST EMERGENCY',
              style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

class _DiscoveryHeader extends StatelessWidget {
  const _DiscoveryHeader();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoveryBloc, DiscoveryState>(
      builder: (context, state) {
        final discovered = state.peers.length;
        final connected =
            state.peers.where((p) => p.status == PeerStatus.connected).length;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _StatChip(
                label: 'Discovered',
                value: '$discovered',
                color: Colors.blueAccent,
              ),
              const SizedBox(width: 12),
              _StatChip(
                label: 'Connected',
                value: '$connected',
                color: Colors.greenAccent,
              ),
              const Spacer(),
              BlocBuilder<SettingsBloc, SettingsState>(
                builder: (context, state) {
                  return Text(
                    state.username,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(width: 6),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _EmptyDiscovery extends StatelessWidget {
  const _EmptyDiscovery();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.radar, size: 48, color: Colors.blueAccent.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          const Text('Searching for peers...',
              style: TextStyle(color: Colors.white38)),
          const SizedBox(height: 8),
          const Text('Make sure others have Relivox open',
              style: TextStyle(color: Colors.white24, fontSize: 12)),
        ],
      ),
    );
  }
}

class _PeerTile extends StatelessWidget {
  final Peer peer;
  const _PeerTile({required this.peer});

  @override
  Widget build(BuildContext context) {
    final bool isConnected = peer.status == PeerStatus.connected;
    final bool isConnecting = peer.status == PeerStatus.connecting;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white12,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: isConnected
              ? Colors.greenAccent.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.05),
          child: Icon(
            isConnected ? Icons.link : Icons.person_outline,
            color: isConnected ? Colors.greenAccent : Colors.white60,
          ),
        ),
        title: Text(
          peer.displayName.isNotEmpty 
            ? peer.displayName 
            : (peer.deviceId ?? peer.endpointId),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          isConnected
              ? 'Connected via mesh'
              : (isConnecting ? 'Connecting...' : 'Tap to connect'),
          style: TextStyle(
            color: isConnected ? Colors.greenAccent.withValues(alpha: 0.7) : Colors.white38,
            fontSize: 12,
          ),
        ),
        trailing: _buildTrailing(context, peer),
        onTap: () {
          if (isConnected) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(targetPeer: peer)),
            );
          } else if (!isConnecting) {
            context.read<DiscoveryBloc>().add(ConnectToPeerEvent(peer.displayName));
          }
        },
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, Peer peer) {
    if (peer.status == PeerStatus.connected) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF6C63FF)),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatScreen(targetPeer: peer)),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.link_off, color: Colors.white24),
            onPressed: () =>
                context.read<DiscoveryBloc>().add(DisconnectFromPeerEvent(peer.displayName)),
          ),
        ],
      );
    }

    if (peer.status == PeerStatus.connecting) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white24),
      );
    }

    return IconButton(
      icon: const Icon(Icons.link, color: Colors.blueAccent),
      tooltip: 'Connect',
      onPressed: () =>
          context.read<DiscoveryBloc>().add(ConnectToPeerEvent(peer.displayName)),
    );
  }
}

class BroadcastLogScreen extends StatelessWidget {
  final List<Message> log;
  const BroadcastLogScreen({super.key, required this.log});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13132B),
        title: const Row(
          children: [
            Icon(Icons.notifications_active, color: Colors.redAccent, size: 20),
            SizedBox(width: 8),
            Text('Broadcast Alerts',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        iconTheme: const IconThemeData(color: Colors.white70),
        actions: [
          TextButton(
            onPressed: () {
              context.read<DiscoveryBloc>().add(ClearBroadcastLogEvent());
              Navigator.pop(context);
            },
            child: const Text('CLEAR ALL',
                style: TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),
        ],
      ),
      body: log.isEmpty
          ? const Center(
              child: Text('No broadcast alerts received.',
                  style: TextStyle(color: Colors.white38)),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: log.length,
              itemBuilder: (context, i) {
                final msg = log[log.length - 1 - i]; // newest first
                final time = msg.parsedTimestamp.toLocal();
                final timeStr =
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.redAccent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.campaign,
                              color: Colors.redAccent, size: 16),
                          const SizedBox(width: 6),
                          FutureBuilder<String?>(
                            future: DatabaseService().getDisplayName(msg.senderId),
                            builder: (context, snapshot) {
                              final name = (snapshot.data != null && snapshot.data!.isNotEmpty)
                                  ? snapshot.data!
                                  : msg.senderId.substring(msg.senderId.length - 6).toUpperCase();
                              return Text(
                                'FROM: $name',
                                style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold),
                              );
                            },
                          ),
                          const Spacer(),
                          Text(timeStr,
                              style: const TextStyle(
                                  color: Colors.white38, fontSize: 10)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Builder(builder: (context) {
                        final geoMatch =
                            RegExp(r'geo:[^\s]+').firstMatch(msg.payload);
                        final cleanText = msg.payload
                            .replaceAll(
                                RegExp(r'\nTap to open offline map:\ngeo:[^\s]+'),
                                '')
                            .trim();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              cleanText,
                              style: const TextStyle(
                                  color: Colors.white, fontSize: 14),
                            ),
                            if (geoMatch != null) ...[
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final uri =
                                      Uri.parse(geoMatch.group(0)!);
                                  if (await canLaunchUrl(uri)) {
                                    launchUrl(uri);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.redAccent
                                        .withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.map,
                                          color: Colors.redAccent,
                                          size: 16),
                                      SizedBox(width: 6),
                                      Text(
                                        '📍 Open Offline Map',
                                        style: TextStyle(
                                            color: Colors.redAccent,
                                            fontSize: 13),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      }),

                    ],
                  ),
                );
              },
            ),
    );
  }
}
