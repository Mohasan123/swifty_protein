import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import '../services/auth_service.dart';
import '../utils/app_theme.dart';
import 'ligands_list_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final auth = AuthService();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true;
  bool _loading = false;
  bool _obscurePass = true;
  bool _biometricAvailable = false;
  List<BiometricType> _biometrics = [];
  String? _errorMsg;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _animCtrl.forward();
    _checkBiometrics();
    _checkExistingAccount();
  }

  /// If no account has ever been registered on this device, start the user
  /// in Register mode instead of Sign In — otherwise their first action
  /// would be a confusing "Account not found" error.
  Future<void> _checkExistingAccount() async {
    final hasAccount = await auth.hasAnyAccount();
    if (mounted && !hasAccount) {
      setState(() => _isLogin = false);
    }
  }

  Future<void> _checkBiometrics() async {
    final available = await auth.isBiometricAvailable;
    final types = await auth.availableBiometrics;
    if (mounted) setState(() { _biometricAvailable = available; _biometrics = types; });
  }

  void _setError(String? msg) => setState(() => _errorMsg = msg);
  void _setLoading(bool v) => setState(() => _loading = v);

  Future<void> _submit() async {
    _setError(null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    _setLoading(true);

    final username = _usernameCtrl.text;
    final password = _passwordCtrl.text;

    String? error;
    if (_isLogin) {
      error = await auth.login(username, password);
    } else {
      error = await auth.register(username, password);
      if (error == null) error = await auth.login(username, password);
    }

    _setLoading(false);
    if (error != null) {
      _setError(error);
    } else {
      _goHome();
    }
  }

  Future<void> _biometricLogin() async {
    _setError(null);
    _setLoading(true);
    final error = await auth.authenticateWithBiometrics();
    _setLoading(false);
    if (error != null) {
      _showBiometricError(error);
    } else {
      _goHome();
    }
  }

  void _showBiometricError(String msg) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceVariant,
        title: const Text('Authentication Failed', style: TextStyle(color: AppTheme.onSurface)),
        content: Text(msg, style: const TextStyle(color: AppTheme.onSurfaceDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppTheme.primary)),
          ),
        ],
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LigandsListScreen()),
    );
  }

  IconData get _biometricIcon {
    if (_biometrics.contains(BiometricType.face)) return Icons.face_unlock_outlined;
    if (_biometrics.contains(BiometricType.fingerprint)) return Icons.fingerprint;
    return Icons.security;
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 32),
                  // Header
                  const Icon(Icons.hub_rounded, color: AppTheme.primary, size: 40),
                  const SizedBox(height: 20),
                  Text(
                    _isLogin ? 'Welcome back' : 'Create account',
                    style: const TextStyle(color: AppTheme.onSurface, fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLogin ? 'Sign in to your protein library' : 'Start exploring molecular structures',
                    style: const TextStyle(color: AppTheme.onSurfaceDim, fontSize: 14),
                  ),
                  const SizedBox(height: 40),

                  // Username field
                  TextFormField(
                    controller: _usernameCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.onSurfaceDim),
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Enter your username' : null,
                  ),
                  const SizedBox(height: 16),

                  // Password field
                  TextFormField(
                    controller: _passwordCtrl,
                    style: const TextStyle(color: AppTheme.onSurface),
                    obscureText: _obscurePass,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.onSurfaceDim),
                      suffixIcon: IconButton(
                        icon: Icon(_obscurePass ? Icons.visibility_off : Icons.visibility,
                            color: AppTheme.onSurfaceDim),
                        tooltip: _obscurePass ? 'Show password' : 'Hide password',
                        onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      ),
                    ),
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => (v == null || v.isEmpty) ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 24),

                  // Error message
                  if (_errorMsg != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.error.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.error, size: 18),
                          const SizedBox(width: 10),
                          Expanded(child: Text(_errorMsg!, style: const TextStyle(color: AppTheme.error, fontSize: 13))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Submit button
                  _loading
                      ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
                      : ElevatedButton(
                          onPressed: _submit,
                          child: Text(_isLogin ? 'Sign In' : 'Create Account'),
                        ),
                  const SizedBox(height: 16),

                  // Biometric button
                  if (_isLogin && _biometricAvailable)
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _biometricLogin,
                      icon: Icon(_biometricIcon, color: AppTheme.primary),
                      label: const Text('Use Biometrics', style: TextStyle(color: AppTheme.primary)),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 52),
                        side: const BorderSide(color: AppTheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  const SizedBox(height: 32),

                  // Toggle login / register
                  Center(
                    child: TextButton(
                      onPressed: () => setState(() {
                        _isLogin = !_isLogin;
                        _setError(null);
                        _usernameCtrl.clear();
                        _passwordCtrl.clear();
                      }),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: AppTheme.onSurfaceDim, fontSize: 14),
                          children: [
                            TextSpan(text: _isLogin ? "Don't have an account? " : 'Already have an account? '),
                            TextSpan(
                              text: _isLogin ? 'Register' : 'Sign In',
                              style: const TextStyle(color: AppTheme.primary, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
