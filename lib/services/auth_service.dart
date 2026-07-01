import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter/services.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  final _localAuth = LocalAuthentication();

  static const _usersKey = 'sp_users';
  static const _sessionKey = 'sp_session';

  String _hashPassword(String password) {
    const salt = 'swifty_protein_42_salt_v1';
    final bytes = utf8.encode(salt + password);
    return sha256.convert(bytes).toString();
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!password.contains(RegExp(r'[a-zA-Z]'))) return false;
    if (!password.contains(RegExp(r'[0-9]'))) return false;
    return true;
  }

  Future<Map<String, String>> _loadUsers() async {
    final raw = await _storage.read(key: _usersKey);
    if (raw == null) return {};
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    return decoded.map((k, v) => MapEntry(k, v.toString()));
  }

  Future<void> _saveUsers(Map<String, String> users) async {
    await _storage.write(key: _usersKey, value: jsonEncode(users));
  }

  // ── Registration / login ─────────────────────────────────────────────────

  Future<String?> register(String username, String password) async {
    final trimmedUser = username.trim().toLowerCase();
    if (trimmedUser.isEmpty) return 'Username cannot be empty.';
    if (trimmedUser.length < 3) return 'Username must be at least 3 characters.';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmedUser)) {
      return 'Username can only contain letters, numbers, and underscores.';
    }
    if (!_validatePassword(password)) {
      return 'Password must be at least 8 characters with a letter and a digit.';
    }
    final users = await _loadUsers();
    if (users.containsKey(trimmedUser)) return 'Username already taken.';
    users[trimmedUser] = _hashPassword(password);
    await _saveUsers(users);
    return null;
  }

  Future<String?> login(String username, String password) async {
    final trimmedUser = username.trim().toLowerCase();
    final users = await _loadUsers();
    if (!users.containsKey(trimmedUser)) return 'Account not found.';
    if (users[trimmedUser] != _hashPassword(password)) return 'Incorrect password.';
    await _storage.write(key: _sessionKey, value: trimmedUser);
    return null;
  }

  // ── Biometrics ────────────────────────────────────────────────────────────

  Future<bool> get isBiometricAvailable async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      return canCheck && isSupported;
    } catch (_) {
      return false;
    }
  }

  /// List of biometric types enrolled on this device (face, fingerprint, iris...).
  /// Returns an empty list if unavailable or on any error — never throws.
  Future<List<BiometricType>> get availableBiometrics async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } catch (_) {
      return [];
    }
  }

  Future<String?> authenticateWithBiometrics() async {
    try {
      final session = await _storage.read(key: _sessionKey);
      if (session == null) return 'No saved account. Please log in with password first.';
      final authenticated = await _localAuth.authenticate(
        localizedReason: 'Authenticate to access your protein library',
        options: const AuthenticationOptions(biometricOnly: true, stickyAuth: true),
      );
      if (authenticated) return null;
      return 'Authentication failed. Please try again.';
    } on PlatformException catch (e) {
      switch (e.code) {
        case 'NotAvailable':
          return 'Biometric authentication not available on this device.';
        case 'NotEnrolled':
          return 'No biometrics enrolled. Please set up in device Settings.';
        case 'LockedOut':
          return 'Too many failed attempts. Try again later.';
        case 'PermanentlyLockedOut':
          return 'Biometrics locked out. Use your password.';
        default:
          return 'Authentication error: ${e.message}';
      }
    } catch (_) {
      return 'Unexpected error. Please use your password.';
    }
  }

  // ── Session ───────────────────────────────────────────────────────────────

  Future<String?> get currentUser => _storage.read(key: _sessionKey);
  Future<void> logout() async => _storage.delete(key: _sessionKey);

  /// Whether any account has ever been registered on this device.
  Future<bool> hasAnyAccount() async {
    final users = await _loadUsers();
    return users.isNotEmpty;
  }
}