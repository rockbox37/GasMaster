import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/fillup.dart';
import '../services/local_repository.dart';
import '../state/app_state.dart';

class AddFillUpScreen extends ConsumerStatefulWidget {
  final String vehicleId;
  final String? fillUpId;

  const AddFillUpScreen({super.key, required this.vehicleId, this.fillUpId});

  @override
  ConsumerState<AddFillUpScreen> createState() => _AddFillUpScreenState();
}

class _AddFillUpScreenState extends ConsumerState<AddFillUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _odometer = TextEditingController();
  final _volume = TextEditingController();
  final _price = TextEditingController();
  DateTime _date = DateTime.now();
  bool _isFullTank = true;

  bool get _isEditing => widget.fillUpId != null;

  List<FillUp> get _priorFillUps {
    if (_isEditing) {
      return LocalRepository.fillUpsFor(widget.vehicleId)
          .where((f) => f.id != widget.fillUpId)
          .toList();
    }
    return LocalRepository.fillUpsFor(widget.vehicleId);
  }

  @override
  void initState() {
    super.initState();
    for (final c in [_odometer, _volume, _price]) {
      c.addListener(() => setState(() {}));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isEditing) {
        _loadExisting();
      } else {
        _prefillForNewEntry();
      }
    });
  }

  @override
  void dispose() {
    _odometer.dispose();
    _volume.dispose();
    _price.dispose();
    super.dispose();
  }

  void _loadExisting() {
    final existing = LocalRepository.getFillUp(widget.fillUpId!);
    if (existing == null || !mounted) return;
    setState(() {
      _odometer.text = existing.odometer.toString();
      _volume.text = existing.fuelVolume.toString();
      _price.text = existing.pricePaid.toString();
      _date = existing.date;
      _isFullTank = existing.isFullTank;
    });
    ref.read(unitSystemProvider.notifier).set(existing.unitSystem);
  }

  void _prefillForNewEntry() {
    final prior = _priorFillUps;
    if (prior.isEmpty || !mounted) return;
    final last = prior.last;
    setState(() {
      _odometer.text = last.odometer.toString();
    });
  }

  String? _pricePerUnitHint(bool isMetric) {
    final volume = double.tryParse(_volume.text.trim());
    final price = double.tryParse(_price.text.trim());
    if (volume == null || volume <= 0 || price == null) return null;
    final unit = isMetric ? 'L' : 'gal';
    return '\$${(price / volume).toStringAsFixed(3)} per $unit';
  }

  String? _efficiencyPreview(bool isMetric) {
    if (_isEditing) return null;
    if (!_isFullTank) return null;
    final prior = _priorFillUps;
    if (prior.isEmpty) return null;

    final last = prior.last;
    if (!last.isFullTank) return null;

    final odo = double.tryParse(_odometer.text.trim());
    final vol = double.tryParse(_volume.text.trim());
    if (odo == null || vol == null || vol <= 0) return null;

    final dist = odo - last.odometer;
    if (dist <= 0) return null;

    if (isMetric) {
      return '${((vol / dist) * 100).toStringAsFixed(1)} L/100km over ${dist.toStringAsFixed(0)} km';
    }
    return '${(dist / vol).toStringAsFixed(1)} mpg over ${dist.toStringAsFixed(0)} mi';
  }

  @override
  Widget build(BuildContext context) {
    final unit = ref.watch(unitSystemProvider);
    final isMetric = unit == 'metric';
    final priceHint = _pricePerUnitHint(isMetric);
    final efficiencyHint = _efficiencyPreview(isMetric);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Fill-up' : 'Add Fill-up')),
      body: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'imperial', label: Text('Miles/Gallons')),
                ButtonSegment(value: 'metric', label: Text('Kilometers/Liters')),
              ],
              selected: {unit},
              onSelectionChanged: (s) => ref.read(unitSystemProvider.notifier).set(s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _odometer,
              decoration: InputDecoration(
                labelText: isMetric ? 'Odometer (km)' : 'Odometer (mi)',
                helperText: _priorFillUps.isEmpty
                    ? 'First entry — efficiency starts on the next fill-up'
                    : 'Last: ${_priorFillUps.last.odometer.toStringAsFixed(1)} ${isMetric ? 'km' : 'mi'}',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: _validateOdometer,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _volume,
              decoration: InputDecoration(
                labelText: isMetric ? 'Fuel (liters)' : 'Fuel (gallons)',
                helperText: priceHint,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.next,
              validator: _reqNum,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _price,
              decoration: InputDecoration(
                labelText: 'Price paid (total)',
                helperText: priceHint == null ? 'Enter volume and price to see cost per unit' : null,
                prefixText: '\$ ',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              textInputAction: TextInputAction.done,
              validator: _reqNum,
            ),
            if (efficiencyHint != null) ...[
              const SizedBox(height: 16),
              Card(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.speed, color: theme.colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          efficiencyHint,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Full tank?'),
              subtitle: const Text(
                'MPG is only calculated between full fills. Turn off for partial top-offs.',
              ),
              value: _isFullTank,
              onChanged: (v) => setState(() => _isFullTank = v),
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Date'),
              subtitle: Text(DateFormat.yMMMd().format(_date)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_today),
                onPressed: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null) setState(() => _date = d);
                },
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: Icon(_isEditing ? Icons.check : Icons.save),
              label: Text(_isEditing ? 'Update Fill-up' : 'Save Fill-up'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final odometer = double.parse(_odometer.text.trim());
    final volume = double.parse(_volume.text.trim());
    final price = double.parse(_price.text.trim());
    final unit = ref.read(unitSystemProvider);

    if (_isEditing) {
      await LocalRepository.updateFillUp(
        id: widget.fillUpId!,
        odometer: odometer,
        fuelVolume: volume,
        pricePaid: price,
        date: _date,
        unitSystem: unit,
        isFullTank: _isFullTank,
      );
    } else {
      await LocalRepository.addFillUp(
        vehicleId: widget.vehicleId,
        odometer: odometer,
        fuelVolume: volume,
        pricePaid: price,
        date: _date,
        unitSystem: unit,
        isFullTank: _isFullTank,
      );
    }

    if (!mounted) return;
    final preview = _efficiencyPreview(unit == 'metric');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          preview != null ? 'Saved — $preview' : 'Fill-up saved',
        ),
      ),
    );
    Navigator.pop(context);
  }

  String? _reqNum(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final x = double.tryParse(v.trim());
    if (x == null || x < 0) return 'Enter a valid number';
    return null;
  }

  String? _validateOdometer(String? v) {
    final base = _reqNum(v);
    if (base != null) return base;

    final odo = double.parse(v!.trim());
    final prior = _priorFillUps;
    if (prior.isNotEmpty && odo < prior.last.odometer) {
      return 'Lower than last reading (${prior.last.odometer.toStringAsFixed(1)})';
    }
    return null;
  }
}
