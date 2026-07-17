import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_repository.dart';

class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});
  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _color = TextEditingController();
  final _year = TextEditingController();
  final _make = TextEditingController();
  final _model = TextEditingController();
  final _trim = TextEditingController();

  @override
  void dispose() {
    _color.dispose();
    _year.dispose();
    _make.dispose();
    _model.dispose();
    _trim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Vehicle')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _year,
              decoration: const InputDecoration(labelText: 'Year'),
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.next,
              validator: _validateYear,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _make,
              decoration: const InputDecoration(labelText: 'Make'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: _req,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _model,
              decoration: const InputDecoration(labelText: 'Model'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
              validator: _req,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _trim,
              decoration: const InputDecoration(labelText: 'Trim (optional)'),
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _color,
              decoration: const InputDecoration(
                labelText: 'Color',
                helperText: 'e.g. Blue, Silver, Red',
              ),
              textInputAction: TextInputAction.done,
              textCapitalization: TextCapitalization.words,
              validator: _req,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Save Vehicle'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await LocalRepository.addVehicle(
      color: _color.text.trim(),
      year: int.parse(_year.text.trim()),
      make: _make.text.trim(),
      model: _model.text.trim(),
      trim: _trim.text.trim(),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Vehicle added')),
    );
    Navigator.pop(context);
  }

  String? _req(String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null;

  String? _validateYear(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final year = int.tryParse(v.trim());
    if (year == null) return 'Enter a valid year';
    final now = DateTime.now().year;
    if (year < 1900 || year > now + 1) return 'Enter a year between 1900 and ${now + 1}';
    return null;
  }
}
