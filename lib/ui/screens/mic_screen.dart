import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/mic/mic_bloc.dart';
import '../../blocs/mic/mic_event.dart';
import '../../blocs/mic/mic_state.dart';
import '../../constants/mic_constants.dart';
import '../../models/medical_info.dart';

/// Medical Info Card screen — view and edit personal emergency profile.
class MicScreen extends StatelessWidget {
  const MicScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MicBloc, MicState>(
      builder: (context, state) {
        if (state.status == MicStatus.initial ||
            state.status == MicStatus.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final info = state.info;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Medical Info Card'),
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => _openEditSheet(context, info),
            child: const Icon(Icons.edit),
          ),
          body: info.isEmpty
              ? const Center(
                  child: Text(
                    'Tap ✏️ to fill your medical card',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _MicCard(info: info),
                  ],
                ),
        );
      },
    );
  }

  void _openEditSheet(BuildContext context, MedicalInfo current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<MicBloc>(),
        child: _MicEditForm(initial: current),
      ),
    );
  }
}

class _MicCard extends StatelessWidget {
  final MedicalInfo info;
  const _MicCard({required this.info});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (info.name.isNotEmpty) _Row(label: 'Name', value: info.name),
            if (info.bloodType.isNotEmpty)
              _Row(label: 'Blood Type', value: info.bloodType),
            if (info.allergies.isNotEmpty)
              _Row(label: 'Allergies', value: info.allergies),
            if (info.contactName.isNotEmpty)
              _Row(label: 'Emergency Contact', value: info.contactName),
            if (info.contactPhone.isNotEmpty)
              _Row(label: 'Contact Phone', value: info.contactPhone),
            if (info.notes.isNotEmpty) _Row(label: 'Notes', value: info.notes),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _MicEditForm extends StatefulWidget {
  final MedicalInfo initial;
  const _MicEditForm({required this.initial});

  @override
  State<_MicEditForm> createState() => _MicEditFormState();
}

class _MicEditFormState extends State<_MicEditForm> {
  late final TextEditingController _name;
  late final TextEditingController _allergies;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  late final TextEditingController _notes;
  String _bloodType = '';

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initial.name);
    _allergies = TextEditingController(text: widget.initial.allergies);
    _contactName = TextEditingController(text: widget.initial.contactName);
    _contactPhone = TextEditingController(text: widget.initial.contactPhone);
    _notes = TextEditingController(text: widget.initial.notes);
    _bloodType = widget.initial.bloodType;
  }

  @override
  void dispose() {
    _name.dispose();
    _allergies.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _save(BuildContext context) {
    final info = MedicalInfo(
      name: _name.text.trim(),
      bloodType: _bloodType,
      allergies: _allergies.text.trim(),
      contactName: _contactName.text.trim(),
      contactPhone: _contactPhone.text.trim(),
      notes: _notes.text.trim(),
    );
    context.read<MicBloc>().add(SaveMicEvent(info));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Edit Medical Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: MicConstants.maxNameLength,
              decoration: const InputDecoration(labelText: 'Full Name'),
            ),
            DropdownButtonFormField<String>(
              initialValue: _bloodType.isEmpty ? null : _bloodType,
              decoration: const InputDecoration(labelText: 'Blood Type'),
              items: MicConstants.bloodTypes
                  .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                  .toList(),
              onChanged: (v) => setState(() => _bloodType = v ?? ''),
            ),
            TextField(
              controller: _allergies,
              decoration: const InputDecoration(labelText: 'Allergies'),
            ),
            TextField(
              controller: _contactName,
              maxLength: MicConstants.maxContactLength,
              decoration:
                  const InputDecoration(labelText: 'Emergency Contact Name'),
            ),
            TextField(
              controller: _contactPhone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Emergency Contact Phone'),
            ),
            TextField(
              controller: _notes,
              maxLength: MicConstants.maxNotesLength,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Medical Notes'),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _save(context),
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
