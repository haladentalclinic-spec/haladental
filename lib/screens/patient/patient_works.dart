import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';

class PatientWorks extends StatefulWidget {
  const PatientWorks({super.key});

  @override
  State<PatientWorks> createState() => _PatientWorksState();
}

class _PatientWorksState extends State<PatientWorks> {
  final SupabaseService _db = SupabaseService();
  List<Map<String, dynamic>> _works = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadWorks();
  }

  Future<void> _loadWorks() async {
    setState(() => _isLoading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).authUser;
    if (user != null) {
      try {
        final data = await _db.getWorksForPatient(user.id);
        setState(() {
          _works = data;
        });
      } catch (e) {
        print('Error loading patient works: $e');
      }
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadWorks,
      color: AppTheme.primaryColor,
      child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _works.isEmpty
              ? _buildEmptyState(isDark)
              : ListView.builder(
                  padding: const EdgeInsets.all(20.0),
                  itemCount: _works.length,
                  itemBuilder: (context, index) {
                    final work = _works[index];
                    final startDate = DateTime.parse(work['start_date']);
                    final delivDate = DateTime.parse(work['delivery_date']);
                    
                    // Parse teeth details from JSON
                    List<int> teeth = [];
                    try {
                      if (work['teeth'] != null) {
                        if (work['teeth'] is List) {
                          teeth = List<int>.from(work['teeth']);
                        } else if (work['teeth'] is String) {
                          teeth = List<int>.from(json.decode(work['teeth']));
                        }
                      }
                    } catch (e) {
                      print('Error decoding teeth JSON: $e');
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Treatment Title & Work Type
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    work['title'] ?? 'Dental Work',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryColor.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    work['work_type'] ?? 'General',
                                    style: const TextStyle(
                                      color: AppTheme.primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 24),
                            
                            // Doctor name
                            Row(
                              children: [
                                const Icon(Icons.medical_services_outlined, size: 16, color: AppTheme.primaryColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Doctor: ${work['doctor']?['full_name'] ?? 'Clinic Dentist'}',
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),

                            // Tooth Details Graphic
                            if (teeth.isNotEmpty) ...[
                              const Text(
                                'Treated Teeth Map:',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              _buildTeethGraphic(teeth),
                              const SizedBox(height: 12),
                            ],

                            // Teeth shade color
                            if (work['teeth_color'] != null && work['teeth_color'].toString().trim().isNotEmpty) ...[
                              Row(
                                children: [
                                  const Icon(Icons.palette_outlined, size: 16, color: Colors.blueGrey),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tooth Color Shade: ${work['teeth_color']}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],

                            // Dates Row
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _buildDateCol('Start Date', startDate),
                                _buildDateCol('Delivery Date', delivDate),
                              ],
                            ),
                            
                            // Clinical Note
                            if (work['note'] != null && work['note'].toString().trim().isNotEmpty) ...[
                              const SizedBox(height: 16),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Dentist Note:',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      work['note'],
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ]
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shield_moon_outlined,
              size: 70,
              color: AppTheme.primaryColor.withOpacity(0.3),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Treatments Registered',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your custom dental works, crowns, veneers, and general treatments will appear here once recorded by the dentist.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Graphical Teeth map representation
  Widget _buildTeethGraphic(List<int> highlightedTeeth) {
    // Standard layout: Upper teeth 1 to 16, Lower teeth 17 to 32
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Upper jaw
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(16, (index) {
              final toothNum = index + 1;
              final isHighlighted = highlightedTeeth.contains(toothNum);
              return _buildToothBubble(toothNum, isHighlighted);
            }),
          ),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Colors.grey),
          const SizedBox(height: 6),
          // Lower jaw
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(16, (index) {
              final toothNum = 32 - index; // Layout 17 to 32 right to left
              final isHighlighted = highlightedTeeth.contains(toothNum);
              return _buildToothBubble(toothNum, isHighlighted);
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildToothBubble(int toothNum, bool isHighlighted) {
    return Tooltip(
      message: 'Tooth #$toothNum',
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isHighlighted ? AppTheme.secondaryColor : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: isHighlighted ? AppTheme.primaryColor : Colors.grey.shade400,
            width: isHighlighted ? 1.5 : 1,
          ),
        ),
        child: Text(
          '$toothNum',
          style: TextStyle(
            fontSize: 7,
            fontWeight: FontWeight.bold,
            color: isHighlighted ? AppTheme.primaryColor : Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildDateCol(String label, DateTime date) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
        Text(
          DateFormat('MMM dd, yyyy').format(date),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
