import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/discovery/discovery_bloc.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../models/peer.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF13132B),
        title: const Text('Relivox Local Mesh',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const _DiscoveryHeader(),
          Expanded(
            child: BlocBuilder<DiscoveryBloc, DiscoveryState>(
              builder: (context, state) {
                if (state.peers.isEmpty) {
                  return const _EmptyDiscovery();
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.peers.length,
                  itemBuilder: (context, i) => _PeerTile(peer: state.peers[i]),
                );
              },
            ),
          ),
        ],
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
        title: Text(peer.displayName,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
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
          if (!isConnected && !isConnecting) {
            context.read<DiscoveryBloc>().add(ConnectToPeerEvent(peer.displayName));
          } else if (isConnected) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            );
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
              MaterialPageRoute(builder: (_) => const ChatScreen()),
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

    return const Icon(Icons.chevron_right, color: Colors.white12);
  }
}
