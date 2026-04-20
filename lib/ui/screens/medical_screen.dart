import 'package:flutter/material.dart';
import '../../services/medical_service.dart';

class MedicalScreen extends StatefulWidget {
  const MedicalScreen({super.key});

  @override
  State<MedicalScreen> createState() => _MedicalScreenState();
}

class _MedicalScreenState extends State<MedicalScreen> {
  final TextEditingController _bloodController = TextEditingController();
  final TextEditingController _allergiesController = TextEditingController();
  final TextEditingController _conditionsController = TextEditingController();
  final TextEditingController _contactNameController = TextEditingController();
  final TextEditingController _contactPhoneController = TextEditingController();
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final data = await MedicalService.load();
    setState(() {
      _bloodController.text = data['bloodGroup'] ?? '';
      _allergiesController.text = data['allergies'] ?? '';
      _conditionsController.text = data['conditions'] ?? '';
      _contactNameController.text = data['contactName'] ?? '';
      _contactPhoneController.text = data['contactPhone'] ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    await MedicalService.save(data: {
      'bloodGroup': _bloodController.text,
      'allergies': _allergiesController.text,
      'conditions': _conditionsController.text,
      'contactName': _contactNameController.text,
      'contactPhone': _contactPhoneController.text,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medical profile saved ✅'),
          backgroundColor: Color(0xFF6C63FF),
        ),
      );
    }
  }

  @override
  void dispose() {
    _bloodController.dispose();
    _allergiesController.dispose();
    _conditionsController.dispose();
    _contactNameController.dispose();
    _contactPhoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D0D1A),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF6C63FF))),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Emergency Medical Profile',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'This information will be attached to all outgoing emergency broadcasts.',
              style: TextStyle(color: Colors.white54, fontSize: 14),
            ),
            const SizedBox(height: 24),
            _buildCard([
              _buildTextField('Blood Group', _bloodController, 'e.g. A+'),
              _buildTextField('Allergies', _allergiesController, 'e.g. Penicillin'),
              _buildTextField('Medical Conditions', _conditionsController, 'e.g. Asthma'),
            ]),
            const SizedBox(height: 20),
            const Text(
              'Emergency Contact',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _buildCard([
              _buildTextField('Contact Name', _contactNameController, 'e.g. Mom'),
              _buildTextField('Contact Phone', _contactPhoneController, 'e.g. 9876543210', keyboardType: TextInputType.phone),
            ]),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _saveData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6C63FF),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'SAVE PROFILE',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13132B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String hint, {TextInputType? keyboardType}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          const SizedBox(height: 4),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white12),
              enabledBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Colors.white12),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF6C63FF)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
