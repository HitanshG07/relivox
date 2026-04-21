import 'package:flutter/material.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

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
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(4),
              ),
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
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Messages',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF00C896),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.add, color: Color(0xFF004D38)),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF131315),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Search conversations...',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                        prefixIcon: Icon(Icons.search, color: Colors.white.withValues(alpha: 0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                children: [
                  _buildChatItem(
                    name: 'Bravo Team Leader',
                    time: '14:22',
                    message: 'Coordinates received. Moving to grid 4A.',
                    unreadCount: 2,
                    isWarning: false,
                    avatarWidget: const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChatItem(
                    name: 'Outpost Alpha',
                    time: '09:15',
                    message: 'Daily sync completed successfully. No anomalies detected.',
                    unreadCount: 0,
                    isWarning: false,
                    avatarWidget: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A2A2C),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'O1',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChatItem(
                    name: 'Field Medic',
                    time: 'Yesterday',
                    message: 'Supplies restocked. Awaiting further instructions.',
                    unreadCount: 0,
                    isWarning: false,
                    avatarWidget: const CircleAvatar(
                      backgroundColor: Colors.grey,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildChatItem(
                    name: 'System Alert',
                    time: 'Mon',
                    message: 'Signal degradation detected in sector 7.',
                    unreadCount: 0,
                    isWarning: true,
                    avatarWidget: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A2A2C),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.warning,
                        color: Color(0xFFFFBCA2), // Tertiary warning color
                      ),
                    ),
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

  Widget _buildChatItem({
    required String name,
    required String time,
    required String message,
    required int unreadCount,
    required bool isWarning,
    required Widget avatarWidget,
  }) {
    final nameColor = isWarning ? const Color(0xFFFFBCA2) : Colors.white;
    final timeColor = isWarning ? const Color(0xFFFFBCA2) : (unreadCount > 0 ? const Color(0xFF00C896) : Colors.grey);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1B1B1D),
        borderRadius: BorderRadius.circular(4),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            if (isWarning)
              Container(
                width: 4,
                color: const Color(0xFFFFBCA2),
              ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    avatarWidget,
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                name,
                                style: TextStyle(
                                  color: nameColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                time,
                                style: TextStyle(
                                  color: timeColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  message,
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 14,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (unreadCount > 0)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00C896),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: Text(
                                    unreadCount.toString(),
                                    style: const TextStyle(
                                      color: Color(0xFF002116),
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
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
          _buildNavItem(Icons.chat, 'CHAT', true, false),
          _buildNavItem(Icons.group, 'PEERS', false, false),
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
      itemColor = const Color(0xFFFF3B30);
    }

    return Container(
      padding: isActive ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4) : EdgeInsets.zero,
      decoration: isActive ? BoxDecoration(
        color: const Color(0xFF00C896).withValues(alpha: 0.1),
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
