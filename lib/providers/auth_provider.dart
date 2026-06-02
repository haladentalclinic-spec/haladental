import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseService _db = SupabaseService();
  
  User? _authUser;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = false;
  String? _errorMessage;

  AuthProvider() {
    // Listen for auth state updates
    _db.client.auth.onAuthStateChange.listen((data) async {
      _authUser = data.session?.user;
      if (_authUser != null) {
        await fetchUserProfile();
      } else {
        _userProfile = null;
        notifyListeners();
      }
    });

    // Check current session on startup
    _authUser = _db.client.auth.currentUser;
    if (_authUser != null) {
      fetchUserProfile();
    }
  }

  // Getters
  User? get authUser => _authUser;
  Map<String, dynamic>? get userProfile => _userProfile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  
  bool get isAuthenticated => _authUser != null;
  bool get isDoctor => _userProfile != null && _userProfile!['role'] == 'doctor';
  bool get isAdmin => _userProfile != null && _userProfile!['role'] == 'admin';
  String get userRole => _userProfile?['role'] ?? 'patient';

  // Clear errors
  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  // Fetch user profile from public.users table
  Future<void> fetchUserProfile() async {
    _isLoading = true;
    notifyListeners();
    try {
      _userProfile = await _db.getCurrentUserProfile();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Login
  Future<bool> login(String email, String password) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _db.signIn(email: email, password: password);
      await fetchUserProfile();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = "An unexpected error occurred during login.";
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Register
  Future<bool> register({
    required String email,
    required String password,
    required String fullName,
    required String phone,
    required String role,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _db.signUp(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
        role: role,
      );
      // Wait for auth sync and profile fetching
      await Future.delayed(const Duration(milliseconds: 500));
      await fetchUserProfile();
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Sign out
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _db.signOut();
      _authUser = null;
      _userProfile = null;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
