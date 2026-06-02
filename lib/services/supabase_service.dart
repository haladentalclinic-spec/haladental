import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  final SupabaseClient client = Supabase.instance.client;

  // Initialize and check database seed data (e.g. Default Clinic)
  Future<void> initializeDatabase() async {
    try {
      // Try to fetch default clinic
      final clinicResponse = await client
          .from('clinics')
          .select()
          .eq('id', AppConfig.defaultClinicId)
          .maybeSingle();

      if (clinicResponse == null) {
        // Seed default clinic
        await client.from('clinics').insert({
          'id': AppConfig.defaultClinicId,
          'name': 'Haladent Main Clinic',
          'phone': '+123456789',
          'address': 'Main Dental Center, Suite 101',
          'is_active': true,
        });
        print('Default clinic seeded successfully.');
      }
    } catch (e) {
      print('Error checking or seeding default clinic: $e');
    }
  }

  // --- AUTH SERVICES ---
  
  // Sign Up User
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    // 1. Sign up user in Supabase Auth
    final response = await client.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'phone': phone,
        'role': role,
      },
    );

    if (response.user != null) {
      // 2. Insert user into public.users table (linked via ID)
      await client.from('users').insert({
        'id': response.user!.id,
        'clinic_id': AppConfig.defaultClinicId,
        'username': email.split('@')[0],
        'full_name': fullName,
        'phone': phone,
        'role': role,
        'is_active': true,
        'patient_code': role == 'patient' ? 'PT-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}' : null,
      });
    }

    return response;
  }

  // Login User
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // Sign Out User
  Future<void> signOut() async {
    await client.auth.signOut();
  }

  // Get current user details from public.users table
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = client.auth.currentUser;
    if (user == null) return null;

    try {
      final response = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      return response;
    } catch (e) {
      print('Error getting user profile: $e');
      return null;
    }
  }

  // Update user profile
  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await client.from('users').update(data).eq('id', userId);
  }

  // --- PATIENTS SERVICES (FOR DOCTOR) ---

  // Get all patient users
  Future<List<Map<String, dynamic>>> getPatients() async {
    final response = await client
        .from('users')
        .select()
        .eq('role', 'patient')
        .order('full_name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Get all doctors/staff
  Future<List<Map<String, dynamic>>> getDoctors() async {
    final response = await client
        .from('users')
        .select()
        .eq('role', 'doctor')
        .order('full_name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Create new patient directly
  Future<void> createPatient(Map<String, dynamic> patientData) async {
    // Generate a random ID for users that don't go through auth signup
    await client.from('users').insert({
      'clinic_id': AppConfig.defaultClinicId,
      ...patientData,
      'role': 'patient',
      'is_active': true,
    });
  }

  // --- DENTAL WORKS SERVICES ---

  // Get dental works for a specific patient
  Future<List<Map<String, dynamic>>> getWorksForPatient(String patientId) async {
    final response = await client
        .from('works')
        .select('*, doctor:doctor_id(full_name)')
        .eq('patient_id', patientId)
        .order('start_date', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Get all dental works (for doctor)
  Future<List<Map<String, dynamic>>> getAllWorks() async {
    final response = await client
        .from('works')
        .select('*, patient:patient_id(full_name), doctor:doctor_id(full_name)')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  // Create dental work record
  Future<void> createWork({
    required String patientId,
    required String doctorId,
    required String title,
    required String workType,
    required List<int> teeth,
    required String teethColor,
    required String note,
    required DateTime startDate,
    required DateTime deliveryDate,
  }) async {
    final user = client.auth.currentUser;
    await client.from('works').insert({
      'clinic_id': AppConfig.defaultClinicId,
      'patient_id': patientId,
      'doctor_id': doctorId,
      'title': title,
      'work_type': workType,
      'teeth': teeth, // Stored as jsonb
      'teeth_color': teethColor,
      'note': note,
      'start_date': startDate.toIso8601String().split('T')[0],
      'delivery_date': deliveryDate.toIso8601String().split('T')[0],
      'created_by': user?.id,
    });
  }

  // Delete/Update work
  Future<void> deleteWork(String id) async {
    await client.from('works').delete().eq('id', id);
  }

  // --- REMINDERS SERVICES ---

  // Get reminders/appointments for a patient
  Future<List<Map<String, dynamic>>> getRemindersForPatient(String patientId) async {
    final response = await client
        .from('reminders')
        .select()
        .eq('patient_id', patientId)
        .order('reminder_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Get all reminders (for doctor)
  Future<List<Map<String, dynamic>>> getAllReminders() async {
    final response = await client
        .from('reminders')
        .select('*, patient:patient_id(full_name)')
        .order('reminder_date', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Create reminder
  Future<void> createReminder({
    required String patientId,
    required String title,
    required DateTime reminderDate,
    required String note,
  }) async {
    await client.from('reminders').insert({
      'clinic_id': AppConfig.defaultClinicId,
      'patient_id': patientId,
      'title': title,
      'reminder_date': reminderDate.toIso8601String(),
      'status': 'pending',
      'note': note,
    });
  }

  // Update reminder status
  Future<void> updateReminderStatus(String reminderId, String status) async {
    await client
        .from('reminders')
        .update({'status': status})
        .eq('id', reminderId);
  }

  // --- CHAT MESSAGES SERVICES ---

  // Stream chat messages between two users (patient <-> doctor)
  // Since we want standard fetching and real-time subscription
  Future<List<Map<String, dynamic>>> getMessages(String senderId, String receiverId) async {
    final response = await client
        .from('messages')
        .select()
        .or('and(sender_id.eq.$senderId,receiver_id.eq.$receiverId),and(sender_id.eq.$receiverId,receiver_id.eq.$senderId)')
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Send message
  Future<void> sendMessage({
    required String receiverId,
    required String messageText,
    String messageType = 'text',
  }) async {
    final user = client.auth.currentUser;
    if (user == null) return;
    
    // Fetch sender phone
    final userProfile = await getCurrentUserProfile();
    final senderPhone = userProfile?['phone'] ?? '';

    await client.from('messages').insert({
      'clinic_id': AppConfig.defaultClinicId,
      'sender_id': user.id,
      'receiver_id': receiverId,
      'sender_phone': senderPhone,
      'message': messageText,
      'message_type': messageType,
      'is_seen': false,
    });
  }

  // Get active chat sessions (for doctor/admin to list active patient chats)
  // It returns users who have sent or received messages
  Future<List<Map<String, dynamic>>> getChatPartners() async {
    final user = client.auth.currentUser;
    if (user == null) return [];

    // Query messages involving user
    final messages = await client
        .from('messages')
        .select('sender_id, receiver_id')
        .or('sender_id.eq.${user.id},receiver_id.eq.${user.id}');

    final partnerIds = <String>{};
    for (var msg in messages) {
      if (msg['sender_id'] != user.id) partnerIds.add(msg['sender_id']);
      if (msg['receiver_id'] != user.id) partnerIds.add(msg['receiver_id']);
    }

    if (partnerIds.isEmpty) return [];

    // Fetch details of partners
    final response = await client
        .from('users')
        .select()
        .inFilter('id', partnerIds.toList());
    return List<Map<String, dynamic>>.from(response);
  }

  // --- BANNERS SERVICES ---

  // Get active banners for home slider
  Future<List<Map<String, dynamic>>> getBanners() async {
    try {
      final response = await client
          .from('banners')
          .select()
          .eq('is_active', true);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching banners: $e');
      return [];
    }
  }
}
