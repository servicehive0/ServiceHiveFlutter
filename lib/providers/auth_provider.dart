import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/error_helper.dart';
import '../services/push_service.dart';

const _cloudName   = 'dbuhxbyq1';
const _uploadPreset = 'servicehive_unsigned';

enum AuthStatus { initial, loading, authenticated, unauthenticated, otpPending, pendingApproval, error }

// ─── UserModel ────────────────────────────────────────────────────────────────
// `token` is a computed getter so every existing screen that reads user.token
// still compiles and always receives the live Supabase session access token.

class UserModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String role;
  final String city;
  final String area;
  final String address;
  final double? latitude;
  final double? longitude;
  final String? avatarUrl;
  final bool showPhone;
  final bool showEmail;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    this.city      = '',
    this.area      = '',
    this.address   = '',
    this.latitude,
    this.longitude,
    this.avatarUrl,
    this.showPhone    = true,
    this.showEmail    = true,
  });

  bool get hasLocation => latitude != null && longitude != null;

  // Supabase manages JWTs automatically — returns the current live access token.
  String get token =>
      Supabase.instance.client.auth.currentSession?.accessToken ?? '';

  UserModel copyWith({
    String? name,
    String? phone,
    String? city,
    String? area,
    String? address,
    double? latitude,
    double? longitude,
    String? avatarUrl,
    bool? showPhone,
    bool? showEmail,
  }) =>
      UserModel(
        id:        id,
        email:     email,
        role:      role,
        name:      name      ?? this.name,
        phone:     phone     ?? this.phone,
        city:      city      ?? this.city,
        area:      area      ?? this.area,
        address:   address   ?? this.address,
        latitude:  latitude  ?? this.latitude,
        longitude: longitude ?? this.longitude,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        showPhone:    showPhone    ?? this.showPhone,
        showEmail:    showEmail    ?? this.showEmail,
      );
}

// ─── AuthProvider ─────────────────────────────────────────────────────────────

class AuthProvider extends ChangeNotifier {
  static final _sb = Supabase.instance.client;

  AuthStatus _status       = AuthStatus.initial;
  UserModel? _user;
  String?    _errorMessage;
  String?    _pendingEmail;
  String?    _pendingUserId;
  Timer?     _liveLocationTimer;
  bool       _liveLocationEnabled = false;
  bool get liveLocationEnabled => _liveLocationEnabled;
  bool       justApproved  = false;
  Map<String, Uint8List> _pendingProviderFiles = {};
  // Fallback copy of the provider's professional fields, kept alongside
  // auth_user_meta_data. Supabase's verifyOTP() response can, in some auth
  // configurations (e.g. re-verifying after a resend), return user_metadata
  // that doesn't reflect the most recent signUp() call — when that happens
  // meta['specialization']/['cnic']/etc silently read as null, producing an
  // empty provider_profiles row. This local copy is used whenever the
  // metadata read back from Supabase is missing these fields.
  Map<String, String> _pendingProviderProfile = {};
  // Surfaced on the OTP screen so KYC-save failures are visible on-device
  // without needing terminal/debugPrint access.
  String? lastProviderProfileError;
  RealtimeChannel? _ownRowChannel;

  AuthStatus get status             => _status;
  UserModel? get user               => _user;
  String?    get errorMessage       => _errorMessage;
  String?    get pendingEmail       => _pendingEmail;
  String?    get pendingUserId      => _pendingUserId;
  bool       get isAuthenticated    => _status == AuthStatus.authenticated;
  bool       get needsVerification  => _status == AuthStatus.otpPending;
  bool       get needsAdminApproval => _status == AuthStatus.pendingApproval;

  AuthProvider() {
    _init();
  }

  // ─── Initialise ───────────────────────────────────────────────────────────

