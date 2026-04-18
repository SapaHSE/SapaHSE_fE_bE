import 'dart:io' show File;
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report.dart';
import '../data/report_store.dart';
import '../services/cloud_save_service.dart';

// ── Data: Departemen & PJA ─────────────────────────────────────────────────
const _departemenList = [
  'Mining', 'Processing', 'Maintenance', 'HSE',
  'HR', 'Finance', 'IT', 'Operations',
];

const _pjaByDepartemen = <String, List<String>>{
  'Mining':      ['Budi Santoso', 'Ahmad Fauzi', 'Riko Pratama', 'Hendra Wijaya'],
  'Processing':  ['Siti Rahayu', 'Dian Permata', 'Eko Susilo', 'Novi Andriani'],
  'Maintenance': ['Wahyu Hidayat', 'Agus Setiawan', 'Bambang Purnomo'],
  'HSE':         ['Lintang Bhaskara', 'Maya Putri', 'Reza Firmansyah'],
  'HR':          ['Dewi Kusuma', 'Rizki Fauzan', 'Rina Marlina'],
  'Finance':     ['Tono Subagio', 'Fitri Handayani', 'Arief Budiman'],
  'IT':          ['Kevin Alfarisi', 'Deni Setiawan', 'Putri Wulandari'],
  'Operations':  ['Faisal Rahman', 'Guntur Prabowo', 'Yuli Astuti'],
};

// ── Data: Kategori & Subkategori ───────────────────────────────────────────
const _subkategoriTTA = [
  'Tidak Menggunakan APD',
  'Mengoperasikan Peralatan Tanpa Izin',
  'Posisi/Sikap Kerja Tidak Aman',
  'Bekerja di Bawah Pengaruh Alkohol/Obat',
  'Mengabaikan Prosedur Keselamatan',
  'Berkendara Tidak Aman',
  'Menggunakan Peralatan Rusak',
];

const _subkategoriKTA = [
  'Kondisi Lantai/Jalan Berbahaya',
  'Peralatan Rusak/Tidak Layak Pakai',
  'Pencahayaan Tidak Memadai',
  'Penyimpanan Material Tidak Aman',
  'Bahaya Benda Jatuh/Terlempar',
  'Kebisingan Berlebihan',
  'Instalasi Listrik Tidak Aman',
  'Ventilasi Tidak Memadai',
];

class CreateHazardScreen extends StatefulWidget {
  const CreateHazardScreen({super.key});

  @override
  State<CreateHazardScreen> createState() => _CreateHazardScreenState();
}

