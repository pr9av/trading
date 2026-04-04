import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../config/api_config.dart';

final authProvider = ChangeNotifierProvider<AuthService>((ref) => AuthService());

class AuthService with ChangeNotifier {
  final String _baseUrl = '${ApiConfig.baseUrl}/auth';
  String? _token;
  String? _userId;
  String? _role;
  bool _isLoading = false;

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  String? get role => _role;
  bool get isLoading => _isLoading;

  AuthService() {
    _loadSession();
  }

  Future<void> _loadSession() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('access_token');
    _userId = prefs.getString('user_id');
    _role = prefs.getString('role');
    notifyListeners();
  }

  Future<String?> login(String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': username, 'password': password}),
      );

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final data = body['data'] as Map<String, dynamic>;
        _token = data['access_token'];
        _userId = data['user_id']?.toString();
        _role = data['role'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('access_token', _token!);
        await prefs.setString('user_id', _userId!);
        await prefs.setString('role', _role ?? 'user');

        _isLoading = false;
        notifyListeners();
        return null; // success
      } else {
        final body = jsonDecode(response.body);
        // Express error shape: { error, message } or rate limiter shape
        final msg = body['message'] ?? body['error'] ?? 'Login failed';
        _isLoading = false;
        notifyListeners();
        return msg as String;
      }
    } catch (e) {
      debugPrint('Login error: $e');
      _isLoading = false;
      notifyListeners();
      return 'Connection error: $e';
    }
  }

  Future<String?> register(String email, String username, String password) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'username': username,
          'password': password,
        }),
      );

      _isLoading = false;
      notifyListeners();
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        return null; // Success
      } else {
        final data = jsonDecode(response.body);
        // Express error shape: { error, code, message }
        return data['message'] ?? data['error'] ?? 'Registration failed';
      }
    } catch (e) {
      debugPrint('Registration error: $e');
      _isLoading = false;
      notifyListeners();
      return 'Debug Error: $e';
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _role = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }
}
