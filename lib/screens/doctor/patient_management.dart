import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

class PatientManagementScreen extends StatefulWidget {
  const PatientManagementScreen({super.key});

  @override
  State<PatientManagementScreen> createState() => _PatientManagementScreenState();
}

class _PatientManagementScreenState extends State<PatientManagementScreen> {
  final SupabaseService _db = SupabaseService();
  List<Map<String, dynamic>> _patients = [];
  List<Map<String, dynamic>> _filteredPatients = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchController.addListener(_filterPatients);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      final list = await _db.getPatients();
      setState(() {
        _patients = list;
        _filteredPatients = list;
      });
    } catch (e) {
      print('Error loading patients: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _filterPatients() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredPatients = _patients.where((p) {
        final name = (p['full_name'] ?? '').toLowerCase();
        final phone = (p['phone'] ?? '').toLowerCase();
        final code = (p['patient_code'] ?? '').toLowerCase();
        return name.contains(query) || phone.contains(query) || code.contains(query);
      }).toList();
    });
  }

  void _openPatientDialog({Map<String, dynamic>? patient}) {
    final isNew = patient == null;
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: patient?['full_name']);
    final phoneCtrl = TextEditingController(text: patient?['phone']);
    final ageCtrl = TextEditingController(text: patient?['age']?.toString());
    final genderCtrl = TextEditingController(text: patient?['gender'] ?? 'Male');
    final bloodCtrl = TextEditingController(text: patient?['blood_type']);
    final allergiesCtrl = TextEditingController(text: patient?['allergies']);
    final diseaseCtrl = TextEditingController(text: patient?['disease']);
    final noteCtrl = TextEditingController(text: patient?['note']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
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
                  Text(
                    isNew ? 'Register New Patient' : 'Edit Patient Record',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(labelText: 'Full Name *', border: OutlineInputBorder()),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  
                  TextFormField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(labelText: 'Phone Number', border: OutlineInputBorder()),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: ageCtrl,
                          decoration: const InputDecoration(labelText: 'Age', border: OutlineInputBorder()),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: genderCtrl.text,
                          decoration: const InputDecoration(labelText: 'Gender', border: OutlineInputBorder()),
                          items: const [
                            DropdownMenuItem(value: 'Male', child: Text('Male')),
                            DropdownMenuItem(value: 'Female', child: Text('Female')),
                          ],
                          onChanged: (v) => genderCtrl.text = v ?? 'Male',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: bloodCtrl,
                    decoration: const InputDecoration(labelText: 'Blood Type (e.g. O+, A-)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: allergiesCtrl,
                    decoration: const InputDecoration(labelText: 'Allergies', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: diseaseCtrl,
                    decoration: const InputDecoration(labelText: 'Chronic Diseases', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(labelText: 'Clinical Notes', border: OutlineInputBorder()),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      
                      final data = {
                        'full_name': nameCtrl.text.trim(),
                        'phone': phoneCtrl.text.trim(),
                        'age': int.tryParse(ageCtrl.text),
                        'gender': genderCtrl.text,
                        'blood_type': bloodCtrl.text.trim(),
                        'allergies': allergiesCtrl.text.trim(),
                        'disease': diseaseCtrl.text.trim(),
                        'note': noteCtrl.text.trim(),
                      };

                      try {
                        if (isNew) {
                          await _db.createPatient({
                            ...data,
                            'patient_code': 'PT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}',
                          });
                        } else {
                          await _db.updateUserProfile(patient['id'], data);
                        }
                        
                        if (mounted) {
                          Navigator.pop(context);
                          _loadPatients();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(isNew ? 'Patient created successfully.' : 'Patient record updated.'),
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
                    child: const Text('Save Record', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patients Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadPatients,
          )
        ],
      ),
      body: Column(
        children: [
          // Search box
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search patients by name, code, or phone...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : _filteredPatients.isEmpty
                    ? const Center(child: Text('No patient records found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _filteredPatients.length,
                        itemBuilder: (context, index) {
                          final p = _filteredPatients[index];
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _openPatientDialog(patient: p),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          p['full_name'] ?? 'No Name',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        if (p['patient_code'] != null)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              p['patient_code'],
                                              style: const TextStyle(
                                                color: AppTheme.primaryColor,
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Icon(Icons.phone_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text(p['phone'] ?? 'No phone'),
                                        const SizedBox(width: 16),
                                        const Icon(Icons.male_outlined, size: 14, color: Colors.grey),
                                        const SizedBox(width: 6),
                                        Text('${p['gender'] ?? 'Unspecified'}, ${p['age'] ?? '??'} yrs'),
                                      ],
                                    ),
                                    
                                    // Medical Warnings section (Allergies/Diseases)
                                    if ((p['allergies'] != null && p['allergies'].toString().trim().isNotEmpty) ||
                                        (p['disease'] != null && p['disease'].toString().trim().isNotEmpty)) ...[
                                      const Divider(height: 16),
                                      Row(
                                        children: [
                                          if (p['allergies'] != null && p['allergies'].toString().trim().isNotEmpty)
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Allergy: ${p['allergies']}',
                                                      style: const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          if (p['disease'] != null && p['disease'].toString().trim().isNotEmpty)
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.healing_outlined, size: 16, color: Colors.redAccent),
                                                  const SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      'Disease: ${p['disease']}',
                                                      style: const TextStyle(fontSize: 12, overflow: TextOverflow.ellipsis),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openPatientDialog(),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
