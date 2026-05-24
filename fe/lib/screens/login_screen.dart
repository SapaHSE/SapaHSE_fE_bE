import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'register_screen.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/idle_timeout_service.dart';
import '../services/offline_reference_cache_service.dart';
import '../services/storage_service.dart';
import 'package:local_auth/local_auth.dart';

import '../services/push_notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscurePass = true;
  bool _isLoading = false;
  bool _rememberMe = false;

  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut),
    );
    _animCtrl.forward();

    // Trigger biometric if enabled
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricLogin();
    });
  }

  Future<void> _checkBiometricLogin() async {
    if (kIsWeb) return;

    final bioEnabled = await StorageService.isBiometricEnabled();
    if (!bioEnabled) return;

    final credentials = await StorageService.getBiometricCredentials();
    if (credentials == null) return;

    final localAuth = LocalAuthentication();
    try {
      final canCheck = await localAuth.canCheckBiometrics ||
          await localAuth.isDeviceSupported();
      if (!canCheck) return;

      final authenticated = await localAuth.authenticate(
        localizedReason: 'Gunakan biometrik untuk login',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (authenticated) {
        if (!mounted) return;
        setState(() => _isLoading = true);

        final result = await AuthService.login(
          login: credentials['loginId']!,
          password: credentials['password']!,
          rememberMe: true,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        if (result.success) {
          await PushNotificationService.syncTokenWithBackendIfLoggedIn();
          OfflineReferenceCacheService.prefetchHazardCreateReferences();
          await IdleTimeoutService.instance.start();
          if (!mounted) return;
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const MainScreen()),
            (route) => false,
          );
        } else {
          _showError(result.errorMessage ?? 'Login biometrik gagal.');
        }
      }
    } catch (e) {
      debugPrint('Biometric error: $e');
    }
  }

  @override
  void dispose() {
    _employeeIdCtrl.dispose();
    _passCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Login Logic ───────────────────────────────────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final result = await AuthService.login(
      login: _employeeIdCtrl.text.trim(),
      password: _passCtrl.text,
      rememberMe: _rememberMe,
    );

    if (!mounted) return;

    setState(() => _isLoading = false); // ALWAYS reset

    if (result.success) {
      await PushNotificationService.syncTokenWithBackendIfLoggedIn();
      OfflineReferenceCacheService.prefetchHazardCreateReferences();
      await IdleTimeoutService.instance.start();
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()),
        (route) => false,
      );
    } else {
      _showError(result.errorMessage ?? 'Login gagal. Coba lagi.');
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: const Color(0xFFF44336),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // ── Header blue area ───────────────────────────────────
                  Container(
                    width: double.infinity,
                    color: const Color(0xFF1A56C4),
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 40),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.asset(
                                  'assets/logo.png',
                                  fit: BoxFit.contain,
                                  width: 44,
                                  height: 44,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('SapaHse',
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 22,
                                        letterSpacing: 1)),
                                Text('PT. Bukit Baiduri Energi',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 11)),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        const Text(
                          'Selamat Datang',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Masuk ke akun Anda untuk melanjutkan',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),

                  // ── Form card ──────────────────────────────────────────
                  Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.07),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Login identifier field ─────────────────────
                          _buildLabel('NIP / Email'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _employeeIdCtrl,
                            keyboardType: TextInputType.emailAddress,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(150),
                            ],
                            validator: (v) {
                              final value = (v ?? '').trim();
                              if (value.isEmpty) {
                                return 'Field ini wajib diisi';
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              hint: 'Masukkan NIP atau email',
                              prefixIcon: Icons.person_outline,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // ── Password field ─────────────────────────────
                          _buildLabel('Password'),
                          const SizedBox(height: 6),
                          TextFormField(
                            controller: _passCtrl,
                            obscureText: _obscurePass,
                            validator: (v) {
                              if (v == null || v.isEmpty) {
                                return 'Password wajib diisi';
                              }
                              if (v == '123') {
                                return null; // Bypass validation for "123"';
                              }
                              if (v.length < 8) {
                                return 'Password minimal 8 karakter';
                              }
                              return null;
                            },
                            decoration: _inputDecoration(
                              hint: 'Masukkan password',
                              prefixIcon: Icons.lock_outline,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePass
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                    () => _obscurePass = !_obscurePass),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // ── Remember me + Forgot password ──────────────
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () =>
                                    setState(() => _rememberMe = !_rememberMe),
                                child: Row(
                                  children: [
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 200),
                                      width: 20,
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: _rememberMe
                                            ? const Color(0xFF1A56C4)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(5),
                                        border: Border.all(
                                          color: _rememberMe
                                              ? const Color(0xFF1A56C4)
                                              : Colors.grey.shade400,
                                          width: 2,
                                        ),
                                      ),
                                      child: _rememberMe
                                          ? const Icon(Icons.check,
                                              color: Colors.white, size: 13)
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text('Ingat saya',
                                        style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.black54)),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: () => _showForgotPasswordDialog(context),
                                child: const Text(
                                  'Lupa password?',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF1A56C4),
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // ── Login button ───────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 50,
                                  child: ElevatedButton(
                                    onPressed: _isLoading ? null : _login,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF1A56C4),
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          const Color(0xFF1A56C4)
                                              .withValues(alpha: 0.6),
                                      shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                color: Colors.white,
                                                strokeWidth: 2))
                                        : const Text('Masuk',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold)),
                                  ),
                                ),
                              ),
                              if (!kIsWeb)
                                FutureBuilder<bool>(
                                  future: StorageService.isBiometricEnabled(),
                                  builder: (context, snapshot) {
                                    if (snapshot.data == true) {
                                      return Padding(
                                        padding:
                                            const EdgeInsets.only(left: 12),
                                        child: SizedBox(
                                          height: 50,
                                          width: 50,
                                          child: ElevatedButton(
                                            onPressed: _isLoading
                                                ? null
                                                : _checkBiometricLogin,
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  const Color(0xFFF0F4FA),
                                              foregroundColor:
                                                  const Color(0xFF1A56C4),
                                              padding: EdgeInsets.zero,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12)),
                                              elevation: 0,
                                            ),
                                            child: const Icon(Icons.fingerprint,
                                                size: 28),
                                          ),
                                        ),
                                      );
                                    }
                                    return const SizedBox();
                                  },
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // ── Register link ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Belum punya akun? ',
                            style:
                                TextStyle(fontSize: 14, color: Colors.black54)),
                        GestureDetector(
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          ),
                          child: const Text(
                            'Daftar Sekarang',
                            style: TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1A56C4),
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
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

  void _showForgotPasswordDialog(BuildContext context) {
    final identifierCtrl = TextEditingController();
    bool isLoading = false;
    String? errorMsg;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Lupa Password',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Masukkan email pribadi, email kantor, atau NIP Anda. Tautan reset password akan dikirimkan ke email pribadi Anda.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 14),
              if (errorMsg != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          color: Colors.red.shade600, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(errorMsg!,
                            style: TextStyle(
                                color: Colors.red.shade700, fontSize: 13)),
                      ),
                    ],
                  ),
                ),
              ],
              TextField(
                controller: identifierCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _inputDecoration(
                    hint: 'Email pribadi/kantor atau NIP',
                    prefixIcon: Icons.person_outline),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed:
                    isLoading ? null : () => Navigator.pop(dialogContext),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      final identifier = identifierCtrl.text.trim();
                      if (identifier.isEmpty) return;

                      setDialogState(() {
                        isLoading = true;
                        errorMsg = null;
                      });

                      final result = await AuthService.forgotPassword(
                          identifier: identifier);

                      if (!dialogContext.mounted) return;

                      if (result.success) {
                        Navigator.pop(dialogContext);
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result.message),
                            backgroundColor: const Color(0xFF1A56C4),
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                            margin: const EdgeInsets.all(16),
                          ),
                        );
                      } else {
                        setDialogState(() {
                          isLoading = false;
                          errorMsg = result.message;
                        });
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56C4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Kirim'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: Colors.grey, size: 20),
      suffixIcon: suffixIcon,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      filled: true,
      fillColor: const Color(0xFFF8F8F8),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF1A56C4), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }
}
