import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/medication_schedule.dart';
import '../providers/medication_provider.dart';

class MedicationFormScreen extends ConsumerStatefulWidget {
  const MedicationFormScreen({super.key, this.initialSchedule});

  final MedicationSchedule? initialSchedule;

  bool get isEdit => initialSchedule != null;

  @override
  ConsumerState<MedicationFormScreen> createState() =>
      _MedicationFormScreenState();
}

class _MedicationFormScreenState extends ConsumerState<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _purposeController;
  late final TextEditingController _dosageController;
  late final TextEditingController _noteController;
  late Set<MedicationWeekday> _selectedDays;
  late List<TimeOfDay> _selectedTimes;
  late bool _alarmEscalationEnabled;
  DateTime? _stopDate;
  bool _saving = false;
  bool _showScheduleValidation = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialSchedule;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _purposeController = TextEditingController(text: initial?.purpose ?? '');
    _dosageController = TextEditingController(text: initial?.dosage ?? '');
    _noteController = TextEditingController(text: initial?.note ?? '');
    _stopDate = initial?.stopDate?.toLocal();
    _selectedDays =
        initial?.activeDays.toSet() ??
        <MedicationWeekday>{
          MedicationWeekday.mon,
          MedicationWeekday.tue,
          MedicationWeekday.wed,
          MedicationWeekday.thu,
          MedicationWeekday.fri,
        };
    _selectedTimes =
        initial?.doseTimes.map(_parseTime).whereType<TimeOfDay>().toList() ??
        <TimeOfDay>[const TimeOfDay(hour: 9, minute: 0)];
    _selectedTimes.sort(_compareTimes);
    _alarmEscalationEnabled = initial?.alarmEscalationEnabled ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _purposeController.dispose();
    _dosageController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEdit = widget.isEdit;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit medication' : 'Add medication'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            children: [
              TextFormField(
                controller: _nameController,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Medicine name *',
                  hintText: 'e.g. Amlodipine',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Medicine name is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _purposeController,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'What it is for',
                  hintText: 'e.g. Blood pressure',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dosageController,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Dosage *',
                  hintText: 'e.g. 1/2 tablet, 5 mL, 2 units, 1/4 cap',
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Dosage is required.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              _StopDateField(
                stopDate: _stopDate,
                enabled: !_saving,
                onPickDate: _pickStopDate,
                onClearDate: _clearStopDate,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _noteController,
                enabled: !_saving,
                textInputAction: TextInputAction.done,
                minLines: 2,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Note (optional)',
                  hintText: 'e.g. Give after food',
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'Active days *',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: MedicationWeekday.values
                    .map((day) {
                      final selected = _selectedDays.contains(day);
                      return FilterChip(
                        label: Text(_weekdayLabel(day)),
                        selected: selected,
                        onSelected: _saving
                            ? null
                            : (value) {
                                setState(() {
                                  if (value) {
                                    _selectedDays.add(day);
                                  } else {
                                    _selectedDays.remove(day);
                                  }
                                });
                              },
                      );
                    })
                    .toList(growable: false),
              ),
              if (_showScheduleValidation && _selectedDays.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Select at least one day.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dose times *',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _saving ? null : _addTime,
                    icon: const Icon(Icons.add),
                    label: const Text('Add another time'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_selectedTimes.isNotEmpty)
                ..._buildTimeRows(theme)
              else
                Text(
                  'No dose times added yet.',
                  style: theme.textTheme.bodyLarge,
                ),
              if (_showScheduleValidation && _selectedTimes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Add at least one dose time.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _alarmEscalationEnabled,
                onChanged: _saving
                    ? null
                    : (value) {
                        setState(() {
                          _alarmEscalationEnabled = value;
                        });
                      },
                title: const Text('Enable missed-dose alarm escalation'),
                subtitle: const Text(
                  'If a dose stays unconfirmed, Guardian can escalate to alarm mode.',
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: Text(_saving ? 'Saving...' : 'Save medication'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildTimeRows(ThemeData theme) {
    final sortedTimes = _selectedTimes.toList(growable: false)
      ..sort(_compareTimes);
    return List<Widget>.generate(sortedTimes.length, (index) {
      final value = sortedTimes[index];
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFF3F5F7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.schedule, color: Color(0xFF0E5E6D)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _friendlyTime(value),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton(
                onPressed: _saving ? null : () => _replaceTime(index, value),
                child: const Text('Change'),
              ),
              IconButton(
                tooltip: 'Remove time',
                onPressed: _saving ? null : () => _removeTime(value),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      );
    });
  }

  Future<void> _addTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedTimes.add(picked);
      _selectedTimes = _dedupeAndSortTimes(_selectedTimes);
    });
  }

  Future<void> _replaceTime(int index, TimeOfDay current) async {
    final picked = await showTimePicker(context: context, initialTime: current);
    if (picked == null) {
      return;
    }
    setState(() {
      _selectedTimes[index] = picked;
      _selectedTimes = _dedupeAndSortTimes(_selectedTimes);
    });
  }

  void _removeTime(TimeOfDay value) {
    setState(() {
      _selectedTimes.remove(value);
    });
  }

  Future<void> _submit() async {
    final validForm = _formKey.currentState?.validate() ?? false;
    final validSchedule = _selectedDays.isNotEmpty && _selectedTimes.isNotEmpty;
    if (!validForm || !validSchedule) {
      setState(() {
        _showScheduleValidation = true;
      });
      return;
    }

    setState(() {
      _saving = true;
      _showScheduleValidation = false;
    });

    final existing = widget.initialSchedule;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    final schedule = MedicationSchedule(
      id: existing?.id ?? 'med-$now',
      name: _nameController.text.trim(),
      dosage: _dosageController.text.trim(),
      purpose: _purposeController.text.trim().isEmpty
          ? null
          : _purposeController.text.trim(),
      doseTimes: _selectedTimes
          .map(
            (time) =>
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
          )
          .toList(growable: false),
      activeDays: _selectedDays,
      alarmEscalationEnabled: _alarmEscalationEnabled,
      stopDate: _stopDate == null
          ? null
          : DateTime(_stopDate!.year, _stopDate!.month, _stopDate!.day),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      createdAt: existing?.createdAt,
      updatedAt: existing?.updatedAt,
    );

    try {
      final controller = ref.read(medicationControllerProvider);
      final saved = await controller.saveSchedule(schedule);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(saved);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Guardian could not save this medication yet.'),
        ),
      );
    }
  }

  Future<void> _pickStopDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _stopDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) {
      return;
    }
    setState(() {
      _stopDate = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _clearStopDate() {
    setState(() {
      _stopDate = null;
    });
  }

  String _weekdayLabel(MedicationWeekday day) {
    return switch (day) {
      MedicationWeekday.mon => 'Mon',
      MedicationWeekday.tue => 'Tue',
      MedicationWeekday.wed => 'Wed',
      MedicationWeekday.thu => 'Thu',
      MedicationWeekday.fri => 'Fri',
      MedicationWeekday.sat => 'Sat',
      MedicationWeekday.sun => 'Sun',
    };
  }

  TimeOfDay? _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  int _compareTimes(TimeOfDay a, TimeOfDay b) {
    return ((a.hour * 60) + a.minute).compareTo((b.hour * 60) + b.minute);
  }

  List<TimeOfDay> _dedupeAndSortTimes(List<TimeOfDay> values) {
    final seen = <String, TimeOfDay>{};
    for (final value in values) {
      final key = '${value.hour}:${value.minute}';
      seen[key] = value;
    }
    final deduped = seen.values.toList(growable: false)..sort(_compareTimes);
    return deduped;
  }

  String _friendlyTime(TimeOfDay value) {
    final hour = value.hour == 0
        ? 12
        : (value.hour > 12 ? value.hour - 12 : value.hour);
    final minute = value.minute.toString().padLeft(2, '0');
    final suffix = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }
}

class _StopDateField extends StatelessWidget {
  const _StopDateField({
    required this.stopDate,
    required this.enabled,
    required this.onPickDate,
    required this.onClearDate,
  });

  final DateTime? stopDate;
  final bool enabled;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  @override
  Widget build(BuildContext context) {
    final label = stopDate == null
        ? 'No stop date (reminders continue)'
        : _formatDate(stopDate!);
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Stop date (optional)',
        border: OutlineInputBorder(),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          TextButton(
            onPressed: enabled ? onPickDate : null,
            child: Text(stopDate == null ? 'Set' : 'Change'),
          ),
          if (stopDate != null)
            TextButton(
              onPressed: enabled ? onClearDate : null,
              child: const Text('Clear'),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
