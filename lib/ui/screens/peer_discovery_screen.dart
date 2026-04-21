import 'package:flutter/material.dart';

class PeerDiscoveryScreen extends StatelessWidget {
  const PeerDiscoveryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      appBar: AppBar(
        backgroundColor: const Color(0xFF131315),
        elevation: 0,
        title: const Row(
          children: [
            Icon(Icons.sensors, color: Color(0xFF00C896), size: 20),
            SizedBox(width: 8),
            Text(
              'RELIVOX',
              style: TextStyle(
                color: Color(0xFF00C896),
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
          ],
        ),
        actions: [
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: const Text(
                'CONNECTED',
                style: TextStyle(
                  color: Color(0xFF00C896),
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Nearby Peers',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'SCANNING... 04 PEERS DETECTED',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E0E10),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.refresh, color: Color(0xFF00C896)),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0E0E10),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF353437),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'LIST VIEW',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF00C896),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: const Text(
                              'RADAR VIEW',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _buildPeerItem(
                    name: 'NODE-X7R9',
                    hops: '1 hop away',
                    signalStrength: '-65 dBm',
                    signalIcon: Icons.signal_cellular_4_bar,
                    iconColor: const Color(0xFF00C896),
                    barColor: const Color(0xFF00C896),
                    buttonEnabled: true,
                  ),
                  const SizedBox(height: 8),
                  _buildPeerItem(
                    name: 'ALPHA-992',
                    hops: '2 hops away',
                    signalStrength: '-72 dBm',
                    signalIcon: Icons.signal_cellular_alt_2_bar,
                    iconColor: const Color(0xFF00C896),
                    barColor: const Color(0xFF00C896),
                    buttonEnabled: true,
                  ),
                  const SizedBox(height: 8),
                  _buildPeerItem(
                    name: 'ECHO-LIMA',
                    hops: '3 hops away',
                    signalStrength: '-88 dBm',
                    signalIcon: Icons.signal_cellular_alt_1_bar,
                    iconColor: const Color(0xFFFFBCA2), // Tertiary
                    barColor: const Color(0xFFFFBCA2),
                    buttonEnabled: false,
                  ),
                  const SizedBox(height: 8),
                  _buildPeerItem(
                    name: 'DELTA-V2',
                    hops: '1 hop away',
                    signalStrength: '-55 dBm',
                    signalIcon: Icons.signal_cellular_4_bar,
                    iconColor: const Color(0xFF00C896),
                    barColor: const Color(0xFF00C896),
                    buttonEnabled: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildPeerItem({
    required String name,
    required String hops,
    required String signalStrength,
    required IconData signalIcon,
    required Color iconColor,
    required Color barColor,
    required bool buttonEnabled,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1D),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              color: barColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0E0E10),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Icon(signalIcon, color: iconColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Text(
                                hops,
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: const BoxDecoration(
                                  color: Colors.grey,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                signalStrength,
                                style: TextStyle(
                                  color: iconColor,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    OutlinedButton.icon(
                      onPressed: buttonEnabled ? () {} : null,
                      icon: const Icon(Icons.chat, size: 18),
                      label: const Text(
                        'CHAT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        disabledForegroundColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: Color(0xFF131315),
        border: Border(
          top: BorderSide(
            color: Colors.white10,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, 'HOME', false, false),
          _buildNavItem(Icons.chat, 'CHAT', false, false),
          _buildNavItem(Icons.group, 'PEERS', true, false),
          _buildNavItem(Icons.emergency, 'SOS', false, true),
          _buildNavItem(Icons.settings, 'SETTINGS', false, false),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool isActive, bool isError) {
    Color itemColor = Colors.grey;
    if (isActive) {
      itemColor = const Color(0xFF00C896);
    } else if (isError) {
      itemColor = const Color(0xFFFF3B30); // Note: Original had error color, but let's stick to inactive if not active
    }

    return Container(
      padding: isActive ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : EdgeInsets.zero,
      decoration: isActive ? BoxDecoration(
        color: const Color(0xFF201F21),
        borderRadius: BorderRadius.circular(4),
      ) : null,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: itemColor,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: itemColor,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
