import 'package:flutter/material.dart';

class VoiceRecorderScreen extends StatelessWidget {
  const VoiceRecorderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0C),
      body: Stack(
        children: [
          // Background content (Dimmed chat thread)
          Opacity(
            opacity: 0.3,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildBackgroundMessage(
                      'UNIT 04 - 10:42Z',
                      'Perimeter secured. Awaiting further instructions on vector 7.',
                      false,
                    ),
                    const SizedBox(height: 16),
                    _buildBackgroundMessage(
                      'ME - 10:44Z',
                      'Copy that. Proceeding to rally point beta. Maintain comms silence unless necessary.',
                      true,
                    ),
                    const SizedBox(height: 16),
                    _buildBackgroundMessage(
                      'UNIT 04 - 10:45Z',
                      '[Voice message]',
                      false,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Overlay
          Container(
            color: const Color(0xFF0E0E10).withValues(alpha: 0.8),
          ),

          // Bottom Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              height: MediaQuery.of(context).size.height * 0.65,
              decoration: BoxDecoration(
                color: const Color(0xFF201F21),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.1),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 40,
                    offset: const Offset(0, -10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag Handle Area
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Center(
                          child: Container(
                            width: 48,
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {},
                                borderRadius: BorderRadius.circular(4),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    children: const [
                                      Icon(Icons.close, color: Colors.grey, size: 16),
                                      SizedBox(width: 4),
                                      Text(
                                        'DISCARD',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Content
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Header Status
                          Column(
                            children: [
                              const Text(
                                'VOICE MESSAGE',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2.0,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF3B30).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: const Color(0xFFFF3B30).withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFFFF3B30),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'RECORDING',
                                      style: TextStyle(
                                        color: Color(0xFFFF3B30),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          // Visualizer & Timer
                          Column(
                            children: [
                              SizedBox(
                                height: 80,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    _buildWaveBar(8, 0.4),
                                    _buildWaveBar(16, 0.5),
                                    _buildWaveBar(32, 0.6),
                                    _buildWaveBar(48, 0.7),
                                    _buildWaveBar(24, 1.0),
                                    _buildWaveBar(64, 1.0),
                                    _buildWaveBar(40, 1.0),
                                    _buildWaveBar(80, 1.0),
                                    _buildWaveBar(56, 1.0),
                                    _buildWaveBar(24, 1.0),
                                    _buildWaveBar(48, 1.0),
                                    _buildWaveBar(16, 0.8),
                                    _buildWaveBar(32, 0.6),
                                    _buildWaveBar(8, 0.4),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Text(
                                '00:08',
                                style: TextStyle(
                                  color: Color(0xFF00C896),
                                  fontSize: 32,
                                  fontFamily: 'monospace',
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          // Controls
                          Stack(
                            alignment: Alignment.center,
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                right: -24,
                                child: Row(
                                  children: const [
                                    Text(
                                      'SLIDE LEFT TO CANCEL',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    SizedBox(width: 4),
                                    Icon(
                                      Icons.keyboard_double_arrow_left,
                                      color: Colors.grey,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(right: 80),
                                child: Column(
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          width: 100,
                                          height: 100,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF3B30).withValues(alpha: 0.4),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        Container(
                                          width: 80,
                                          height: 80,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A0005),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: const Color(0xFFFF3B30),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFFF3B30).withValues(alpha: 0.5),
                                                blurRadius: 20,
                                              ),
                                            ],
                                          ),
                                          child: const Icon(
                                            Icons.mic,
                                            color: Color(0xFFFF3B30),
                                            size: 32,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'RELEASE TO SEND',
                                      style: TextStyle(
                                        color: Colors.grey,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundMessage(String sender, String text, bool isMine) {
    return Column(
      crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          sender,
          style: TextStyle(
            color: isMine ? const Color(0xFF00C896) : Colors.grey,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMine ? const Color(0xFF00C896).withValues(alpha: 0.2) : const Color(0xFF1B1B1D),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: text == '[Voice message]'
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.mic, color: Color(0xFF00C896), size: 16),
                    SizedBox(width: 8),
                    Text(
                      '00:14',
                      style: TextStyle(
                        color: Color(0xFF00C896),
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                )
              : Text(
                  text,
                  style: TextStyle(
                    color: isMine ? const Color(0xFF00C896) : Colors.white,
                    fontSize: 14,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildWaveBar(double height, double opacity) {
    return Container(
      width: 6,
      height: height,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF00C896).withValues(alpha: opacity),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}
