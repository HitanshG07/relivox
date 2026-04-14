import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../services/database_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        backgroundColor: const Color(0xFF0D0D1A),
        appBar: AppBar(
          backgroundColor: const Color(0xFF13132B),
          title: const Text('Settings', style: TextStyle(color: Colors.white)),
          iconTheme: const IconThemeData(color: Colors.white70),
        ),
        body: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, state) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const _SectionHeader('Identity'),
                _UsernameCard(initialUsername: state.username),
                
                const SizedBox(height: 24),
                const _SectionHeader('Preferences'),
                _SettingCard(
                  child: Column(
                    children: [
                      _buildToggle(
                        context,
                        title: 'Allow Message Relay',
                        subtitle: 'Help the mesh network by relaying messages.',
                        value: state.allowRelay,
                        onChanged: (v) => context.read<SettingsBloc>().add(AllowRelayToggled(v)),
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      _buildToggle(
                        context,
                        title: 'Enable Notifications',
                        subtitle: 'Notify when new messages arrive.',
                        value: state.enableNotifications,
                        onChanged: (v) => context.read<SettingsBloc>().add(NotificationsToggled(v)),
                      ),
                      const Divider(color: Colors.white10, height: 24),
                      _buildToggle(
                        context,
                        title: 'Emergency Alerts',
                        subtitle: 'Always relay and notify emergency broadcasts.',
                        value: state.enableEmergencyAlerts,
                        onChanged: (v) => context.read<SettingsBloc>().add(EmergencyAlertsToggled(v)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const _SectionHeader('Data'),
                _SettingCard(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    title: const Text('Clear All Messages',
                        style: TextStyle(color: Colors.white)),
                    subtitle: const Text('Permanently deletes message history.',
                        style: TextStyle(color: Colors.white38, fontSize: 11)),
                    onTap: () => _confirmClear(context),
                  ),
                ),

                const SizedBox(height: 24),
                const _SectionHeader('Mesh Diagnostics'),
                _SettingCard(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Device State',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
                          Text('Manual override for testing relay rules.',
                              style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                      ),
                      DropdownButton<String>(
                        dropdownColor: const Color(0xFF13132B),
                        value: state.forcedDeviceState,
                        underline: const SizedBox(),
                        style: const TextStyle(color: Color(0xFF6C63FF), fontWeight: FontWeight.bold),
                        onChanged: (val) {
                          if (val != null) {
                            context.read<SettingsBloc>().add(DeviceStateChanged(val));
                          }
                        },
                        items: ['AUTO', 'READY', 'LIMITED', 'FULL']
                            .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                            .toList(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const _SectionHeader('About'),
                _SettingCard(
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Relivox v1.0.0',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      SizedBox(height: 4),
                      Text(
                        'Offline Peer-to-Peer Communication using Google Nearby Connections. '
                        'No internet required. No central server. All data stays on device.',
                        style: TextStyle(color: Colors.white38, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
    );
  }

  Widget _buildToggle(
    BuildContext context, {
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              Text(subtitle, style: const TextStyle(color: Colors.white38, fontSize: 11)),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF6C63FF),
          activeTrackColor: const Color(0xFF6C63FF).withValues(alpha: 0.5),
        ),
      ],
    );
  }

  Future<void> _confirmClear(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        title: const Text('Clear messages?', style: TextStyle(color: Colors.white)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: Colors.white54)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final db = DatabaseService();
      await db.clearMessages();
      await db.clearPending();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All messages cleared.')),
        );
      }
    }
  }
}

class _UsernameCard extends StatefulWidget {
  final String initialUsername;
  const _UsernameCard({required this.initialUsername});

  @override
  State<_UsernameCard> createState() => _UsernameCardState();
}

class _UsernameCardState extends State<_UsernameCard> {
  late TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialUsername);
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        _save();
      }
    });
  }

  void _save() {
    final val = _ctrl.text.trim();
    if (val.isNotEmpty) {
      context.read<SettingsBloc>().add(UsernameChanged(val));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Username', style: TextStyle(color: Colors.white60, fontSize: 12)),
          const SizedBox(height: 8),
          TextField(
            controller: _ctrl,
            focusNode: _focusNode,
            style: const TextStyle(color: Colors.white),
            onSubmitted: (_) => _save(),
            decoration: const InputDecoration(
              isDense: true,
              hintText: 'Enter your name...',
              hintStyle: TextStyle(color: Colors.white24),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF6C63FF))),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: Color(0xFF6C63FF),
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2)),
    );
  }
}

class _SettingCard extends StatelessWidget {
  final Widget child;
  const _SettingCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: child,
    );
  }
}
