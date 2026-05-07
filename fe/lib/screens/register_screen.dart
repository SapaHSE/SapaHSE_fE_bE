import 'package:flutter/material.dart';
import 'login_screen.dart';
import '../services/auth_service.dart';
import '../services/company_service.dart';
import '../services/department_service.dart';
import '../widgets/minimal_dropdown.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _currentStep = 1;

  // Step 1
  final _formKey1 = GlobalKey<FormState>();
  final _namaCtrl = TextEditingController();
  final _empIdCtrl = TextEditingController();
  final _hpCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscurePass = true;

  // Step 2
  final _formKey2 = GlobalKey<FormState>();
  String _tipeAfiliasi = 'Owner'; // Owner, Kontraktor, Sub-Kont.
  String? _perusahaan;
  String? _perusahaanKontraktor;
  String? _subKontraktor;
  String? _departemen;
  final _jabatanCtrl = TextEditingController();
  final _simperCtrl = TextEditingController();
  final _emailKantorCtrl = TextEditingController();

  List<String> _ownerList = [];
  List<String> _kontraktorList = [];
  List<String> _subkontraktorList = [];
  List<String> _departemenList = [];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchCompanies();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final depts = await DepartmentService.getDepartments();
      if (mounted) {
        setState(() {
          _departemenList = depts.map((e) => e.name).toList();
        });
      }
    } catch (e) {
      debugPrint('Error fetching departments: $e');
    }
  }

  /// Prefers active companies; falls back to all in category so dropdowns are not empty/disabled.
  Future<List<String>> _loadCompanyNames(String category) async {
    var list =
        await CompanyService.getCompanies(category: category, active: true);
    if (list.isEmpty) {
      list = await CompanyService.getCompanies(category: category);
    }
    final names = list.map((e) => e.name).toList();
    final seen = <String>{};
    return names.where((n) => seen.add(n)).toList();
  }

  Future<void> _fetchCompanies() async {
    try {
      final owners = await _loadCompanyNames('owner');
      final contractors = await _loadCompanyNames('kontraktor');
      final subContractors = await _loadCompanyNames('subkontraktor');

      if (!mounted) return;
      setState(() {
        _ownerList = owners;
        _kontraktorList = contractors;
        _subkontraktorList = subContractors;
      });
    } catch (e) {
      debugPrint('Error fetching companies: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memuat daftar perusahaan: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _namaCtrl.dispose();
    _empIdCtrl.dispose();
    _hpCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _jabatanCtrl.dispose();
    _simperCtrl.dispose();
    _emailKantorCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 1) {
      if (_formKey1.currentState!.validate()) {
        setState(() {
          _currentStep = 2;
        });
      }
    } else if (_currentStep == 2) {
      if (_formKey2.currentState!.validate()) {
        setState(() {
          _currentStep = 3;
        });
      }
    }
  }

  void _prevStep() {
    if (_currentStep > 1) {
      setState(() {
        _currentStep--;
      });
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      final response = await AuthService.register(
        nik: _empIdCtrl.text,
        fullName: _namaCtrl.text,
        personalEmail: _emailCtrl.text,
        workEmail: _emailKantorCtrl.text,
        password: _passCtrl.text,
        phoneNumber: _hpCtrl.text,
        position: _jabatanCtrl.text,
        department: _departemen ?? '',
        company: _perusahaan ?? '',
        tipeAfiliasi: _tipeAfiliasi,
        perusahaanKontraktor: _perusahaanKontraktor,
        subKontraktor: _subKontraktor,
        simper: _simperCtrl.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.success) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 60),
                const SizedBox(height: 16),
                const Text('Registrasi Berhasil!',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Text(
                  'Registrasi berhasil. Akun Anda sedang menunggu persetujuan administrator. Anda akan menerima email verifikasi setelah akun disetujui.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // close dialog
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3D5AFE),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    child: const Text('Oke Mengerti!'),
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        _showError(response.errorMessage ?? 'Registrasi gagal.');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Terjadi kesalahan: ${e.toString()}');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFF4F6F9),
                ),
                child: Column(
                  children: [
                    // Step Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                      ),
                      child: _buildStepIndicator(),
                    ),

                    // Form Content
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildCurrentStepContent(),
                      ),
                    ),

                    // Bottom Button
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        border: Border(top: BorderSide(color: Colors.black12)),
                      ),
                      child: Column(
                        children: [
                          _buildBottomButton(),
                          if (_currentStep == 1) ...[
                            const SizedBox(height: 16),
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: const Text.rich(
                                TextSpan(
                                  text: 'Sudah punya akun? ',
                                  style: TextStyle(
                                      color: Colors.grey, fontSize: 13),
                                  children: [
                                    TextSpan(
                                        text: 'Masuk',
                                        style: TextStyle(
                                            color: Color(0xFF3D5AFE),
                                            fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    if (_currentStep == 1) {
      return Container(
        width: double.infinity,
        color: const Color(0xFF111827),
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child:
                  const Icon(Icons.shield, color: Colors.blueAccent, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Informasi Pengguna',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            const Text('1Sapa · Neztek Platform',
                style: TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    } else {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            GestureDetector(
              onTap: _prevStep,
              child: const Icon(Icons.arrow_back),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                _currentStep == 2 ? 'Informasi Karyawan' : 'Tinjau & Daftar',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Text('Langkah $_currentStep/3',
                style: const TextStyle(color: Colors.grey, fontSize: 13)),
          ],
        ),
      );
    }
  }

  Widget _buildStepIndicator() {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Positioned(
          top: 14,
          left: 40,
          right: 40,
          child: Row(
            children: [
              Expanded(
                  child: Container(
                      height: 2,
                      color: _currentStep > 1
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE5E7EB))),
              Expanded(
                  child: Container(
                      height: 2,
                      color: _currentStep > 2
                          ? const Color(0xFF10B981)
                          : const Color(0xFFE5E7EB))),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStepDot(1, 'PRIBADI'),
            _buildStepDot(2, 'KARYAWAN'),
            _buildStepDot(3, 'REVIEW'),
          ],
        ),
      ],
    );
  }

  Widget _buildStepDot(int step, String label) {
    bool isActive = _currentStep == step;
    bool isDone = _currentStep > step;

    Color color;
    Color textColor;
    if (isDone) {
      color = const Color(0xFF10B981);
      textColor = const Color(0xFF10B981);
    } else if (isActive) {
      color = const Color(0xFF3D5AFE);
      textColor = const Color(0xFF3D5AFE);
    } else {
      color = const Color(0xFFE5E7EB);
      textColor = const Color(0xFF9CA3AF);
    }

    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: isDone || isActive ? color : color,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: isDone
                ? const Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$step',
                    style: TextStyle(
                      color: isActive ? Colors.white : const Color(0xFF9CA3AF),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentStepContent() {
    switch (_currentStep) {
      case 1:
        return _buildStep1();
      case 2:
        return _buildStep2();
      case 3:
        return _buildStep3();
      default:
        return const SizedBox();
    }
  }

  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        children: [
          // Avatar
          const SizedBox(height: 8),
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: const BoxDecoration(
                  color: Color(0xFF6366F1),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.person, color: Colors.white54, size: 40),
              ),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFF3D5AFE),
                  shape: BoxShape.circle,
                ),
                child:
                    const Icon(Icons.camera_alt, color: Colors.white, size: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Tambah Foto (opsional)',
              style: TextStyle(color: Color(0xFF3D5AFE), fontSize: 13)),
          const SizedBox(height: 24),

          // Form Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('INFORMASI PRIBADI',
                    style: TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12)),
                const SizedBox(height: 16),
                _buildTextField(
                    label: 'NAMA LENGKAP *',
                    hint: 'Sesuai dokumen resmi',
                    controller: _namaCtrl),
                const SizedBox(height: 16),
                _buildTextField(
                    label: 'EMPLOYEE ID *',
                    hint: '10–16 karakter',
                    controller: _empIdCtrl,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib diisi';
                      if (v.length < 10 || v.length > 16) {
                        return 'Employee ID 10–16 karakter';
                      }
                      return null;
                    }),
                const SizedBox(height: 16),
                _buildTextField(
                    label: 'NOMOR HP *',
                    hint: '+62 8xx-xxxx-xxxx',
                    controller: _hpCtrl,
                    keyboardType: TextInputType.phone),
                const SizedBox(height: 16),
                _buildTextField(
                    label: 'EMAIL PRIBADI *',
                    hint: 'email@pribadi.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Wajib diisi';
                      if (!v.contains('@') || !v.contains('.')) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    }),
                const Padding(
                  padding: EdgeInsets.only(top: 4, bottom: 12),
                  child: Text('Untuk login, reset sandi, dan notifikasi',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
                _buildTextField(
                  label: 'KATA SANDI *',
                  hint: 'Minimal 8 karakter',
                  controller: _passCtrl,
                  obscureText: _obscurePass,
                  suffixIcon: IconButton(
                    icon: Icon(
                        _obscurePass ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                        size: 20),
                    onPressed: () =>
                        setState(() => _obscurePass = !_obscurePass),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Wajib diisi';
                    if (v.length < 8) return 'Minimal 8 karakter';
                    return null;
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep2() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // AFILIASI PERUSAHAAN
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('AFILIASI PERUSAHAAN',
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('TIPE AFILIASI *'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildAfiliasiBtn('Owner', Icons.business),
                    const SizedBox(width: 8),
                    _buildAfiliasiBtn('Kontraktor', Icons.handshake),
                    const SizedBox(width: 8),
                    _buildAfiliasiBtn('Sub-Kont.', Icons.assignment),
                  ],
                ),
                const SizedBox(height: 16),
                _buildLabel('PERUSAHAAN OWNER *'),
                const SizedBox(height: 8),
                _buildDropdown(
                  value: _perusahaan,
                  items: _ownerList,
                  hint: '-- Pilih --',
                  onChanged: (v) => setState(() => _perusahaan = v),
                ),
                if (_tipeAfiliasi == 'Kontraktor' ||
                    _tipeAfiliasi == 'Sub-Kont.') ...[
                  const SizedBox(height: 16),
                  _buildLabel('PERUSAHAAN KONTRAKTOR'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _perusahaanKontraktor,
                    items: _kontraktorList,
                    hint: '-- Pilih --',
                    onChanged: (v) => setState(() => _perusahaanKontraktor = v),
                    isRequired: false,
                  ),
                ],
                if (_tipeAfiliasi == 'Sub-Kont.') ...[
                  const SizedBox(height: 16),
                  _buildLabel('SUB-KONTRAKTOR'),
                  const SizedBox(height: 8),
                  _buildDropdown(
                    value: _subKontraktor,
                    items: _subkontraktorList,
                    hint: '-- Pilih --',
                    onChanged: (v) => setState(() => _subKontraktor = v),
                    isRequired: false,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),

          // POSISI & DEPARTEMEN
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('POSISI & DEPARTEMEN',
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('DEPARTEMEN *'),
                const SizedBox(height: 8),
                _buildDropdown(
                  value: _departemen,
                  items: _departemenList,
                  hint: '-- Pilih --',
                  onChanged: (v) => setState(() => _departemen = v),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                    label: 'JABATAN / POSISI *',
                    hint: 'Contoh: Safety Officer, Operator...',
                    controller: _jabatanCtrl,
                    isRequired: true),
                const SizedBox(height: 16),
                _buildTextField(
                    label: 'SIMPER / KIMPER',
                    hint: 'Nomor SIM operasi internal (jika ada)',
                    controller: _simperCtrl,
                    isRequired: false),
                const SizedBox(height: 16),
                _buildTextField(
                    label: 'EMAIL PERUSAHAAN',
                    hint: 'email@perusahaan.com (opsional)',
                    controller: _emailKantorCtrl,
                    isRequired: false,
                    validator: (v) {
                      final t = v?.trim() ?? '';
                      if (t.isEmpty) return null;
                      if (!t.contains('@') || !t.contains('.')) {
                        return 'Format email tidak valid';
                      }
                      return null;
                    }),
                const Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text('Tidak semua karyawan memiliki email perusahaan',
                      style: TextStyle(color: Colors.grey, fontSize: 11)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Info box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBFDBFE)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info, color: Color(0xFF3B82F6), size: 18),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text.rich(
                    TextSpan(
                      text: 'Akun perlu ',
                      style: TextStyle(color: Color(0xFF1E40AF), fontSize: 12),
                      children: [
                        TextSpan(
                            text: 'disetujui Supervisor',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                            text:
                                ' sebelum dapat digunakan. Data opsional yang belum diisi mendapat...'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // INFORMASI PRIBADI
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('INFORMASI PRIBADI',
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            TextButton.icon(
              onPressed: () => setState(() => _currentStep = 1),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildReviewRow('Nama', _namaCtrl.text),
              const Divider(),
              _buildReviewRow('Employee ID', _empIdCtrl.text),
              const Divider(),
              _buildReviewRow('Nomor HP', _hpCtrl.text),
              const Divider(),
              _buildReviewRow('Email Pribadi', _emailCtrl.text),
              const Divider(),
              _buildReviewRow('Password', '••••••••'),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // INFORMASI KARYAWAN
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('INFORMASI KARYAWAN',
                style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 12)),
            TextButton.icon(
              onPressed: () => setState(() => _currentStep = 2),
              icon: const Icon(Icons.edit, size: 14),
              label: const Text('Edit'),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFEF4444),
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              _buildReviewRow('Tipe', _tipeAfiliasi, isBadge: true),
              const Divider(),
              _buildReviewRow('Perusahaan Owner', _perusahaan ?? '-'),
              if (_perusahaanKontraktor != null) ...[
                const Divider(),
                _buildReviewRow(
                    'Perusahaan Kontraktor', _perusahaanKontraktor!),
              ],
              if (_subKontraktor != null) ...[
                const Divider(),
                _buildReviewRow('Sub-Kontraktor', _subKontraktor!),
              ],
              const Divider(),
              _buildReviewRow('Departemen', _departemen ?? '-'),
              const Divider(),
              _buildReviewRow('Jabatan',
                  _jabatanCtrl.text.isEmpty ? '-' : _jabatanCtrl.text),
              const Divider(),
              _buildReviewRow(
                  'Email Kantor',
                  _emailKantorCtrl.text.isEmpty
                      ? '— (opsional)'
                      : _emailKantorCtrl.text,
                  isGrey: _emailKantorCtrl.text.isEmpty),
              const Divider(),
              _buildReviewRow('SIMPER',
                  _simperCtrl.text.isEmpty ? '— (opsional)' : _simperCtrl.text,
                  isGrey: _simperCtrl.text.isEmpty),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Key info
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F3FF),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.vpn_key, color: Color(0xFF8B5CF6), size: 16),
                  const SizedBox(width: 8),
                  const Text('Kamu bisa login menggunakan:',
                      style: TextStyle(
                          color: Color(0xFF6D28D9),
                          fontWeight: FontWeight.bold,
                          fontSize: 13)),
                ],
              ),
              const SizedBox(height: 8),
              _buildBullet(
                  'Email pribadi (${_emailCtrl.text.isEmpty ? "..." : _emailCtrl.text})'),
              _buildBullet(
                  'Employee ID (${_empIdCtrl.text.isEmpty ? "..." : _empIdCtrl.text})'),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Hourglass info
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.hourglass_empty,
                  color: Color(0xFFD97706), size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: 'Setelah mendaftar, akun perlu ',
                    style:
                        const TextStyle(color: Color(0xFF92400E), fontSize: 12),
                    children: [
                      TextSpan(
                          text: 'disetujui Supervisor\n',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(
                          text:
                              'departemen ${_departemen ?? "HSE"}. Estimasi: dalam 1 jam kerja.'),
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

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 24, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: Color(0xFF6D28D9))),
          Expanded(
              child: Text(text,
                  style:
                      const TextStyle(color: Color(0xFF6D28D9), fontSize: 13))),
        ],
      ),
    );
  }

  Widget _buildReviewRow(String label, String value,
      {bool isBadge = false, bool isGrey = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(
            child: isBadge
                ? Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD1FAE5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Karyawan $value',
                          style: const TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  )
                : Text(
                    value,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isGrey ? Colors.grey : Colors.black87,
                      fontWeight: isGrey ? FontWeight.normal : FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAfiliasiBtn(String title, IconData icon) {
    bool isSelected = _tipeAfiliasi == title;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tipeAfiliasi = title;
            if (title == 'Owner') {
              _perusahaanKontraktor = null;
              _subKontraktor = null;
            } else if (title == 'Kontraktor') {
              _subKontraktor = null;
            }
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEEF2FF) : Colors.white,
            border: Border.all(
                color: isSelected
                    ? const Color(0xFF6366F1)
                    : Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF6366F1) : Colors.grey),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected ? const Color(0xFF6366F1) : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    bool isRequired = true,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1A56C4))),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: Colors.white,
          ),
          validator: validator ??
              (isRequired
                  ? (v) =>
                      (v == null || v.isEmpty) ? 'Wajib diisi' : null
                  : null),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Text(text,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Color(0xFF4B5563)));
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required ValueChanged<String?> onChanged,
    bool isRequired = true,
  }) {
    return Container(
      decoration: kMinimalFieldContainerDecoration,
      child: DropdownButtonFormField<String>(
        // ignore: deprecated_member_use
        value: value,
        isExpanded: true,
        icon: kMinimalDropdownChevron,
        borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
        style: kMinimalDropdownTextStyle,
        items: items
            .map((e) => DropdownMenuItem(
                value: e,
                child: Text(e, style: kMinimalDropdownTextStyle)))
            .toList(),
        onChanged: onChanged,
        decoration: minimalFieldDecoration(hintText: hint),
        validator:
            isRequired ? (v) => v == null ? 'Wajib dipilih' : null : null,
      ),
    );
  }

  Widget _buildBottomButton() {
    String label = '';
    if (_currentStep == 1) label = 'Lanjut → Informasi Karyawan';
    if (_currentStep == 2) label = 'Lanjut → Tinjau Pendaftaran';
    if (_currentStep == 3) label = 'Kirim Pendaftaran';

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed:
            _isLoading ? null : (_currentStep == 3 ? _submit : _nextStep),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF1A56C4),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          elevation: 0,
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_currentStep == 3) const Icon(Icons.how_to_reg, size: 18),
                  if (_currentStep == 3) const SizedBox(width: 8),
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                ],
              ),
      ),
    );
  }
}
