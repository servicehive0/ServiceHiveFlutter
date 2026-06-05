import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

enum AuthStatus { initial, loading, authenticated, unauthenticated, otpPending, error }

const _kBase = kBaseUrl;

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String token;
  final String city;
  final String area;
  final String address;
  final double? latitude;
  final double? longitude;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.token,
    this.city      = '',
    this.area      = '',
    this.address   = '',
    this.latitude,
    this.longitude,
  });

  bool get hasLocation => latitude != null && longitude != null;

  UserModel copyWith({
    String? name, String? phone, String? city, String? area, String? address,
    double? latitude, double? longitude,
  }) => UserModel(
    id: id, email: email, role: role, token: token,
    name:      name      ?? this.name,
    phone:     phone     ?? this.phone,
    city:      city      ?? this.city,
    area:      area      ?? this.area,
    address:   address   ?? this.address,
    latitude:  latitude  ?? this.latitude,
    longitude: longitude ?? this.longitude,
  );
}

class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String?    _errorMessage;
  String?    _pendingEmail;

  AuthStatus get status          => _status;
  UserModel? get user            => _user;
  String?    get errorMessage    => _errorMessage;
  String?    get pendingEmail    => _pendingEmail;
  bool       get isAuthenticated => _status == AuthStatus.authenticated;

  AuthProvider() { _restoreSession(); }

  // ─── Restore session ────────────────────────────────────────────
  Future<void> _restoreSession() async {
    final p = await SharedPreferences.getInstance();
    final token = p.getString('token');
    final id    = p.getString('u_id');
    final name  = p.getString('u_name');
    final email = p.getString('u_email');
    final role  = p.getString('u_role');
    if (token != null && id != null && name != null && email != null && role != null) {
      _user = UserModel(
        id: id, name: name, email: email, role: role, token: token,
        phone:     p.getString('u_phone')   ?? '',
        city:      p.getString('u_city')    ?? '',
        area:      p.getString('u_area')    ?? '',
        address:   p.getString('u_address') ?? '',
        latitude:  p.getDouble('u_lat'),
        longitude: p.getDouble('u_lng'),
      );
      _status = AuthStatus.authenticated;
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  // ─── Login ──────────────────────────────────────────────────────
  Future<bool> login(String email, String password, {String role = 'user'}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$_kBase/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    email.trim().toLowerCase(),
          'password': password.trim(),
          'role':     role,
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        final u     = data['user'] as Map<String, dynamic>;
        final token = data['token'] as String;
        // Basic user from login response
        _user = UserModel(
          id: u['id'].toString(), name: u['name'] as String,
          email: u['email'] as String, role: u['role'] as String,
          phone: '', token: token,
        );
        _status = AuthStatus.authenticated;
        // Fetch full profile (phone, city, area, address)
        await _fetchFullProfile(token);
        notifyListeners();
        return true;
      }

      if (data['needsVerification'] == true) {
        _pendingEmail = (data['email'] as String?) ?? email.trim();
        _status       = AuthStatus.otpPending;
        _errorMessage = data['message'] as String?;
        notifyListeners();
        return false;
      }

      _status       = AuthStatus.error;
      _errorMessage = data['message'] as String? ?? 'Login failed. Check email/password.';
      notifyListeners();
      return false;

    } catch (e) {
      _status       = AuthStatus.error;
      _errorMessage = 'Cannot reach server. Make sure you are on the same WiFi.';
      notifyListeners();
      return false;
    }
  }

  // ─── Register ───────────────────────────────────────────────────
  Future<bool> register({
    required String name, required String email,
    required String phone, required String password,
    required String role,
    String city = '', String area = '', String address = '',
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$_kBase/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name.trim(), 'email': email.trim().toLowerCase(),
          'password': password.trim(), 'role': role,
          'phone': phone.trim(), 'city': city.trim(),
          'area': area.trim(), 'address': address.trim(),
        }),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        _pendingEmail = (data['email'] as String?) ?? email.trim();
        _status       = AuthStatus.otpPending;
        notifyListeners();
        return true;
      }

      _status       = AuthStatus.error;
      _errorMessage = data['message'] as String? ?? 'Registration failed.';
      notifyListeners();
      return false;

    } catch (e) {
      _status       = AuthStatus.error;
      _errorMessage = 'Cannot reach server. Make sure you are on the same WiFi.';
      notifyListeners();
      return false;
    }
  }

  // ─── Verify OTP ─────────────────────────────────────────────────
  Future<bool> verifyOtp(String otp) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final res = await http.post(
        Uri.parse('$_kBase/auth/verify-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': _pendingEmail ?? '', 'otp': otp.trim()}),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;

      if (data['success'] == true) {
        final u     = data['user'] as Map<String, dynamic>;
        final token = data['token'] as String;
        _user = UserModel(
          id: u['id'].toString(), name: u['name'] as String,
          email: u['email'] as String, role: u['role'] as String,
          phone: '', token: token,
        );
        _pendingEmail = null;
        _status = AuthStatus.authenticated;
        await _fetchFullProfile(token);
        notifyListeners();
        return true;
      }

      _status       = AuthStatus.otpPending;
      _errorMessage = data['message'] as String? ?? 'Invalid OTP.';
      notifyListeners();
      return false;

    } catch (e) {
      _status       = AuthStatus.otpPending;
      _errorMessage = 'Cannot reach server.';
      notifyListeners();
      return false;
    }
  }

  // ─── Fetch full profile from backend ────────────────────────────
  Future<void> _fetchFullProfile(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$_kBase/users/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 10));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true && _user != null) {
        final d = data['data'] as Map<String, dynamic>;
        _user = _user!.copyWith(
          phone:     d['phone']     as String? ?? '',
          city:      d['city']      as String? ?? '',
          area:      d['area']      as String? ?? '',
          address:   d['address']   as String? ?? '',
          latitude:  (d['latitude']  as num?)?.toDouble(),
          longitude: (d['longitude'] as num?)?.toDouble(),
        );
        await _saveSession();
      }
    } catch (_) {}
  }

  // ─── Update profile ──────────────────────────────────────────────
  Future<bool> updateProfile({
    required String name,
    String  phone     = '',
    String  city      = '',
    String  area      = '',
    String  address   = '',
    double? latitude,
    double? longitude,
  }) async {
    if (_user == null) return false;
    try {
      final body = <String, dynamic>{
        'name': name.trim(), 'phone': phone.trim(),
        'city': city.trim(), 'area':  area.trim(),
        'address': address.trim(),
      };
      if (latitude  != null) body['latitude']  = latitude;
      if (longitude != null) body['longitude'] = longitude;

      final res = await http.put(
        Uri.parse('$_kBase/users/me'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer ${_user!.token}',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['success'] == true) {
        _user = _user!.copyWith(
          name: name.trim(), phone: phone.trim(),
          city: city.trim(), area: area.trim(), address: address.trim(),
          latitude: latitude, longitude: longitude,
        );
        await _saveSession();
        notifyListeners();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  // ─── Send OTP for password change ───────────────────────────────
  Future<bool> sendPasswordOtp(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$_kBase/auth/forgot-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (_) { return false; }
  }

  // ─── Verify OTP + set new password ──────────────────────────────
  Future<String?> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      // Step 1: verify OTP
      final v = await http.post(
        Uri.parse('$_kBase/auth/verify-reset-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase(), 'otp': otp.trim()}),
      ).timeout(const Duration(seconds: 15));
      final vData = jsonDecode(v.body) as Map<String, dynamic>;
      if (vData['success'] != true) {
        return vData['message'] as String? ?? 'Invalid or expired OTP';
      }

      // Step 2: reset password
      final r = await http.post(
        Uri.parse('$_kBase/auth/reset-password'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email':    email.trim().toLowerCase(),
          'otp':      otp.trim(),
          'password': newPassword.trim(),
        }),
      ).timeout(const Duration(seconds: 15));
      final rData = jsonDecode(r.body) as Map<String, dynamic>;
      if (rData['success'] == true) return null; // null = success
      return rData['message'] as String? ?? 'Failed to change password';
    } catch (_) {
      return 'Cannot reach server.';
    }
  }

  // ─── Resend OTP ─────────────────────────────────────────────────
  Future<bool> resendOtp(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$_kBase/auth/resend-otp'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim().toLowerCase()}),
      ).timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      return data['success'] == true;
    } catch (_) { return false; }
  }

  // ─── Logout ─────────────────────────────────────────────────────
  Future<void> logout() async {
    final p = await SharedPreferences.getInstance();
    await p.clear();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  // ─── Persist session ─────────────────────────────────────────────
  Future<void> _saveSession() async {
    if (_user == null) return;
    final p = await SharedPreferences.getInstance();
    await p.setString('token',     _user!.token);
    await p.setString('u_id',      _user!.id);
    await p.setString('u_name',    _user!.name);
    await p.setString('u_email',   _user!.email);
    await p.setString('u_role',    _user!.role);
    await p.setString('u_phone',   _user!.phone);
    await p.setString('u_city',    _user!.city);
    await p.setString('u_area',    _user!.area);
    await p.setString('u_address', _user!.address);
    if (_user!.latitude  != null) await p.setDouble('u_lat', _user!.latitude!);
    if (_user!.longitude != null) await p.setDouble('u_lng', _user!.longitude!);
  }
}
