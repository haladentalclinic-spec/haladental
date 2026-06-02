import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

class ReminderManagementScreen extends StatefulWidget {
  const ReminderManagementScreen({super.key});

  @override
  State<ReminderManagementScreen> createState() => _ReminderManagementScreenState();
}

class _ReminderManagementScreenState extends State<ReminderManagementScreen> {
  final SupabaseService _db = SupabaseService();
  List<Map<String, dynamic>> _reminders = [];
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getAllReminders();
      final patientsList = await _db.getPatients();
      
      setState(() {
        _reminders = list;
        _patients = patientsList;
      });
    } catch (e) {
      print('Error loading reminders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openAddReminderDialog() {
    if (_patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a patient first.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: 'Routine Dental Checkup');
    final noteCtrl = TextEditingController();
    
    String? selectedPatientId = _patients.first['id'];
    DateTime reminderDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay reminderTime = const TimeOfDay(hour: 10, minute: 0);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateSB) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Schedule New Reminder / Appointment',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 20),

                      // Patient Dropdown
                      DropdownButtonFormField<String>(
                        value: selectedPatientId,
                        decoration: const InputDecoration(labelText: 'Select Patient *', border: OutlineInputBorder()),
                        items: _patients.map((p) {
                          return DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(p['full_name']),
                          );
                        }).toList(),
                        onChanged: (v) => selectedPatientId = v,
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Title
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Reminder Title *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Date & Time Picker Row
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.calendar_month),
                              label: Text(DateFormat('MM/dd/yyyy').format(reminderDate)),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: reminderDate,
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(2028),
                                );
                                if (d != null) {
                                  setStateSB(() => reminderDate = d);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.access_time),
                              label: Text(reminderTime.format(context)),
                              onPressed: () async {
                                final t = await showTimePicker(
                                  context: context,
                                  initialTime: reminderTime,
                                );
                                if (t != null) {
                                  setStateSB(() => reminderTime = t);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Note
                      TextFormField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(labelText: 'Special Notes / Instructions', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate() || selectedPatientId == null) return;

                          final scheduledDateTime = DateTime(
                            reminderDate.year,
                            reminderDate.month,
                            reminderDate.day,
                            reminderTime.hour,
                            reminderTime.minute,
                          );

                          try {
                            await _db.createReminder(
                              patientId: selectedPatientId!,
                              title: titleCtrl.text.trim(),
                              reminderDate: scheduledDateTime,
                              note: noteCtrl.text.trim(),
                            );

                            if (mounted) {
                              Navigator.pop(context);
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Reminder scheduled successfully.'),
                                  backgroundColor: AppTheme.success,
                                ),
                              );
                            }
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Schedule Reminder', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _toggleReminderStatus(String id, String currentStatus) async {
    final newStatus = currentStatus == 'pending' ? 'completed' : 'pending';
    try {
      await _db.updateReminderStatus(id, newStatus);
      _loadData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reminders & Appointments'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _reminders.isEmpty
              ? const Center(child: Text('No scheduled appointments.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _reminders.length,
                  itemBuilder: (context, index) {
                    final r = _reminders[index];
                    final date = DateTime.parse(r['reminder_date']);
                    final formattedDate = DateFormat('MMM dd, yyyy - hh:mm a').format(date);
                    final isPending = r['status'] == 'pending';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Checkbox(
                              value: !isPending,
                              activeColor: AppTheme.success,
                              onChanged: (_) => _toggleReminderStatus(r['id'], r['status']),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    r['title'] ?? 'Reminder',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                      decoration: isPending ? null : TextDecoration.lineThrough,
                                      color: isPending ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Patient: ${r['patient']?['full_name'] ?? 'Unknown'}',
                                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isPending ? AppTheme.primaryColor : Colors.grey,
                                    ),
                                  ),
                                  if (r['note'] != null && r['note'].toString().trim().isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      r['note'],
                                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddReminderDialog,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.alarm_add_outlined),
      ),
    );
  }
}
