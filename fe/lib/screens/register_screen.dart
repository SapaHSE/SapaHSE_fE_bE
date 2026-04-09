import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey       = GlobalKey<FormState>();
  final _namaCtrl      = TextEditingController();
  final _nikCtrl       = TextEditingController();
  final _emailCtrl     = TextEditingController();
  final _teleponCtrl   = TextEditingController();
  final _passCtrl      = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  String _selectedDivisi = 'Departemen HSE';
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _isLoading      = false;
  bool _agreeTerms     = false;

  // Step: 0 = data diri, 1 = akun
  int _currentStep = 0;

  final List<String> _divisiList = [
    'Departemen HSE',
    'Departemen IT',
    'Departemen Operasional',
    'Departemen Produksi',
    'Departemen Keuangan',
    'Departemen HR',
    'Departemen Maintenance',
    'Departemen Logistik',
  ];

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _nikCtrl.dispose();
    _emailCtrl.dispose();
    _teleponCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Step 1 → Step 2 ───────────────────────────────────────────────────────
  void _nextStep() {
    if (_currentStep == 0) {
      if (_namaCtrl.text.isEmpty || _nikCtrl.text.isEmpty ||
          _emailCtrl.text.isEmpty || _teleponCtrl.text.isEmpty) {
        _showSnackbar('Harap lengkapi semua field', Colors.orange);
        return;
      }
      if (_nikCtrl.text.length < 10) {
        _showSnackbar('NIK minimal 10 digit', Colors.orange);
        return;
      }
      setState(() => _currentStep = 1);
      _animCtrl.reset();
      _animCtrl.forward();
    }
  }

  void _prevStep() {
    setState(() => _currentStep = 0);
    _animCtrl.reset();
    _animCtrl.forward();
  }

  // ── Register → API ────────────────────────────────────────────────────────
  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_agreeTerms) {
      _showSnackbar('Harap setujui syarat & ketentuan', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);

    final result = await AuthService.register(
      nik:         _nikCtrl.text.trim(),
      employeeId:  null,
      fullName:    _namaCtrl.text.trim(),
      email:       _emailCtrl.text.trim(),
      password:    _passCtrl.text,
      phoneNumber: _teleponCtrl.text.trim().isEmpty
          ? null
          : _teleponCtrl.text.trim(),
      department:  _selectedDivisi,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      // Navigate ke LoginScreen dan tampilkan snackbar sukses
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
      // Snackbar ditampilkan setelah navigasi selesai
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Registrasi berhasil! Silakan login.')),
              ],
            ),
            backgroundColor: const Color(0xFF1A56C4),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
            duration: const Duration(seconds: 3),
          ),
        );
      });
    } else {
      _showSnackbar(result.errorMessage ?? 'Registrasi gagal.', Colors.red);
    }
  }

  void _showSnackbar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
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
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────
            Container(
              color: const Color(0xFF1A56C4),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _currentStep == 1
                            ? _prevStep
                            : () => Navigator.pop(context),
                        child: Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 20),
                        ),
                      ),
                      const Expanded(
                        child: Text('Buat Akun',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 18)),
                      ),
                      const SizedBox(width: 36),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // ── Step indicator ─────────────────────────────────────
                  Row(
                    children: [
                      _StepDot(
                          number: 1,
                          isActive: _currentStep == 0,
                          isDone: _currentStep > 0,
                          label: 'Data Diri'),
                      Expanded(
                        child: Container(
                          height: 2,
                          color: _currentStep > 0
                              ? Colors.white
                              : Colors.white38,
                        ),
                      ),
                      _StepDot(
                          number: 2,
                          isActive: _currentStep == 1,
                          isDone: false,
                          label: 'Akun'),
                    ],
                  ),
                ],
              ),
            ),

            // ── Form ────────────────────────────────────────────────────
            Expanded(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4)),
                            ],
                          ),
                          child: _currentStep == 0
                              ? _buildStep1()
                              : _buildStep2(),
                        ),

                        const SizedBox(height: 20),

                        // ── Tombol aksi ───────────────────────────────────
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isLoading
                                ? null
                                : (_currentStep == 0 ? _nextStep : _register),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1A56C4),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  const Color(0xFF1A56C4).withOpacity(0.6),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22, height: 22,
                                    child: CircularProgressIndicator(
                                        color: Colors.white, strokeWidth: 2))
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentStep == 0
                                            ? 'Lanjut'
                                            : 'Daftar Sekarang',
                                        style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 6),
                                      Icon(
                                        _currentStep == 0
                                            ? Icons.arrow_forward
                                            : Icons.check,
                                        size: 18,
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Link login ────────────────────────────────────
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Sudah punya akun? ',
                                style: TextStyle(
                                    fontSize: 14, color: Colors.black54)),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text('Masuk',
                                  style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF1A56C4),
                                      fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── STEP 1 — Data Diri ────────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Data Diri',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Lengkapi informasi pribadi Anda',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),

        _label('Nama Lengkap *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _namaCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: _deco(hint: 'Masukkan nama lengkap', icon: Icons.person_outline),
          validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
        ),

        const SizedBox(height: 16),

        _label('NIK *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nikCtrl,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(16),
          ],
          decoration: _deco(hint: 'Masukkan NIK (16 digit)', icon: Icons.badge_outlined),
          validator: (v) {
            if (v!.isEmpty) return 'Wajib diisi';
            if (v.length != 16) return 'NIK harus 16 digit';
            return null;
          },
        ),

        const SizedBox(height: 16),

        _label('Email *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          decoration: _deco(hint: 'Masukkan email', icon: Icons.email_outlined),
          validator: (v) {
            if (v!.isEmpty) return 'Wajib diisi';
            if (!v.contains('@') || !v.contains('.')) return 'Format email tidak valid';
            return null;
          },
        ),

        const SizedBox(height: 16),

        _label('Nomor Telepon *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _teleponCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: _deco(hint: 'Contoh: 081234567890', icon: Icons.phone_outlined),
          validator: (v) {
            if (v!.isEmpty) return 'Wajib diisi';
            if (v.length < 10) return 'Nomor telepon tidak valid';
            return null;
          },
        ),

        const SizedBox(height: 16),

        _label('Jabatan / Divisi *'),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F8F8),
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDivisi,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              style: const TextStyle(fontSize: 14, color: Colors.black87),
              items: _divisiList
                  .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedDivisi = v);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ── STEP 2 — Akun ─────────────────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Buat Password',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 4),
        const Text('Password akan digunakan untuk login',
            style: TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 20),

        // Ringkasan data diri
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF4FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: const Color(0xFF1A56C4).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              _SummaryRow(label: 'Nama',   value: _namaCtrl.text),
              _SummaryRow(label: 'NIK',    value: _nikCtrl.text),
              _SummaryRow(label: 'Email',  value: _emailCtrl.text),
              _SummaryRow(label: 'Divisi', value: _selectedDivisi),
            ],
          ),
        ),

        const SizedBox(height: 20),

        _label('Password *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _passCtrl,
          obscureText: _obscurePass,
          onChanged: (_) => setState(() {}),
          decoration: _deco(
            hint: 'Minimal 8 karakter',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                _obscurePass
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey, size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscurePass = !_obscurePass),
            ),
          ),
          validator: (v) {
            if (v!.isEmpty) return 'Wajib diisi';
            if (v.length < 8) return 'Password minimal 8 karakter';
            return null;
          },
        ),

        const SizedBox(height: 8),

        if (_passCtrl.text.isNotEmpty)
          _buildPasswordStrength(_passCtrl.text),

        const SizedBox(height: 16),

        _label('Konfirmasi Password *'),
        const SizedBox(height: 6),
        TextFormField(
          controller: _confirmPassCtrl,
          obscureText: _obscureConfirm,
          onChanged: (_) => setState(() {}),
          decoration: _deco(
            hint: 'Ulangi password',
            icon: Icons.lock_outline,
            suffix: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Colors.grey, size: 20,
              ),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          validator: (v) {
            if (v!.isEmpty) return 'Wajib diisi';
            if (v != _passCtrl.text) return 'Password tidak cocok';
            return null;
          },
        ),

        const SizedBox(height: 20),

        // Syarat & ketentuan
        GestureDetector(
          onTap: () => setState(() => _agreeTerms = !_agreeTerms),
          behavior: HitTestBehavior.opaque,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 20, height: 20,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: _agreeTerms
                      ? const Color(0xFF1A56C4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(
                    color: _agreeTerms
                        ? const Color(0xFF1A56C4)
                        : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: _agreeTerms
                    ? const Icon(Icons.check, color: Colors.white, size: 13)
                    : null,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Saya menyetujui ',
                    style:
                        TextStyle(fontSize: 13, color: Colors.black54),
                    children: [
                      TextSpan(
                        text: 'Syarat & Ketentuan',
                        style: TextStyle(
                            color: Color(0xFF1A56C4),
                            fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' dan '),
                      TextSpan(
                        text: 'Kebijakan Privasi',
                        style: TextStyle(
                            color: Color(0xFF1A56C4),
                            fontWeight: FontWeight.w600),
                      ),
                      TextSpan(text: ' BBE'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordStrength(String pass) {
    int strength = 0;
    if (pass.length >= 8) strength++;
    if (pass.contains(RegExp(r'[A-Z]'))) strength++;
    if (pass.contains(RegExp(r'[0-9]'))) strength++;
    if (pass.contains(RegExp(r'[!@#$%^&*]'))) strength++;

    final labels = ['Sangat Lemah', 'Lemah', 'Cukup', 'Kuat'];
    final colors = [
      Colors.red,
      Colors.orange,
      Colors.yellow.shade700,
      const Color(0xFF1A56C4)
    ];
    final idx = (strength - 1).clamp(0, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(
            4,
            (i) => Expanded(
              child: Container(
                height: 4,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: i < strength
                      ? colors[idx]
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          strength > 0 ? 'Kekuatan: ${labels[idx]}' : '',
          style: TextStyle(
              fontSize: 11,
              color: strength > 0 ? colors[idx] : Colors.grey),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87),
      );

  InputDecoration _deco({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: Icon(icon, color: Colors.grey, size: 20),
      suffixIcon: suffix,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
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
          borderSide:
              const BorderSide(color: Color(0xFF1A56C4), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }
}

// ── STEP DOT ──────────────────────────────────────────────────────────────────
class _StepDot extends StatelessWidget {
  final int number;
  final bool isActive;
  final bool isDone;
  final String label;

  const _StepDot({
    required this.number,
    required this.isActive,
    required this.isDone,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: 32, height: 32,
          decoration: BoxDecoration(
            color: isActive || isDone ? Colors.white : Colors.white30,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check,
                    color: Color(0xFF1A56C4), size: 18)
                : Text(
                    '$number',
                    style: TextStyle(
                      color: isActive
                          ? const Color(0xFF1A56C4)
                          : Colors.white54,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: isActive || isDone ? Colors.white : Colors.white54,
            fontSize: 11,
            fontWeight:
                isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

// ── SUMMARY ROW ───────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 56,
              child: Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: Colors.grey)),
            ),
            const Text(': ',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
            Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ),
          ],
        ),
      );
}