class _CreateHazardScreenState extends State<CreateHazardScreen> {
  // ── Constants ──────────────────────────────────────────────────────────────
  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);
  static const _bgColor = Color(0xFFF0F0F0);

  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _kronologiCtrl = TextEditingController();
  final _saranCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();

  // Orang
  String? _selectedDepartemen;
  String? _selectedPja;

  // Status (Severity)
  ReportSeverity? _selectedSeverity;

  // Kategori & Subkategori Hazard
  String? _selectedKategori; // 'TTA' or 'KTA'
  String? _selectedSubkategori;

  bool _isSubmitting = false;

  // ── Photo ──────────────────────────────────────────────────────────────────
  XFile? _photoFile;
  final _picker = ImagePicker();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _kronologiCtrl.dispose();
    _saranCtrl.dispose();
    _locationCtrl.dispose();
    super.dispose();
  }

  List<String> get _subkategoriList {
    if (_selectedKategori == 'TTA') return _subkategoriTTA;
    if (_selectedKategori == 'KTA') return _subkategoriKTA;
    return [];
  }

  // ── Pick photo ─────────────────────────────────────────────────────────────
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1280,
      );
      if (picked != null) setState(() => _photoFile = picked);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal mengambil foto: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.all(16),
        ));
      }
    }
  }

  // ── Bottom sheet pilih sumber foto ─────────────────────────────────────────
  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 4),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text('Tambah Foto',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _blueLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.camera_alt_outlined, color: _blue, size: 22),
              ),
              title: const Text('Ambil Foto dari Kamera'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.camera); },
            ),
            ListTile(
              leading: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: _blueLight, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.photo_library_outlined, color: _blue, size: 22),
              ),
              title: const Text('Pilih dari Galeri'),
              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
              onTap: () { Navigator.pop(context); _pickPhoto(ImageSource.gallery); },
            ),
            if (_photoFile != null)
              ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                ),
                title: const Text('Hapus Foto', style: TextStyle(color: Colors.red)),
                onTap: () { Navigator.pop(context); setState(() => _photoFile = null); },
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200),
                    ),
                  ),
                  child: const Text('Batal'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final online = await CloudSaveService.isOnline();

    if (!online) {
      // ── OFFLINE: simpan sebagai draft Cloud Save ───────────────────────
      final draft = ReportDraft(
        id: 'hazard_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
        type: DraftType.hazard,
        title: _titleCtrl.text.trim(),
        data: {
          'title': _titleCtrl.text.trim(),
          'description': _descriptionCtrl.text.trim(),
          'kronologi': _kronologiCtrl.text.trim(),
          'saran': _saranCtrl.text.trim(),
          'location': _locationCtrl.text.trim(),
          'departemen': _selectedDepartemen,
          'pja': _selectedPja,
          'severity': _selectedSeverity?.name,
          'kategori': _selectedKategori,
          'subkategori': _selectedSubkategori,
          'photoPath': _photoFile?.path,
        },
        createdAt: DateTime.now(),
      );
      await CloudSaveService.instance.saveDraft(draft);

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      _showResultDialog(
        isOffline: true,
        title: 'Tersimpan sebagai Draft',
        message:
            'Tidak ada koneksi internet. Laporan hazard disimpan secara lokal dan akan dikirim otomatis saat Anda kembali online.',
      );
    } else {
      try {
        await ReportStore.instance.createHazardReport(
          title: _titleCtrl.text.trim(),
          description: _kronologiCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          severity: _severityToApi(_selectedSeverity),
          namePja: _selectedPja,
          department: _selectedDepartemen,
          hazardCategory: _selectedKategori,
          hazardSubcategory: _selectedSubkategori,
          suggestion: _saranCtrl.text.trim(),
          imagePath: _photoFile?.path,
        );

        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showResultDialog(
          isOffline: false,
          title: 'Laporan Terkirim!',
          message:
              'Laporan hazard Anda telah berhasil dikirim dan akan segera ditindaklanjuti.',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengirim laporan: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  String _severityToApi(ReportSeverity? severity) {
    switch (severity) {
      case ReportSeverity.low:
        return 'low';
      case ReportSeverity.medium:
        return 'medium';
      case ReportSeverity.high:
        return 'high';
      case ReportSeverity.critical:
        return 'critical';
      case null:
        return 'medium';
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isOffline
                    ? const Color(0xFFFFF3E0)
                    : _blueLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOffline
                    ? Icons.cloud_off_outlined
                    : Icons.cloud_done_outlined,
                color: isOffline ? const Color(0xFFFF9800) : _blue,
                size: 42,
              ),
            ),
            const SizedBox(height: 16),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: Colors.grey, fontSize: 13, height: 1.5),
            ),
            if (isOffline) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF9800)
                          .withValues(alpha: 0.4)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_outlined,
                        size: 14, color: Color(0xFFE65100)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Cek ikon Cloud Save di header untuk melihat & mengirim draft.',
                        style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFFE65100),
                            height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                backgroundColor: isOffline
                    ? const Color(0xFFFF9800)
                    : _blue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('OK',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

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
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Photo section (compact) ────────────────────────────────
              _buildPhotoCompact(),

              const SizedBox(height: 16),

              // ── Form card ──────────────────────────────────────────────
              _buildCard(children: [
                _label('Judul Laporan *'),
                _textField(
                  controller: _titleCtrl,
                  hint: 'Masukkan judul laporan',
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                ),

                const SizedBox(height: 14),
                _label('Status *'),
                _buildSeverityDropdown(),

                const SizedBox(height: 14),
                _label('Departemen *'),
                _buildDropdown(
                  value: _selectedDepartemen,
                  hint: 'Pilih departemen',
                  items: _departemenList,
                  icon: Icons.business_outlined,
                  onChanged: (val) => setState(() {
                    _selectedDepartemen = val;
                    _selectedPja = null;
                  }),
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                ),

                const SizedBox(height: 14),
                _label('PJA (Penanggung Jawab Area) *'),
                _buildDropdown(
                  value: _selectedPja,
                  hint: _selectedDepartemen == null
                      ? 'Pilih departemen terlebih dahulu'
                      : 'Pilih PJA',
                  items: _selectedDepartemen != null
                      ? (_pjaByDepartemen[_selectedDepartemen!] ?? [])
                      : [],
                  icon: Icons.person_outlined,
                  onChanged: _selectedDepartemen == null
                      ? null
                      : (val) => setState(() => _selectedPja = val),
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                ),

                const SizedBox(height: 14),
                _label('Kategori Hazard *'),
                _buildKategoriSelector(),

                const SizedBox(height: 14),
                _label('Subkategori Hazard *'),
                _buildDropdown(
                  value: _selectedSubkategori,
                  hint: _selectedKategori == null
                      ? 'Pilih kategori terlebih dahulu'
                      : 'Pilih subkategori',
                  items: _subkategoriList,
                  icon: Icons.category_outlined,
                  onChanged: _selectedKategori == null
                      ? null
                      : (val) => setState(() => _selectedSubkategori = val),
                  validator: (v) => v == null ? 'Wajib dipilih' : null,
                ),

                const SizedBox(height: 14),
                _label('Lokasi *'),
                _textField(
                  controller: _locationCtrl,
                  hint: 'Contoh: Gedung A - Lantai 2',
                  icon: Icons.location_on_outlined,
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                ),

                const SizedBox(height: 14),
                _label('Deskripsi Kronologi *'),
                TextFormField(
                  controller: _kronologiCtrl,
                  maxLines: 4,
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                  decoration: _inputDeco(hint: 'Jelaskan kronologi kejadian secara runtut...'),
                ),

                const SizedBox(height: 14),
                _label('Deskripsi Saran *'),
                TextFormField(
                  controller: _saranCtrl,
                  maxLines: 4,
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                  decoration: _inputDeco(hint: 'Berikan saran atau rekomendasi tindakan perbaikan...'),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Submit ─────────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _blue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22, height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Kirim Laporan',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── Photo compact row ──────────────────────────────────────────────────────
  Widget _buildPhotoCompact() {
    if (_photoFile != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: double.infinity,
              height: 160,
              child: kIsWeb
                  ? Image.network(_photoFile!.path, fit: BoxFit.cover)
                  : Image.file(File(_photoFile!.path), fit: BoxFit.cover),
            ),
          ),
          Positioned(
            top: 8, right: 8,
            child: GestureDetector(
              onTap: _showPhotoOptions,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, color: Colors.white, size: 13),
                    SizedBox(width: 4),
                    Text('Ganti', style: TextStyle(color: Colors.white, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    // Compact placeholder
    return GestureDetector(
      onTap: _showPhotoOptions,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _blue.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: _blueLight, shape: BoxShape.circle),
              child: const Icon(Icons.camera_alt_outlined, color: _blue, size: 16),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Tambah Foto Hazard',
                    style: TextStyle(fontWeight: FontWeight.w600, color: _blue, fontSize: 12)),
                Text('Kamera atau Galeri',
                    style: TextStyle(fontSize: 10, color: Colors.grey)),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.grey, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Severity dropdown ──────────────────────────────────────────────────────
  Widget _buildSeverityDropdown() {
    const options = [ReportSeverity.low, ReportSeverity.high, ReportSeverity.critical];
    const colors = {
      ReportSeverity.low:      Color(0xFF4CAF50),
      ReportSeverity.high:     Color(0xFFF44336),
      ReportSeverity.critical: Color(0xFF880E4F),
    };

    return FormField<ReportSeverity>(
      validator: (v) => v == null ? 'Wajib dipilih' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: options.map((s) {
              final isSelected = _selectedSeverity == s;
              final color = colors[s]!;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _selectedSeverity = s);
                    state.didChange(s);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color, width: isSelected ? 2 : 1),
                    ),
                    child: Text(
                      s.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: isSelected ? Colors.white : color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ── Kategori selector (TTA / KTA) ──────────────────────────────────────────
  Widget _buildKategoriSelector() {
    const options = ['TTA', 'KTA'];
    const labels = {'TTA': 'TTA (Tindakan Tidak Aman)', 'KTA': 'KTA (Kondisi Tidak Aman)'};
    const icons = {'TTA': Icons.warning_amber_outlined, 'KTA': Icons.construction_outlined};

    return FormField<String>(
      validator: (v) => v == null ? 'Wajib dipilih' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: options.map((k) {
              final isSelected = _selectedKategori == k;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedKategori = k;
                      _selectedSubkategori = null;
                    });
                    state.didChange(k);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? _blue : _blueLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: isSelected ? _blue : Colors.blue.shade100,
                          width: isSelected ? 2 : 1),
                    ),
                    child: Column(
                      children: [
                        Icon(icons[k], color: isSelected ? Colors.white : _blue, size: 20),
                        const SizedBox(height: 4),
                        Text(
                          labels[k]!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isSelected ? Colors.white : _blue,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  // ── Generic dropdown ───────────────────────────────────────────────────────
  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required void Function(String?)? onChanged,
    required String? Function(String?) validator,
    IconData? icon,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      validator: validator,
      onChanged: onChanged,
      decoration: _inputDeco(hint: hint, icon: icon),
      isExpanded: true,
      hint: Text(hint, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13))))
          .toList(),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _buildCard({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
      );

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required String? Function(String?) validator,
    IconData? icon,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: _inputDeco(hint: hint, icon: icon),
    );
  }

  InputDecoration _inputDeco({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon: icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
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
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }
}
