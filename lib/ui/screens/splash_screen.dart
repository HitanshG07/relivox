import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../blocs/discovery/discovery_bloc.dart';
import '../../services/permission_service.dart';
import '../../services/identity_service.dart';
import 'home_screen.dart';

/// Splash screen with permission flow.
/// Shows a branded intro, requests all required permissions,
/// then navigates to HomeScreen once permissions are granted.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _permService = PermissionService();
  String _status = 'Initializing…';
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    await Future.delayed(const Duration(milliseconds: 600)); // Brand splash
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    setState(() => _status = 'Requesting permissions…');
    final granted = await _permService.requestAll();
    if (!mounted) return;

    if (granted) {
      setState(() => _status = 'Starting network…');
      context.read<DiscoveryBloc>().add(StartDiscoveryEvent());
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    } else {
      setState(() {
        _status = 'Bluetooth and Location permissions are required for offline P2P.';
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = context.read<IdentityService>();
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_tethering, size: 80, color: Color(0xFF6C63FF)),
              const SizedBox(height: 24),
              const Text(
                'Relivox',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Offline P2P Communication',
                style: TextStyle(color: Colors.white54, fontSize: 14),
              ),
              const SizedBox(height: 48),
              if (!_failed) ...[
                const CircularProgressIndicator(color: Color(0xFF6C63FF)),
                const SizedBox(height: 24),
              ],
              Text(_status, textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
              if (_failed) ...[
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () async {
                    setState(() => _failed = false);
                    await _requestPermissions();
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry'),
                ),
                TextButton(
                  onPressed: () => _permService.openSettingsIfPermanentlyDenied(),
                  child: const Text('Open Settings'),
                ),
              ],
              if (!_failed) ...[
                const SizedBox(height: 12),
                Text('Identity: ${id.displayName}',
                    style: const TextStyle(color: Colors.white30, fontSize: 11)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