  Future<void> _init() async {
    // Only react to sign-out here; login/register handle their own state.
    _sb.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut) {
        _user   = null;
        _status = AuthStatus.unauthenticated;
        notifyListeners();
      }
    });

    // Restore an existing session when the app is reopened
    final session = _sb.auth.currentSession;
    if (session != null) {
      await _loadProfile(session.user);
    } else {
      _status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  // ─── Internal helpers ─────────────────────────────────────────────────────

  Future<void> _loadProfile(User authUser) async {
    try {
      final row = await _sb
          .from('users')
          .select('*')
          .eq('id', authUser.id)
          .single()
          // A stuck/slow connection on app launch used to leave _status
          // stuck at AuthStatus.initial forever — router.dart bounces back
          // to '/' whenever status is initial, so a hang here (not even an
          // error, just no response) looked like the splash screen being
          // permanently frozen with nothing in the console to explain why.
          .timeout(const Duration(seconds: 12));
      _user   = _rowToModel(authUser.id, authUser.email ?? '', row);
      _status = AuthStatus.authenticated;
    } catch (e) {
      debugPrint('AuthProvider._loadProfile error: $e');
      // DB trigger may not have fired yet — use auth metadata as fallback
      final meta = authUser.userMetadata ?? {};
      _user = UserModel(
        id:    authUser.id,
        name:  meta['name']  as String? ?? 'User',
        email: authUser.email ?? '',
        phone: meta['phone'] as String? ?? '',
        role:  meta['role']  as String? ?? 'user',
      );
      _status = AuthStatus.authenticated;
    }
    notifyListeners();
    _listenForOwnRowChanges(authUser.id);
    PushService.registerToken(authUser.id);
  }

  // Keeps the logged-in user's own profile in sync with admin edits (e.g.
  // changing their name/city, or banning them by flipping is_verified off)
  // without requiring an app restart — mirrors PendingApprovalScreen's
  // per-row subscription. If the row is banned or deleted, force logout
  // instead of leaving the app running on a revoked account.
  void _listenForOwnRowChanges(String userId) {
    if (_ownRowChannel != null) return;
    _ownRowChannel = _sb.channel('own_user_$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'users',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: userId,
          ),
          callback: (payload) async {
            final row = payload.newRecord;
            final role = row['role'] as String? ?? _user?.role;
            if (role == 'provider' && row['is_verified'] == false) {
              await logout();
              return;
            }
            _user = _rowToModel(userId, _user?.email ?? '', row);
            notifyListeners();
          },
        )
        .subscribe();
  }

  static UserModel _rowToModel(String id, String email, Map<String, dynamic> r) =>
      UserModel(
        id:        id,
        name:      r['name']     as String? ?? '',
        email:     email,
        phone:     r['phone']    as String? ?? '',
        role:      r['role']     as String? ?? 'user',
        city:      r['city']     as String? ?? '',
        area:      r['area']     as String? ?? '',
        address:   r['address']  as String? ?? '',
        latitude:  (r['latitude']  as num?)?.toDouble(),
        longitude: (r['longitude'] as num?)?.toDouble(),
        avatarUrl: r['avatar_url'] as String?,
        showPhone: r['show_phone'] as bool? ?? true,
        showEmail: r['show_email'] as bool? ?? true,
      );

  void _set(AuthStatus status, {String? error}) {
    _status       = status;
    _errorMessage = error;
    notifyListeners();
  }

  // ─── Login ────────────────────────────────────────────────────────────────

  Future<bool> login(String email, String password, {String role = 'user'}) async {
    _set(AuthStatus.loading, error: null);

    try {
      final res = await _sb.auth.signInWithPassword(
        email:    email.trim().toLowerCase(),
        password: password.trim(),
      );

      final row = await _sb
          .from('users')
          .select('*')
          .eq('id', res.user!.id)
          .single();

      final userRole = row['role'] as String? ?? 'user';

      // Role guard: admin can log in from any portal
      if (role != 'admin' && userRole != role && userRole != 'admin') {
        await _sb.auth.signOut();
        _set(AuthStatus.error,
            error: 'This account is registered as "$userRole". Use the correct login portal.');
        return false;
      }

      // Provider approval gate — provider cannot login until admin verifies them
      if (userRole == 'provider') {
        final isApproved = row['is_verified'] as bool? ?? false;
        if (!isApproved) {
          await _sb.auth.signOut();
          _set(AuthStatus.error,
              error: 'Your account is under review. Admin will approve you shortly.');
          return false;
        }
      }

      _user   = _rowToModel(res.user!.id, res.user!.email ?? '', row);
      _status = AuthStatus.authenticated;
      notifyListeners();
      _listenForOwnRowChanges(res.user!.id);
      PushService.registerToken(res.user!.id);
      return true;

    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('email not confirmed') || msg.contains('not confirmed')) {
        _pendingEmail = email.trim().toLowerCase();
        _set(AuthStatus.otpPending,
            error: 'Please verify your email. Check your inbox for the OTP.');
        return false;
      }
      _set(AuthStatus.error, error: e.message);
      return false;
    } catch (e) {
      _set(AuthStatus.error, error: friendlyError(e));
      return false;
    }
  }

  // ─── Register ─────────────────────────────────────────────────────────────

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String role,
    String city           = '',
    String area           = '',
    String address        = '',
    String cnic           = '',
    String specialization = '',
    String skills         = '',
    String experience     = '',
  }) async {
    _set(AuthStatus.loading, error: null);

    try {
      final res = await _sb.auth.signUp(
        email:    email.trim().toLowerCase(),
        password: password.trim(),
        data: {
          'name':    name.trim(),
          'role':    role,
          'phone':   phone.trim(),
          'city':    city.trim(),
          'area':    area.trim(),
          'address': address.trim(),
          if (role == 'provider') 'cnic':           cnic.trim(),
          if (role == 'provider') 'specialization': specialization.trim(),
          if (role == 'provider') 'skills':         skills.trim(),
          if (role == 'provider') 'experience':     experience.trim(),
        },
      );

      // Empty identities = email already registered
      if (res.user?.identities?.isEmpty == true) {
        _set(AuthStatus.error, error: 'An account with this email already exists.');
        return false;
      }

      if (role == 'provider') {
        _pendingProviderProfile = {
          'cnic': cnic.trim(),
          'specialization': specialization.trim(),
          'skills': skills.trim(),
          'experience': experience.trim(),
        };
      }

      _pendingEmail = email.trim().toLowerCase();
      _set(AuthStatus.otpPending);
      return true;

    } on AuthException catch (e) {
      _set(AuthStatus.error, error: e.message);
      return false;
    } catch (e) {
      _set(AuthStatus.error, error: friendlyError(e));
      return false;
    }
  }

  // ─── OTP verification (signup) ────────────────────────────────────────────

  Future<bool> verifyOtp(String otp, {String? email}) async {
    _set(AuthStatus.loading, error: null);

    final verifyEmail =
        (email?.trim().toLowerCase().isNotEmpty == true)
            ? email!.trim().toLowerCase()
            : _pendingEmail ?? '';

    if (verifyEmail.isEmpty) {
      _set(AuthStatus.otpPending,
          error: 'Session expired. Please register again.');
      return false;
    }

    try {
      final res = await _sb.auth.verifyOTP(
        email: verifyEmail,
        token: otp.trim(),
        type:  OtpType.signup,
      );

      if (res.user == null) {
        _set(AuthStatus.otpPending, error: 'Invalid or expired OTP. Try again.');
        return false;
      }

      debugPrint('verifyOTP session established. uid=${res.user!.id}, '
          'currentSession.uid=${_sb.auth.currentSession?.user.id}, '
          'accessToken present=${_sb.auth.currentSession?.accessToken != null}');

      // Insert user profile into the users table.
      // Supabase auth.signUp only creates an auth user — we must create the
      // public profile row here (equivalent to User.create() in the MERN backend).
      final meta = res.user!.userMetadata ?? {};
      final role = meta['role'] as String? ?? 'user';
      // Customers are auto-verified after email OTP.
      // Providers stay unverified until an admin approves their account.
      final isVerified = role != 'provider';
      final userRowPayload = {
        'id':          res.user!.id,
        'name':        meta['name']    as String? ?? '',
        'email':       res.user!.email ?? '',
        'phone':       meta['phone']   as String? ?? '',
        'role':        role,
        'city':        meta['city']    as String? ?? '',
        'area':        meta['area']    as String? ?? '',
        'address':     meta['address'] as String? ?? '',
        'is_verified': isVerified,
      };
      try {
        await _sb.from('users').upsert(userRowPayload, onConflict: 'id');
      } catch (e) {
        debugPrint('users upsert failed, retrying: $e');
        // A DB trigger may have already created the row (rare races aside);
        // verify before giving up so we don't silently strand the account.
        try {
          await _sb.from('users').upsert(userRowPayload, onConflict: 'id');
        } catch (e2) {
          final exists = await _sb
              .from('users')
              .select('id')
              .eq('id', res.user!.id)
              .maybeSingle();
          if (exists == null) {
            _set(AuthStatus.otpPending,
                error: 'Account verified but profile setup failed. Please try again.');
            return false;
          }
          debugPrint('users row exists despite upsert failure ($e2), continuing.');
        }
      }

      // Create provider_profiles row with registration data.
      // Prefer local _pendingProviderProfile (set at register() time, same
      // app session) over auth metadata — Supabase's verifyOTP() response can
      // return user_metadata that's missing custom fields in some flows
      // (e.g. resend-OTP), which previously produced a silently empty row.
      if (role == 'provider') {
        final hasLocalPending = _pendingProviderProfile.isNotEmpty;
        final specialization = hasLocalPending
            ? _pendingProviderProfile['specialization']
            : meta['specialization'] as String?;
        final cnicValue = hasLocalPending
            ? _pendingProviderProfile['cnic']
            : meta['cnic'] as String?;
        final rawSkills = (hasLocalPending ? _pendingProviderProfile['skills'] : meta['skills'] as String?) ?? '';
        final experienceValue = hasLocalPending
            ? _pendingProviderProfile['experience']
            : meta['experience'] as String?;
        final skillsList = rawSkills
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        final providerProfilePayload = {
          'id':           res.user!.id,
          'service_type': specialization ?? '',
          'cnic':         cnicValue ?? '',
          'skills':       skillsList,
          'experience':   experienceValue ?? '',
          'is_online':    false,
          'rating':       0.0,
          'total_jobs':   0,
        };
        debugPrint('provider_profiles upsert payload: $providerProfilePayload');
        String? kycSaveError;
        try {
          final inserted = await _sb.from('provider_profiles').upsert(providerProfilePayload, onConflict: 'id').select();
          debugPrint('provider_profiles upsert SUCCEEDED, row: $inserted');
        } catch (e, st) {
          debugPrint('provider_profiles upsert FAILED: $e');
          debugPrint('stack: $st');
          try {
            final inserted = await _sb.from('provider_profiles').upsert(providerProfilePayload, onConflict: 'id').select();
            debugPrint('provider_profiles upsert retry SUCCEEDED, row: $inserted');
          } catch (e2) {
            debugPrint('provider_profiles upsert retry FAILED again: $e2 — provider will be missing service_type/CNIC until fixed manually.');
            kycSaveError = e2.toString();
          }
        }
        lastProviderProfileError = kycSaveError;

        // Upload provider documents to Cloudinary. Failed uploads are
        // retried once each; any that still fail are recorded so the caller
        // can warn the user their KYC docs weren't fully submitted, instead
        // of the failure being completely silent.
        debugPrint('Pending KYC files to upload: ${_pendingProviderFiles.keys.toList()} '
            '(sizes: ${_pendingProviderFiles.map((k, v) => MapEntry(k, v.length))})');
        if (_pendingProviderFiles.isNotEmpty) {
          final urls = <String, String>{};
          final failedUploads = <String>[];
          for (final e in _pendingProviderFiles.entries) {
            String? uploadedUrl;
            for (var attempt = 0; attempt < 2 && uploadedUrl == null; attempt++) {
              try {
                final req = http.MultipartRequest(
                  'POST',
                  Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload'),
                );
                req.fields['upload_preset'] = _uploadPreset;
                req.fields['folder'] = 'provider-docs/${res.user!.id}';
                req.files.add(http.MultipartFile.fromBytes('file', e.value, filename: e.key));
                final resp = await req.send();
                final respBody = await resp.stream.bytesToString();
                if (resp.statusCode == 200) {
                  final body = jsonDecode(respBody);
                  uploadedUrl = body['secure_url'] as String;
                  debugPrint('Cloudinary upload ${e.key} SUCCEEDED: $uploadedUrl');
                } else {
                  debugPrint('Cloudinary upload ${e.key} attempt ${attempt + 1} REJECTED: '
                      'status=${resp.statusCode} body=$respBody');
                }
              } catch (uploadErr) {
                debugPrint('Cloudinary upload ${e.key} attempt ${attempt + 1} THREW: $uploadErr');
              }
            }
            if (uploadedUrl != null) {
              urls[e.key] = uploadedUrl;
            } else {
              failedUploads.add(e.key);
            }
          }
          if (failedUploads.isNotEmpty) {
            debugPrint('KYC documents failed to upload after retry: $failedUploads. Provider approval may be delayed until re-submitted.');
          }
          if (urls.isNotEmpty) {
            try {
              final updated = await _sb.from('provider_profiles').update({
                if (urls.containsKey('cnic_front'))   'cnic_front_url':    urls['cnic_front'],
                if (urls.containsKey('cnic_back'))    'cnic_back_url':     urls['cnic_back'],
                if (urls.containsKey('selfie'))       'selfie_url':        urls['selfie'],
                if (urls.containsKey('portfolio'))    'portfolio_url':     urls['portfolio'],
                if (urls.containsKey('certificates')) 'certificates_url':  urls['certificates'],
              }).eq('id', res.user!.id).select();
              debugPrint('provider_profiles KYC url update SUCCEEDED: $updated');
            } catch (updateErr) {
              debugPrint('provider_profiles KYC url update FAILED: $updateErr');
              failedUploads.add('(saving URLs to profile)');
            }
          }
          if (failedUploads.isNotEmpty) {
            lastProviderProfileError = (lastProviderProfileError == null ? '' : '${lastProviderProfileError!}; ')
                + 'KYC upload issue: ${failedUploads.join(', ')}';
          }
          _pendingProviderFiles = {};
        }
        _pendingProviderProfile = {};
      }

      _pendingEmail = null;

      // Providers wait for admin approval — keep session alive but block dashboard
      if (role == 'provider') {
        _pendingUserId = res.user!.id;
        _user = UserModel(
          id:      res.user!.id,
          name:    meta['name']    as String? ?? '',
          email:   res.user!.email ?? '',
          phone:   meta['phone']   as String? ?? '',
          role:    role,
          city:    meta['city']    as String? ?? '',
          area:    meta['area']    as String? ?? '',
          address: meta['address'] as String? ?? '',
        );
        _status = AuthStatus.pendingApproval;
        notifyListeners();
        return true;
      }

      await _loadProfile(res.user!);
      return true;

    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('expired') || msg.contains('invalid') || msg.contains('otp')) {
        _set(AuthStatus.otpPending,
            error: 'Invalid or expired OTP. Please try again or resend.');
      } else {
        _set(AuthStatus.otpPending, error: e.message);
      }
      return false;
    } catch (_) {
      _set(AuthStatus.otpPending,
          error: 'Connection error. Please check your internet.');
      return false;
    }
  }

  // ─── Check approval (called from pending screen via Realtime) ────────────

  Future<bool> checkAndLoadApproval() async {
    final session = _sb.auth.currentSession;
    if (session == null) return false;
    try {
      final row = await _sb
          .from('users')
          .select('*')
          .eq('id', session.user.id)
          .single();
      if (row['is_verified'] == true) {
        _pendingUserId = null;
        await _loadProfile(session.user);
        return true;
      }
    } catch (_) {}
    return false;
  }

  // ─── Resend OTP ───────────────────────────────────────────────────────────

  Future<bool> resendOtp(String email) async {
    try {
      await _sb.auth.resend(
        type:  OtpType.signup,
        email: email.trim().toLowerCase(),
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Change password for logged-in user (no OTP needed) ─────────────────

  Future<String?> updatePassword(String newPassword) async {
    try {
      await _sb.auth.updateUser(UserAttributes(password: newPassword.trim()));
      return null; // null = success
    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ─── Send OTP for password reset (forgot password / not logged in) ───────

  Future<bool> sendPasswordOtp(String email) async {
    try {
      await _sb.auth.signInWithOtp(
        email:            email.trim().toLowerCase(),
        shouldCreateUser: false,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Change password (verify email OTP → set new password) ───────────────

  Future<String?> changePassword({
    required String email,
    required String otp,
    required String newPassword,
  }) async {
    try {
      final res = await _sb.auth.verifyOTP(
        email: email.trim().toLowerCase(),
        token: otp.trim(),
        type:  OtpType.email,
      );
      if (res.user == null) return 'Invalid or expired OTP.';

      await _sb.auth.updateUser(UserAttributes(password: newPassword.trim()));
      return null; // null = success

    } on AuthException catch (e) {
      return e.message;
    } catch (e) {
      return friendlyError(e);
    }
  }

  // ─── Update profile ───────────────────────────────────────────────────────

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
        'name':    name.trim(),
        'phone':   phone.trim(),
        'city':    city.trim(),
        'area':    area.trim(),
        'address': address.trim(),
      };
      if (latitude  != null) body['latitude']  = latitude;
      if (longitude != null) body['longitude'] = longitude;

      await _sb.from('users').update(body).eq('id', _user!.id);

      _user = _user!.copyWith(
        name:      name.trim(),
        phone:     phone.trim(),
        city:      city.trim(),
        area:      area.trim(),
        address:   address.trim(),
        latitude:  latitude,
        longitude: longitude,
      );
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  // Independent of the rest of the profile form — a user can flip these
  // without re-submitting name/phone/location, matching how
  // updateProviderSpecialization is its own separate save action.
  Future<bool> updateVisibility({bool? showPhone, bool? showEmail}) async {
    if (_user == null) return false;
    try {
      final body = <String, dynamic>{};
      if (showPhone != null) body['show_phone'] = showPhone;
      if (showEmail != null) body['show_email'] = showEmail;
      if (body.isEmpty) return true;

      await _sb.from('users').update(body).eq('id', _user!.id);
      _user = _user!.copyWith(
        showPhone: showPhone,
        showEmail: showEmail,
      );
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('updateVisibility error: $e');
      return false;
    }
  }

  // Profile picture upload — same Cloudinary account/preset as KYC docs so
  // both apps and every asset type land in the same place. Available to
  // both customers and providers from the shared Profile screen.
  Future<bool> uploadAvatar(Uint8List bytes, String filename) async {
    if (_user == null) return false;
    String? uploadedUrl;
    for (var attempt = 0; attempt < 2 && uploadedUrl == null; attempt++) {
      try {
        final req = http.MultipartRequest(
          'POST',
          Uri.parse('https://api.cloudinary.com/v1_1/$_cloudName/auto/upload'),
        );
        req.fields['upload_preset'] = _uploadPreset;
        req.fields['folder'] = 'avatars/${_user!.id}';
        req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
        final resp = await req.send();
        if (resp.statusCode == 200) {
          final body = jsonDecode(await resp.stream.bytesToString());
          uploadedUrl = body['secure_url'] as String;
        } else {
          debugPrint('Avatar upload attempt ${attempt + 1} rejected: status=${resp.statusCode}');
        }
      } catch (e) {
        debugPrint('Avatar upload attempt ${attempt + 1} failed: $e');
      }
    }
    if (uploadedUrl == null) return false;

    try {
      await _sb.from('users').update({'avatar_url': uploadedUrl}).eq('id', _user!.id);
      _user = _user!.copyWith(avatarUrl: uploadedUrl);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Saving avatar_url failed: $e');
      return false;
    }
  }

  // ─── Live location toggle ─────────────────────────────────────────────────
  // Runs only while the app is in the foreground (a real always-on background
  // tracker needs a native foreground-service setup, which is out of scope
  // here) — while enabled, captures GPS every 30s and writes it straight to
  // `users` so proximity search / admin sees a fresh location without the
  // user needing to keep re-opening Edit Profile.

  int _locationFailureCount = 0;

  Future<bool> startLiveLocation() async {
    if (_user == null) return false;
    if (_liveLocationEnabled) return true;

    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) return false;

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      return false;
    }

    final firstFix = await _pushCurrentLocation();
    if (!firstFix) return false;

    _liveLocationEnabled = true;
    _locationFailureCount = 0;
    _liveLocationTimer?.cancel();
    _liveLocationTimer = Timer.periodic(const Duration(seconds: 30), (_) => _pushCurrentLocation());
    notifyListeners();
    return true;
  }

  // Providers going online requires live location (see provider_home_tab.dart's
  // _toggleOnline), so turning location off — whether the user does it
  // manually in Edit Profile, or GPS/permission gets lost underneath them —
  // must also force them back offline. Otherwise a provider could show as
  // "Online" with no working location, which is exactly what this whole
  // online/location linkage exists to prevent.
  void stopLiveLocation() {
    _liveLocationTimer?.cancel();
    _liveLocationTimer = null;
    _locationFailureCount = 0;
    if (_liveLocationEnabled) {
      _liveLocationEnabled = false;
      notifyListeners();
    }
    // Clearing location_updated_at (not just stopping the timer) matters —
    // otherwise the admin panel's "Live" badge keeps reading a stale-but-
    // recent timestamp as fresh for up to 2 more minutes after location was
    // actually turned off, showing "Live" when tracking has already stopped.
    if (_user != null) {
      _sb.from('users').update({'location_updated_at': null}).eq('id', _user!.id).then((_) {}, onError: (_) {});
    }
    _forceProviderOffline();
  }

  Future<void> _forceProviderOffline() async {
    if (_user == null || _user!.role != 'provider') return;
    try {
      await _sb.from('provider_profiles').update({'is_online': false}).eq('id', _user!.id);
    } catch (e) {
      debugPrint('_forceProviderOffline error: $e');
    }
  }

  Future<bool> _pushCurrentLocation() async {
    if (_user == null) return false;
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      await _sb.from('users').update({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'location_updated_at': DateTime.now().toIso8601String(),
      }).eq('id', _user!.id);
      _user = _user!.copyWith(latitude: pos.latitude, longitude: pos.longitude);
      _locationFailureCount = 0;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Live location update failed: $e');
      // A single missed fix (brief GPS hiccup) shouldn't kick a provider
      // offline — only two consecutive failures (~1 minute of no fix) means
      // GPS/permission was actually lost, not just a momentary blip.
      _locationFailureCount++;
      if (_locationFailureCount >= 2 && _liveLocationEnabled) {
        stopLiveLocation();
      }
      return false;
    }
  }

  // Lets a provider fix a missing/incorrect specialization after registration —
  // previously there was no UI path to set this once the profile-completion
  // gate in RequestsScreen started requiring it, so a provider whose
  // service_type never got saved (or wasn't set at signup) had no way to
  // recover and would be stuck on the "Profile Incomplete" screen forever.
  Future<bool> updateProviderSpecialization(String serviceType) async {
    if (_user == null) return false;
    try {
      await _sb.from('provider_profiles').upsert(
        {'id': _user!.id, 'service_type': serviceType},
        onConflict: 'id',
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─── Logout ───────────────────────────────────────────────────────────────

  Future<void> logout() async {
    stopLiveLocation();
    if (_ownRowChannel != null) {
      await _sb.removeChannel(_ownRowChannel!);
      _ownRowChannel = null;
    }
    if (_user != null) await PushService.clearToken(_user!.id);
    await _sb.auth.signOut();
    _user   = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    if (_status == AuthStatus.error) _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void setPendingProviderFiles(Map<String, Uint8List> files) {
    _pendingProviderFiles = files;
  }
}
