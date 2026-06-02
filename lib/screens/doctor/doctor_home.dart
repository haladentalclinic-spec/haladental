import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';
import '../../theme.dart';
import 'patient_management.dart';
import 'work_management.dart';
import 'reminder_management.dart';
import 'doctor_chat.dart';

class DoctorHome extends StatefulWidget {
  const DoctorHome({super.key});

  @override
  State<DoctorHome> createState() => _DoctorHomeState();
}

class _DoctorHomeState extends State<DoctorHome> {
  final SupabaseService _db = SupabaseService();
  int _patientCount = 0;
  int _worksCount = 0;
  int _remindersCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoading = true);
    try {
      final patients = await _db.getPatients();
      final works = await _db.getAllWorks();
      final reminders = await _db.getAllReminders();
      
      setState(() {
        _patientCount = patients.length;
        _worksCount = works.length;
        _remindersCount = reminders.length;
      });
    } catch (e) {
      print('Error loading doctor dashboard stats: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = Provider.of<AuthProvider>(context).userProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _loadStats,
      color: AppTheme.primaryColor,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Dentist Row
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.15),
                  child: const Icon(
                    Icons.medical_services,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dentist Dashboard,',
                        style: TextStyle(
                          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        profile?['full_name'] ?? 'Doctor',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'CLINIC STAFF',
                    style: TextStyle(
                      color: AppTheme.success,
                      fontWeight: FontWeight.bold,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),

            // Statistics Dashboard Grid
            _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
                : GridView.count(
                    crossAxisCount: 3,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.9,
                    children: [
                      _buildStatCard(
                        'Patients',
                        '$_patientCount',
                        Icons.people_alt_outlined,
                        Colors.blue,
                      ),
                      _buildStatCard(
                        'Dental Works',
                        '$_worksCount',
                        Icons.shield_outlined,
                        AppTheme.primaryColor,
                      ),
                      _buildStatCard(
                        'Reminders',
                        '$_remindersCount',
                        Icons.alarm_on_outlined,
                        Colors.amber,
                      ),
                    ],
                  ),
            const SizedBox(height: 30),

            // Clinical Administration Menu Grid
            const Text(
              'Clinic Administration',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            _buildMenuTile(
              context,
              'Patients Directory',
              'Manage patient files, medical records, and info.',
              Icons.people_outline_rounded,
              Colors.blue,
              const PatientManagementScreen(),
            ),
            const SizedBox(height: 16),
            
            _buildMenuTile(
              context,
              'Treatments & Works',
              'Create lab orders, select teeth indices, and shades.',
              Icons.shield_outlined,
              AppTheme.primaryColor,
              const WorkManagementScreen(),
            ),
            const SizedBox(height: 16),

            _buildMenuTile(
              context,
              'Reminders & Checks',
              'Schedule appointments and follow-up reminders.',
              Icons.alarm_outlined,
              Colors.amber,
              const ReminderManagementScreen(),
            ),
            const SizedBox(height: 16),

            _buildMenuTile(
              context,
              'Clinic Messages',
              'Chat directly with registered patients in real-time.',
              Icons.forum_outlined,
              Colors.purple,
              const DoctorChatInboxScreen(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String count, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              count,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 10,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTile(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    Color color,
    Widget targetPage,
  ) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => targetPage),
          ).then((_) => _loadStats()); // Refresh stats on return
        },
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
