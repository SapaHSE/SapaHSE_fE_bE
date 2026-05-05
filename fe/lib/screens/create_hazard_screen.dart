import 'dart:io' show File;
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:path_provider/path_provider.dart';
import '../data/report_store.dart';
import '../models/company_model.dart';
import '../models/report.dart';
import '../services/cloud_save_service.dart';
import '../services/company_service.dart';
import '../services/report_service.dart';
import 'map_picker_screen.dart';

// ── Screen ────────────────────────────────────────────────────────────────────

class CreateHazardScreen extends StatefulWidget {
  const CreateHazardScreen({super.key});

  @override
  State<CreateHazardScreen> createState() => _CreateHazardScreenState();
}

class _CreateHazardScreenState extends State<CreateHazardScreen> {
  static const _blue = Color(0xFF1A56C4);
  static const _bgColor = Color(0xFFF0F0F0);

  int _currentStep = 0;

  // Step key anchors for scroll-to-top
  final _step1Key = GlobalKey();
  final _step2Key = GlobalKey();
  final _step3Key = GlobalKey();

  // Form keys
  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  // ── API-loaded data ──────────────────────────────────────────────────────────
  List<HazardCategoryData> _apiCategories = [];
  List<String> _apiDepartments = [];
  List<UserEntry> _apiUsers = [];
  List<CompanyData> _apiCompanies = [];
  List<AreaData> _apiAreas = [];
  bool _isLoadingData = true;
  bool _isLoadingAreas = false;

  // ── Step 1 state ─────────────────────────────────────────────────────────────
  String? _selectedKategori;
  String? _selectedKategoriCode; // TTA / KTA for API
  String? _selectedSubkategori;
  String? _selectedPerusahaan;
  int? _selectedCompanyId;
  final Set<String> _selectedDepts = {};
  final Set<UserEntry> _selectedUsers = {};
  static const _hseKeywords = ['hse', 'k3'];

  bool get _hasPicSelection =>
      _selectedDepts.isNotEmpty || _selectedUsers.isNotEmpty;
  bool get _canPickSubcategory =>
      !_isLoadingData &&
      _selectedKategori != null &&
      _selectedKategori!.trim().isNotEmpty;
  bool get _canPickCompany =>
      _canPickSubcategory &&
      _selectedSubkategori != null &&
      _selectedSubkategori!.trim().isNotEmpty;
  bool get _canOpenTagPicker =>
      _canPickCompany &&
      _selectedPerusahaan != null &&
      _selectedPerusahaan!.trim().isNotEmpty;
  bool get _canPickSeverity =>
      _canPickCompany &&
      _selectedPerusahaan != null &&
      _selectedPerusahaan!.trim().isNotEmpty &&
      _selectedCompanyId != null &&
      !_isLoadingAreas;
  bool _isLockedDept(String dept) {
    final normalized = dept.toLowerCase();
    return _hseKeywords.any(normalized.contains);
  }

  Set<String> get _lockedDepts =>
      _apiDepartments.where(_isLockedDept).toSet();

  void _ensureLockedDeptsSelected() {
    if (_lockedDepts.isEmpty) return;
    _selectedDepts.addAll(_lockedDepts);
  }

  // ── Step 2 state ─────────────────────────────────────────────────────────────
  final _titleCtrl = TextEditingController();
  ReportSeverity? _selectedSeverity;
  final _kronologiCtrl = TextEditingController();
  final _saranCtrl = TextEditingController();
  final Set<UserEntry> _selectedPelaku = {};
  String? _selectedLokasi;
  final _locationCtrl = TextEditingController();
  final _pelaporLocationCtrl = TextEditingController();
  final _kejadianLocationCtrl = TextEditingController();
  final List<XFile> _photoFiles = [];
  final _picker = ImagePicker();

