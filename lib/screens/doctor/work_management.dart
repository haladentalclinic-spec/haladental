import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

class WorkManagementScreen extends StatefulWidget {
  const WorkManagementScreen({super.key});

  @override
  State<WorkManagementScreen> createState() => _WorkManagementScreenState();
}

class _WorkManagementScreenState extends State<WorkManagementScreen> {
  final SupabaseService _db = SupabaseService();
  List<Map<String, dynamic>> _works = [];
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _doctors = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final worksList = await _db.getAllWorks();
      final patientsList = await _db.getPatients();
      final doctorsList = await _db.getDoctors();
      
      setState(() {
        _works = worksList;
        _patients = patientsList;
        _doctors = doctorsList;
      });
    } catch (e) {
      print('Error loading dental works data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _openAddWorkDialog() {
    if (_patients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please register a patient first before adding treatments.')),
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController();
    final typeCtrl = TextEditingController(text: 'Crown');
    final shadeCtrl = TextEditingController(text: 'A1');
    final noteCtrl = TextEditingController();
    
    String? selectedPatientId = _patients.first['id'];
    String? selectedDoctorId = _doctors.isNotEmpty ? _doctors.first['id'] : null;
    
    DateTime startDate = DateTime.now();
    DateTime deliveryDate = DateTime.now().add(const Duration(days: 7));
    
    List<int> selectedTeeth = [];

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
                        'New Dental Treatment / Lab Order',
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
                            child: Text('${p['full_name']} (${p['patient_code'] ?? 'No Code'})'),
                          );
                        }).toList(),
                        onChanged: (v) => selectedPatientId = v,
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Doctor Dropdown
                      if (_doctors.isNotEmpty) ...[
                        DropdownButtonFormField<String>(
                          value: selectedDoctorId,
                          decoration: const InputDecoration(labelText: 'Assigned Dentist *', border: OutlineInputBorder()),
                          items: _doctors.map((d) {
                            return DropdownMenuItem(
                              value: d['id'].toString(),
                              child: Text(d['full_name'] ?? 'Dentist'),
                            );
                          }).toList(),
                          onChanged: (v) => selectedDoctorId = v,
                          validator: (v) => v == null ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Title
                      TextFormField(
                        controller: titleCtrl,
                        decoration: const InputDecoration(labelText: 'Treatment Title (e.g. Zirconia Crown, Root Canal) *', border: OutlineInputBorder()),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),

                      // Work Type & Tooth Shade shade
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: typeCtrl,
                              decoration: const InputDecoration(labelText: 'Work Type', border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: shadeCtrl,
                              decoration: const InputDecoration(labelText: 'Shade (e.g. A1, B2, BL2)', border: OutlineInputBorder()),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Interactive Dental Teeth Selector
                      const Text(
                        'Select Treated Teeth:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      
                      // Upper jaw selector
                      const Text('Upper Jaw (Teeth 1-16)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(16, (index) {
                          final toothNum = index + 1;
                          final isSel = selectedTeeth.contains(toothNum);
                          return _buildToothToggle(toothNum, isSel, () {
                            setStateSB(() {
                              if (isSel) {
                                selectedTeeth.remove(toothNum);
                              } else {
                                selectedTeeth.add(toothNum);
                              }
                            });
                          });
                        }),
                      ),
                      const SizedBox(height: 8),

                      // Lower jaw selector
                      const Text('Lower Jaw (Teeth 17-32)', style: TextStyle(fontSize: 10, color: Colors.grey)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(16, (index) {
                          final toothNum = 32 - index;
                          final isSel = selectedTeeth.contains(toothNum);
                          return _buildToothToggle(toothNum, isSel, () {
                            setStateSB(() {
                              if (isSel) {
                                selectedTeeth.remove(toothNum);
                              } else {
                                selectedTeeth.add(toothNum);
                              }
                            });
                          });
                        }),
                      ),
                      const SizedBox(height: 16),

                      // Dates Pickers
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.date_range),
                              label: Text('Start: ${DateFormat('MM/dd').format(startDate)}'),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: startDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) {
                                  setStateSB(() => startDate = d);
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.delivery_dining_outlined),
                              label: Text('Delivery: ${DateFormat('MM/dd').format(deliveryDate)}'),
                              onPressed: () async {
                                final d = await showDatePicker(
                                  context: context,
                                  initialDate: deliveryDate,
                                  firstDate: DateTime(2025),
                                  lastDate: DateTime(2030),
                                );
                                if (d != null) {
                                  setStateSB(() => deliveryDate = d);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Notes
                      TextFormField(
                        controller: noteCtrl,
                        decoration: const InputDecoration(labelText: 'Instructions / Notes', border: OutlineInputBorder()),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 20),

                      ElevatedButton(
                        onPressed: () async {
                          if (!formKey.currentState!.validate() || selectedDoctorId == null || selectedPatientId == null) return;
                          
                          try {
                            await _db.createWork(
                              patientId: selectedPatientId!,
                              doctorId: selectedDoctorId!,
                              title: titleCtrl.text.trim(),
                              workType: typeCtrl.text.trim(),
                              teeth: selectedTeeth,
                              teethColor: shadeCtrl.text.trim(),
                              note: noteCtrl.text.trim(),
                              startDate: startDate,
                              deliveryDate: deliveryDate,
                            );

                            if (mounted) {
                              Navigator.pop(context);
                              _loadData();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Dental work recorded successfully.'),
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
                        child: const Text('Add Treatment', style: TextStyle(fontWeight: FontWeight.bold)),
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

  Widget _buildToothToggle(int toothNum, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.secondaryColor : Colors.grey.shade200,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.grey.shade400,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$toothNum',
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            color: isSelected ? AppTheme.primaryColor : Colors.black,
          ),
        ),
      ),
    );
  }

  void _deleteWork(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Treatment Record'),
        content: const Text('Are you sure you want to delete this treatment record from history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await _db.deleteWork(id);
        _loadData();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Treatments & Works'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _works.isEmpty
              ? const Center(child: Text('No treatments registered yet.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16.0),
                  itemCount: _works.length,
                  itemBuilder: (context, index) {
                    final w = _works[index];
                    final start = DateTime.parse(w['start_date']);
                    final deliv = DateTime.parse(w['delivery_date']);
                    
                    List<int> teeth = [];
                    try {
                      if (w['teeth'] != null) {
                        if (w['teeth'] is List) {
                          teeth = List<int>.from(w['teeth']);
                        } else if (w['teeth'] is String) {
                          teeth = List<int>.from(json.decode(w['teeth']));
                        }
                      }
                    } catch (e) {}

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    w['title'] ?? 'Treatment',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 20),
                                  onPressed: () => _deleteWork(w['id']),
                                ),
                              ],
                            ),
                            
                            // Patient Info
                            Text(
                              'Patient: ${w['patient']?['full_name'] ?? 'Unknown'}',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            Text(
                              'Dentist: ${w['doctor']?['full_name'] ?? 'Staff Dentist'}',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            const SizedBox(height: 8),

                            // Teeth Graphic Indicator
                            if (teeth.isNotEmpty) ...[
                              Text(
                                'Treated Teeth: ${teeth.join(', ')}',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                              ),
                              const SizedBox(height: 6),
                            ],

                            if (w['teeth_color'] != null && w['teeth_color'].toString().trim().isNotEmpty) ...[
                              Text('Teeth Shade: ${w['teeth_color']}', style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 6),
                            ],

                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Start: ${DateFormat('MM/dd/yyyy').format(start)}', style: const TextStyle(fontSize: 12)),
                                Text('Delivery: ${DateFormat('MM/dd/yyyy').format(deliv)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.primaryColor)),
                              ],
                            ),

                            if (w['note'] != null && w['note'].toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(w['note'], style: const TextStyle(fontSize: 12)),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddWorkDialog,
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_circle_outline),
      ),
    );
  }
}