  // ── Step 3 state ─────────────────────────────────────────────────────────────
  bool _isPublic = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadFormData();
    _fetchPelaporLocationSilent();
  }

  Future<void> _loadFormData() async {
    final results = await Future.wait([
      ReportService.getHazardCategories(),
      ReportService.getDepartments(),
      ReportService.getUsers(),
      CompanyService.getCompanies(category: 'owner'),
    ]);
    if (!mounted) return;
    setState(() {
      _apiCategories = results[0] as List<HazardCategoryData>;
      _apiDepartments = results[1] as List<String>;
      _apiUsers = results[2] as List<UserEntry>;
      _apiCompanies = results[3] as List<CompanyData>;
      _ensureLockedDeptsSelected();
      _isLoadingData = false;
    });
  }

  Future<void> _loadAreasForCompany(int? companyId) async {
    if (companyId == null) {
      if (!mounted) return;
      setState(() {
        _apiAreas = [];
        _isLoadingAreas = false;
      });
      return;
    }

    setState(() => _isLoadingAreas = true);
    try {
      final areas = await CompanyService.getAreas(companyId: companyId, active: true);
      if (!mounted) return;
      setState(() {
        _apiAreas = areas;
        _isLoadingAreas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _apiAreas = [];
        _isLoadingAreas = false;
      });
      debugPrint('Gagal load area company: $e');
    }
  }

  Future<void> _fetchPelaporLocationSilent() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        final pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium));
        if (mounted) {
          final loc = '${pos.latitude}, ${pos.longitude}';
          _pelaporLocationCtrl.text = loc;
          if (_kejadianLocationCtrl.text.isEmpty) {
            _kejadianLocationCtrl.text = loc;
          }
        }
      }
    } catch (e) {
      debugPrint('Gagal fetch lokasi pelapor: $e');
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _kronologiCtrl.dispose();
    _saranCtrl.dispose();
    _locationCtrl.dispose();
    _pelaporLocationCtrl.dispose();
    _kejadianLocationCtrl.dispose();
    super.dispose();
  }

  // ── Derived lists (API-driven) ───────────────────────────────────────────────

  List<String> get _kategoriList =>
      _apiCategories.map((c) => c.name).toList();

  List<String> get _subkategoriList {
    if (_selectedKategori == null) return [];
    final cat = _apiCategories.where((c) => c.name == _selectedKategori);
    if (cat.isEmpty) return [];
    return cat.first.subcategories.map((s) => s.name).toList();
  }

  List<String> get _perusahaanList =>
      _apiCompanies.map((company) => company.name).toList();

  List<String> get _lokasiList =>
      _apiAreas.map((area) => area.name).toList();

  void _handleCompanySelected(String? value) {
    final selectedCompany = _apiCompanies
        .cast<CompanyData?>()
        .firstWhere((company) => company?.name == value, orElse: () => null);

    setState(() {
      _selectedPerusahaan = value;
      _selectedCompanyId = selectedCompany?.id;
      _selectedDepts.clear();
      _ensureLockedDeptsSelected();
      _selectedUsers.clear();
      _selectedLokasi = null;
      _locationCtrl.clear();
      _apiAreas = [];
    });

    _loadAreasForCompany(_selectedCompanyId);
  }

  // ── Navigation ────────────────────────────────────────────────────────────────

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey1.currentState!.validate()) return;
      if (_selectedPerusahaan == null || !_hasPicSelection) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Perusahaan dan PIC wajib diisi'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() => _currentStep++);
      _scrollToTop();
    } else if (_currentStep == 1) {
      if (!_formKey2.currentState!.validate()) return;
      if (_selectedSeverity == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Status risiko wajib dipilih'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      _showPinpointConfirmationDialog(() {
        setState(() => _currentStep++);
        _scrollToTop();
      });
    } else {
      _submitReport();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _scrollToTop();
    }
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _currentStep == 0
          ? _step1Key
          : _currentStep == 1
              ? _step2Key
              : _step3Key;
      if (key.currentContext != null) {
        Scrollable.ensureVisible(
          key.currentContext!,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  // ── Location helpers ──────────────────────────────────────────────────────────

  Future<void> _pickLocationFromMap(TextEditingController ctrl) async {
    LatLng? current;
    if (ctrl.text.isNotEmpty) {
      final parts = ctrl.text.split(',');
      if (parts.length == 2) {
        final lat = double.tryParse(parts[0].trim());
        final lng = double.tryParse(parts[1].trim());
        if (lat != null && lng != null) {
          current = LatLng(lat, lng);
        }
      }
    }

    final LatLng? result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapPickerScreen(initialLocation: current),
      ),
    );

    if (result != null) {
      setState(() {
        ctrl.text = '${result.latitude}, ${result.longitude}';
      });
    }
  }

  // ── Photo picker ──────────────────────────────────────────────────────────────

  Future<XFile?> _compressAndConvertImage(XFile file) async {
    try {
      if (kIsWeb) return file;
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_compressed.jpg';
      final result = await FlutterImageCompress.compressAndGetFile(
        file.path,
        targetPath,
        quality: 80,
        format: CompressFormat.jpeg,
      );
      return result == null ? file : XFile(result.path);
    } catch (e) {
      debugPrint('Compression error: $e');
      return file;
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1280,
        );
        if (picked.isNotEmpty) {
          for (final file in picked) {
            final compressed = await _compressAndConvertImage(file);
            if (compressed != null) {
              setState(() => _photoFiles.add(compressed));
            }
          }
        }
      } else {
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1280,
        );
        if (picked != null) {
          final compressed = await _compressAndConvertImage(picked);
          if (compressed != null) setState(() => _photoFiles.add(compressed));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
        ));
      }
    }
  }

  void _showPinpointConfirmationDialog(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Konfirmasi Pinpoint',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Apakah lokasi kejadian (pinpoint) sudah sesuai?',
              style: TextStyle(color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: _blue, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _kejadianLocationCtrl.text,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue,
              foregroundColor: Colors.white,
            ),
            child: const Text(
              'Ya, Lanjut',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  // ── Submit ────────────────────────────────────────────────────────────────────

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    final online = await CloudSaveService.isOnline();

    final String? categoryCode = _selectedKategoriCode;

    final String? department =
        _selectedDepts.isEmpty ? null : _selectedDepts.join(', ');
    final String? picDepartment = _selectedUsers.isEmpty
        ? null
        : _selectedUsers.map((u) => u.fullName).join(', ');
    final pelakuStr = _selectedPelaku.isNotEmpty
        ? _selectedPelaku.map((u) => u.fullName).join(', ')
        : null;
    final severity = _selectedSeverity?.name ?? 'medium';

    final data = {
      'title': _titleCtrl.text.trim(),
      'kronologi': _kronologiCtrl.text.trim(),
      'saran': _saranCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'area': _selectedLokasi,
      'pelaporLocation': _pelaporLocationCtrl.text.trim(),
      'kejadianLocation': _kejadianLocationCtrl.text.trim(),
      'perusahaan': _selectedPerusahaan,
      'department': department,
      'pic': picDepartment,
      'pelakuPelanggaran': pelakuStr,
      'severity': severity,
      'kategori': categoryCode,
      'subkategori': _selectedSubkategori,
      'photoPaths': _photoFiles.map((f) => f.path).toList(),
      'isPublic': _isPublic,
    };

    if (!online) {
      final draft = ReportDraft(
        id: 'hazard_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
        type: DraftType.hazard,
        title: _titleCtrl.text.trim(),
        data: data,
        createdAt: DateTime.now(),
      );
      await CloudSaveService.instance.saveDraft(draft);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showResultDialog(
        isOffline: true,
        title: 'Tersimpan sebagai Draft',
        message: 'Tidak ada koneksi internet. Laporan disimpan secara lokal.',
      );
    } else {
      try {
        await ReportStore.instance.createHazardReport(
          title: _titleCtrl.text.trim(),
          description: _kronologiCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          severity: severity,
          company: _selectedPerusahaan,
          area: _selectedLokasi,
          picDepartment: picDepartment,
          department: department,
          hazardCategory: categoryCode,
          hazardSubcategory: _selectedSubkategori,
          suggestion: _saranCtrl.text.trim(),
          pelakuPelanggaran: pelakuStr,
          pelaporLocation: _pelaporLocationCtrl.text.trim(),
          kejadianLocation: _kejadianLocationCtrl.text.trim(),
          imagePath: _photoFiles.isNotEmpty ? _photoFiles.first.path : null,
          isPublic: _isPublic,
        );

        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showResultDialog(
          isOffline: false,
          title: 'Laporan Terkirim!',
          message: 'Laporan hazard Anda berhasil dikirim.',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim laporan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showResultDialog({
    required bool isOffline,
    required String title,
    required String message,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isOffline ? Icons.cloud_off : Icons.check_circle_outline,
              color: isOffline ? Colors.orange : _blue,
              size: 50,
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: _blue, foregroundColor: Colors.white),
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  // ── UI helpers ────────────────────────────────────────────────────────────────

  InputDecoration _inputDeco({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5)),
    );
  }

  InputDecorationTheme _dropdownTheme() {
    return InputDecorationTheme(
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      filled: true,
      fillColor: const Color(0xFFF8F9FF),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: _blue, width: 1.5)),
      constraints: const BoxConstraints(maxHeight: 50),
    );
  }

  Widget _label(String text, {Key? key}) => Padding(
        key: key,
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      );

  // ── Tag field widgets ─────────────────────────────────────────────────────────

  Widget _picTagField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('PIC / Departemen Terkait *'),
        GestureDetector(
          onTap: _canOpenTagPicker ? _showUnifiedPicker : null,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color: _canOpenTagPicker
                  ? const Color(0xFFF8F9FF)
                  : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color:
                    _canOpenTagPicker ? Colors.grey.shade300 : Colors.grey.shade200,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add_outlined,
                    size: 20,
                    color: _canOpenTagPicker
                        ? Colors.grey
                        : Colors.grey.shade400),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ketuk untuk tag orang atau departemen',
                    style: TextStyle(
                      color: _canOpenTagPicker
                          ? Colors.grey
                          : Colors.grey.shade500,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_isLoadingData)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.grey))
                else
                  Icon(Icons.arrow_forward_ios,
                      size: 14,
                      color: _canOpenTagPicker
                          ? Colors.grey.shade400
                          : Colors.grey.shade300),
              ],
            ),
          ),
        ),
        if (_canOpenTagPicker && _hasPicSelection) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ..._selectedDepts.map((dept) => Chip(
                    label: Text(dept, style: const TextStyle(fontSize: 12)),
                    onDeleted: _isLockedDept(dept)
                        ? null
                        : () => setState(() => _selectedDepts.remove(dept)),
                    deleteIcon:
                        _isLockedDept(dept) ? null : const Icon(Icons.close, size: 14),
                    backgroundColor: _blue.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: _blue.withValues(alpha: 0.2)),
                  )),
              ..._selectedUsers.map((user) => Chip(
                    label: Text(user.fullName,
                        style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _selectedUsers
                        .removeWhere((u) => u.fullName == user.fullName)),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    backgroundColor: Colors.orange.withValues(alpha: 0.1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(
                        color: Colors.orange.withValues(alpha: 0.2)),
                  )),
            ],
          ),
        ],
      ],
    );
  }

  void _showUnifiedPicker() {
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = query.toLowerCase();
          final filteredDepts = _apiDepartments
              .where((d) => d.toLowerCase().contains(q))
              .toList();
          final filteredUsers = _apiUsers
              .where((u) =>
                  u.fullName.toLowerCase().contains(q) ||
                  (u.department?.toLowerCase().contains(q) ?? false))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Tag Departemen / PJA',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari departemen atau nama...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (_hasPicSelection) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('TERPILIH',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  letterSpacing: 0.5)),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              ..._selectedDepts.map((dept) => Chip(
                                    label: Text(dept,
                                        style:
                                            const TextStyle(fontSize: 12)),
                                    onDeleted: _isLockedDept(dept)
                                        ? null
                                        : () {
                                            setState(() =>
                                                _selectedDepts.remove(dept));
                                            setSheetState(() {});
                                          },
                                    deleteIcon: _isLockedDept(dept)
                                        ? null
                                        : const Icon(Icons.close, size: 14),
                                    backgroundColor:
                                        _blue.withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    side: BorderSide(
                                        color:
                                            _blue.withValues(alpha: 0.2)),
                                  )),
                              ..._selectedUsers.map((user) => Chip(
                                    label: Text(user.fullName,
                                        style:
                                            const TextStyle(fontSize: 12)),
                                    onDeleted: () {
                                      setState(() => _selectedUsers
                                          .removeWhere((u) =>
                                              u.fullName == user.fullName));
                                      setSheetState(() {});
                                    },
                                    deleteIcon:
                                        const Icon(Icons.close, size: 14),
                                    backgroundColor: Colors.orange
                                        .withValues(alpha: 0.1),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    side: BorderSide(
                                        color: Colors.orange
                                            .withValues(alpha: 0.2)),
                                  )),
                            ],
                          ),
                        ),
                        const Divider(height: 32),
                      ],
                      if (filteredDepts.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('DEPARTEMEN',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        ...filteredDepts.map((dept) {
                          final isSelected = _selectedDepts.contains(dept);
                          final isLocked = _isLockedDept(dept);
                          return ListTile(
                            leading: const Icon(Icons.business_outlined,
                                size: 20),
                            title: Text(
                              dept,
                              style: TextStyle(
                                fontSize: 14,
                                color: isLocked ? Colors.grey.shade500 : null,
                              ),
                            ),
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isLocked
                                  ? Colors.grey.shade400
                                  : isSelected
                                      ? _blue
                                      : Colors.grey,
                            ),
                            onTap: isLocked
                                ? null
                                : () {
                              setState(() {
                                if (isSelected) {
                                  _selectedDepts.remove(dept);
                                } else {
                                  _selectedDepts.add(dept);
                                }
                              });
                              setSheetState(() {});
                            },
                          );
                        }),
                      ],
                      if (filteredUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('PJA (PERSON IN CHARGE)',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        ...filteredUsers.map((user) {
                          final isSelected = _selectedUsers
                              .any((u) => u.fullName == user.fullName);
                          return ListTile(
                            leading: const Icon(Icons.person_outline,
                                size: 20),
                            title: Text(user.fullName,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: user.department != null
                                ? Text(user.department!,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey))
                                : null,
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSelected ? _blue : Colors.grey,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedUsers.removeWhere(
                                      (u) => u.fullName == user.fullName);
                                } else {
                                  _selectedUsers.add(user);
                                }
                              });
                              setSheetState(() {});
                            },
                          );
                        }),
                      ],
                      if (filteredDepts.isEmpty && filteredUsers.isEmpty)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text('Tidak ditemukan',
                                    style:
                                        TextStyle(color: Colors.grey)))),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Selesai',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _pelakuTagField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Pelaku Pelanggaran (Opsional)'),
        GestureDetector(
          onTap: _isLoadingData ? null : _showPelakuPicker,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: BoxDecoration(
              color:
                  _isLoadingData ? Colors.grey.shade100 : const Color(0xFFF8F9FF),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _isLoadingData
                    ? Colors.grey.shade200
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.person_add_outlined,
                    size: 20,
                    color: _isLoadingData ? Colors.grey.shade400 : Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Ketuk untuk tag pelaku',
                    style: TextStyle(
                      color: _isLoadingData ? Colors.grey.shade500 : Colors.grey,
                      fontSize: 13,
                    ),
                  ),
                ),
                if (_isLoadingData)
                  const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.grey))
                else
                  Icon(Icons.arrow_forward_ios,
                      size: 14, color: Colors.grey.shade400),
              ],
            ),
          ),
        ),
        if (_selectedPelaku.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _selectedPelaku
                .map((user) => Chip(
                      label: Text(user.fullName,
                          style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      onDeleted: () => setState(() => _selectedPelaku
                          .removeWhere((u) => u.fullName == user.fullName)),
                    ))
                .toList(),
          ),
        ],
      ],
    );
  }

  void _showPelakuPicker() {
    String query = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          final q = query.toLowerCase();
          final filteredUsers = _apiUsers
              .where((u) =>
                  u.fullName.toLowerCase().contains(q) ||
                  (u.department?.toLowerCase().contains(q) ?? false))
              .toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2)),
                ),
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Tag Pelaku Pelanggaran',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 18)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Cari nama user...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (v) => setSheetState(() => query = v),
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    children: [
                      if (_selectedPelaku.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('TERPILIH',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue,
                                  letterSpacing: 0.5)),
                        ),
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: _selectedPelaku.map((user) {
                              return Chip(
                                label: Text(user.fullName,
                                    style: const TextStyle(fontSize: 12)),
                                onDeleted: () {
                                  setState(() => _selectedPelaku.removeWhere(
                                      (u) => u.fullName == user.fullName));
                                  setSheetState(() {});
                                },
                                deleteIcon: const Icon(Icons.close, size: 14),
                                backgroundColor:
                                    Colors.orange.withValues(alpha: 0.1),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20)),
                                side: BorderSide(
                                    color:
                                        Colors.orange.withValues(alpha: 0.2)),
                              );
                            }).toList(),
                          ),
                        ),
                        const Divider(height: 32),
                      ],
                      if (filteredUsers.isNotEmpty) ...[
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                          child: Text('USER',
                              style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                  letterSpacing: 0.5)),
                        ),
                        ...filteredUsers.map((user) {
                          final isSelected = _selectedPelaku
                              .any((u) => u.fullName == user.fullName);
                          return ListTile(
                            leading: const Icon(Icons.person_outline,
                                size: 20),
                            title: Text(user.fullName,
                                style: const TextStyle(fontSize: 14)),
                            subtitle: user.department != null
                                ? Text(user.department!,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.grey))
                                : null,
                            trailing: Icon(
                              isSelected
                                  ? Icons.check_circle
                                  : Icons.add_circle_outline,
                              color: isSelected ? _blue : Colors.grey,
                            ),
                            onTap: () {
                              setState(() {
                                if (isSelected) {
                                  _selectedPelaku.removeWhere(
                                      (u) => u.fullName == user.fullName);
                                } else {
                                  _selectedPelaku.add(user);
                                }
                              });
                              setSheetState(() {});
                            },
                          );
                        }),
                      ],
                      if (filteredUsers.isEmpty)
                        const Center(
                            child: Padding(
                                padding: EdgeInsets.all(40),
                                child: Text('Tidak ditemukan',
                                    style:
                                        TextStyle(color: Colors.grey)))),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Selesai',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── Step 1 ────────────────────────────────────────────────────────────────────

  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Kategori Hazard *', key: _step1Key),
          if (_isLoadingData)
            const Center(child: CircularProgressIndicator())
          else
            DropdownButtonFormField<String>(
              key: ValueKey('kategori_$_selectedKategori'),
              initialValue: _selectedKategori,
              validator: (v) => v == null ? 'Wajib dipilih' : null,
              decoration: _inputDeco(
                  hint: 'Pilih Kategori', icon: Icons.category_outlined),
              items: _kategoriList
                  .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                  .toList(),
              onChanged: (v) => setState(() {
                _selectedKategori = v;
                _selectedSubkategori = null;
                _selectedPerusahaan = null;
                _selectedCompanyId = null;
                _apiAreas = [];
                _selectedLokasi = null;
                _locationCtrl.clear();
                _selectedDepts.clear();
                _selectedUsers.clear();
                final cat = _apiCategories.where((c) => c.name == v);
                _selectedKategoriCode =
                    cat.isNotEmpty ? cat.first.code : null;
              }),
          ),
          const SizedBox(height: 14),
          _label('Subkategori Hazard *'),
          Opacity(
            opacity: _canPickSubcategory ? 1 : 0.6,
            child: IgnorePointer(
              ignoring: !_canPickSubcategory,
              child: DropdownButtonFormField<String>(
                key: ValueKey('subkategori_$_selectedSubkategori'),
                initialValue: _selectedSubkategori,
                validator: (v) => v == null ? 'Wajib dipilih' : null,
                decoration: _inputDeco(
                    hint: 'Pilih Subkategori',
                    icon: Icons.subdirectory_arrow_right),
                items: _subkategoriList
                    .map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(e, style: const TextStyle(fontSize: 13))))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedSubkategori = v;
                  _selectedPerusahaan = null;
                  _selectedCompanyId = null;
                  _apiAreas = [];
                  _selectedLokasi = null;
                  _locationCtrl.clear();
                  _selectedDepts.clear();
                  _selectedUsers.clear();
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Perusahaan (Ketik untuk mencari) *'),
          Opacity(
            opacity: _canPickCompany ? 1 : 0.6,
            child: IgnorePointer(
              ignoring: !_canPickCompany,
              child: LayoutBuilder(
                builder: (context, constraints) => DropdownMenu<String>(
                  enabled: _canPickCompany,
                  width: constraints.maxWidth,
                  enableSearch: true,
                  enableFilter: true,
                  requestFocusOnTap: true,
                  initialSelection: _selectedPerusahaan,
                  hintText: 'Pilih / Cari Perusahaan',
                  inputDecorationTheme: _dropdownTheme(),
                  onSelected: _handleCompanySelected,
                  dropdownMenuEntries: _perusahaanList
                      .map((e) => DropdownMenuEntry(value: e, label: e))
                      .toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _picTagField(),
        ],
      ),
    );
  }

  // ── Step 2 ────────────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Form(
      key: _formKey2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Judul Laporan *', key: _step2Key),
          TextFormField(
            controller: _titleCtrl,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(hint: 'Judul laporan'),
          ),
          const SizedBox(height: 14),
          _label('Status Resiko *'),
          Opacity(
            opacity: _canPickSeverity ? 1 : 0.45,
            child: IgnorePointer(
              ignoring: !_canPickSeverity,
              child: Row(
                children: [
                  ReportSeverity.low,
                  ReportSeverity.medium,
                  ReportSeverity.high,
                ].map((s) {
                  final isSelected = _selectedSeverity == s;
                  final colors = {
                    ReportSeverity.low: Colors.green,
                    ReportSeverity.medium: Colors.orange,
                    ReportSeverity.high: Colors.red,
                  };
                  final baseColor = colors[s]!;
                  return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedSeverity = s),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? baseColor
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: _canPickSeverity
                                ? (isSelected ? baseColor : Colors.grey.shade300)
                                : Colors.grey.shade300,
                            width: isSelected ? 2 : 1),
                      ),
                      child: Text(
                        s.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Deskripsi Kronologi *'),
          TextFormField(
            controller: _kronologiCtrl,
            maxLines: 3,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(hint: 'Jelaskan kronologi...'),
          ),
          const SizedBox(height: 14),
          _label('Deskripsi Saran (Opsional)'),
          TextFormField(
            controller: _saranCtrl,
            maxLines: 3,
            decoration: _inputDeco(hint: 'Saran perbaikan...'),
          ),
          const SizedBox(height: 14),
          _pelakuTagField(),
          const SizedBox(height: 14),
          _label('Lokasi Kejadian *'),
          Opacity(
            opacity: _selectedCompanyId != null && !_isLoadingAreas ? 1 : 0.5,
            child: IgnorePointer(
              ignoring: _selectedCompanyId == null || _isLoadingAreas,
              child: DropdownButtonFormField<String>(
                key: ValueKey('lokasi_$_selectedLokasi'),
                initialValue: _selectedLokasi,
                validator: (v) => v == null ? 'Wajib dipilih' : null,
                decoration: _inputDeco(
                    hint: _isLoadingAreas
                        ? 'Memuat lokasi...'
                        : (_selectedCompanyId == null
                            ? 'Pilih company di Step 1'
                            : 'Pilih Lokasi Kejadian'),
                    icon: Icons.location_city),
                items: _lokasiList
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _selectedLokasi = v;
                  _locationCtrl.text = v ?? '';
                }),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Pinpoint Lokasi Kejadian *'),
          TextFormField(
            controller: _kejadianLocationCtrl,
            readOnly: true,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(
              hint: 'Koordinat Kejadian',
              icon: Icons.place,
            ).copyWith(
              suffixIcon: IconButton(
                icon: const Icon(Icons.map_outlined),
                onPressed: () =>
                    _pickLocationFromMap(_kejadianLocationCtrl),
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Foto (Opsional)'),
          if (_photoFiles.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _photoFiles.length,
                itemBuilder: (context, index) {
                  final photo = _photoFiles[index];
                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 120,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? Image.network(photo.path,
                                  fit: BoxFit.cover)
                              : Image.file(File(photo.path),
                                  fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () => setState(
                                () => _photoFiles.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16),
                            ),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),
            ),
          if (_photoFiles.isNotEmpty) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Kamera'))),
              const SizedBox(width: 8),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: () => _pickPhoto(ImageSource.gallery),
                      icon: const Icon(Icons.photo),
                      label: const Text('Galeri'))),
            ],
          ),
        ],
      ),
    );
  }

  // ── Step 3 ────────────────────────────────────────────────────────────────────

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Review Laporan Akhir',
                  key: _step3Key,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              _previewItem('Kategori',
                  '$_selectedKategori - $_selectedSubkategori'),
              _previewItem('Perusahaan', '$_selectedPerusahaan'),
              _previewItem(
                  'Departemen',
                  _selectedDepts.isEmpty
                      ? '-'
                      : _selectedDepts.join(', ')),
              _previewItem(
                  'PJA',
                  _selectedUsers.isEmpty
                      ? '-'
                      : _selectedUsers
                          .map((u) => u.fullName)
                          .join(', ')),
              _previewItem('Judul', _titleCtrl.text),
              _previewItem(
                  'Resiko', _selectedSeverity?.name.toUpperCase() ?? '-'),
              _previewItem('Kronologi', _kronologiCtrl.text),
              if (_saranCtrl.text.trim().isNotEmpty)
                _previewItem('Saran', _saranCtrl.text),
              if (_selectedPelaku.isNotEmpty)
                _previewItem(
                    'Pelaku Pelanggaran',
                    _selectedPelaku.map((u) => u.fullName).join(', ')),
              _previewItem('Lokasi', _selectedLokasi ?? '-'),
              if (_photoFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Foto:',
                    style: TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 4),
                SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoFiles.length,
                    itemBuilder: (context, index) {
                      final photo = _photoFiles[index];
                      return GestureDetector(
                        onTap: () => _showPhotoZoom(context, photo),
                        child: Container(
                          width: 120,
                          margin: const EdgeInsets.only(right: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: kIsWeb
                                ? Image.network(photo.path,
                                    fit: BoxFit.cover)
                                : Image.file(File(photo.path),
                                    fit: BoxFit.cover),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                const Text('Ketuk foto untuk memperbesar',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey,
                        fontStyle: FontStyle.italic)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('Pengaturan Privasi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            children: [
              RadioListTile<bool>(
                title: const Text('Public'),
                subtitle: const Text(
                    'Laporan dapat dilihat oleh semua orang di menu Utama',
                    style: TextStyle(fontSize: 12)),
                value: true,
                // ignore: deprecated_member_use
                groupValue: _isPublic,
                activeColor: _blue,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
              RadioListTile<bool>(
                title: const Text('Private'),
                subtitle: const Text(
                    'Laporan hanya dilihat oleh Anda dan pihak terkait',
                    style: TextStyle(fontSize: 12)),
                value: false,
                // ignore: deprecated_member_use
                groupValue: _isPublic,
                activeColor: _blue,
                // ignore: deprecated_member_use
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
            ],
          ),
        ),
        if (!_isPublic) ...[
          const SizedBox(height: 20),
          const Text('Tambah Departemen / PIC (CC / Tembusan)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          const Text(
              'Tambahkan pihak lain yang perlu menerima laporan ini.',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _canOpenTagPicker ? _showUnifiedPicker : null,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 13),
                    decoration: BoxDecoration(
                      color: _canOpenTagPicker
                          ? const Color(0xFFF8F9FF)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _canOpenTagPicker
                            ? Colors.grey.shade300
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.person_add_outlined,
                            size: 20,
                            color: _canOpenTagPicker
                                ? Colors.grey
                                : Colors.grey.shade400),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Ketuk untuk tag orang atau departemen',
                            style: TextStyle(
                                color: _canOpenTagPicker
                                    ? Colors.grey
                                    : Colors.grey.shade500,
                                fontSize: 13),
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios,
                            size: 14,
                            color: _canOpenTagPicker
                                ? Colors.grey.shade400
                                : Colors.grey.shade300),
                      ],
                    ),
                  ),
                ),
                if (_canOpenTagPicker && _hasPicSelection) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ..._selectedDepts.map((dept) => Chip(
                            label: Text(dept,
                                style: const TextStyle(fontSize: 12)),
                            onDeleted: _isLockedDept(dept)
                                ? null
                                : () => setState(
                                    () => _selectedDepts.remove(dept)),
                            deleteIcon: _isLockedDept(dept)
                                ? null
                                : const Icon(Icons.close, size: 14),
                            backgroundColor:
                                _blue.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(20)),
                            side: BorderSide(
                                color: _blue.withValues(alpha: 0.2)),
                          )),
                      ..._selectedUsers.map((user) => Chip(
                            label: Text(user.fullName,
                                style: const TextStyle(fontSize: 12)),
                            onDeleted: () => setState(() =>
                                _selectedUsers.removeWhere((u) =>
                                    u.fullName == user.fullName)),
                            deleteIcon:
                                const Icon(Icons.close, size: 14),
                            backgroundColor:
                                Colors.orange.withValues(alpha: 0.1),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(20)),
                            side: BorderSide(
                                color: Colors.orange
                                    .withValues(alpha: 0.2)),
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _previewItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 110,
              child: Text(label,
                  style: const TextStyle(
                      color: Colors.grey, fontSize: 13))),
          const Text(': ',
              style: TextStyle(color: Colors.grey, fontSize: 13)),
          Expanded(
              child: Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 13))),
        ],
      ),
    );
  }

  void _showPhotoZoom(BuildContext context, XFile photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              boundaryMargin: const EdgeInsets.all(20),
              minScale: 0.5,
              maxScale: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: kIsWeb
                    ? Image.network(photo.path)
                    : Image.file(File(photo.path)),
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: IconButton(
                icon: const Icon(Icons.close,
                    color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Buat Laporan Hazard',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: Stepper(
        type: StepperType.horizontal,
        currentStep: _currentStep,
        elevation: 0,
        controlsBuilder: (context, details) {
          final isLastStep = _currentStep == 2;
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: details.onStepCancel,
                      style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Kembali'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(
                            isLastStep
                                ? 'Kirim Laporan'
                                : 'Selanjutnya',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
        onStepContinue: _nextStep,
        onStepCancel: _prevStep,
        steps: [
          Step(
            isActive: _currentStep >= 0,
            state: _currentStep > 0
                ? StepState.complete
                : StepState.indexed,
            title: const Text('Data', style: TextStyle(fontSize: 12)),
            content: _buildStep1(),
          ),
          Step(
            isActive: _currentStep >= 1,
            state: _currentStep > 1
                ? StepState.complete
                : StepState.indexed,
            title:
                const Text('Detail', style: TextStyle(fontSize: 12)),
            content: _buildStep2(),
          ),
          Step(
            isActive: _currentStep >= 2,
            title:
                const Text('Review', style: TextStyle(fontSize: 12)),
            content: _buildStep3(),
          ),
        ],
      ),
    );
  }
}

