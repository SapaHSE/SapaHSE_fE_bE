import 'dart:io' show File;
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../data/report_store.dart';
import '../models/report.dart';
import '../services/cloud_save_service.dart';
import 'map_picker_screen.dart';

const _perusahaanList = [
  'PT. Bukit Baiduri Energi',
  'PT. Khotai Makmur Insan Abadi',
];

const _departemenList = [
  'HSE',
  'Produksi',
  'Maintenance',
  'Engineering',
  'HRD',
  'Logistik',
  'Security',
];

class PjaData {
  final String nama;
  final String perusahaan;
  final String departemen;
  const PjaData(this.nama, this.perusahaan, this.departemen);
}

const _pjaList = [
  PjaData('Budi Santoso', 'PT. Bukit Baiduri Energi', 'HSE'),
  PjaData('Ahmad Fauzi', 'PT. Khotai Makmur Insan Abadi', 'Produksi'),
  PjaData('Riko Pratama', 'PT. Bukit Baiduri Energi', 'Maintenance'),
  PjaData('Hendra Wijaya', 'PT. Khotai Makmur Insan Abadi', 'Engineering'),
  PjaData('Siti Rahayu', 'PT. Bukit Baiduri Energi', 'HRD'),
  PjaData('Dian Permata', 'PT. Khotai Makmur Insan Abadi', 'Logistik'),
  PjaData('Eko Susilo', 'PT. Bukit Baiduri Energi', 'Security'),
  PjaData('Novi Andriani', 'PT. Khotai Makmur Insan Abadi', 'HSE'),
  PjaData('Wahyu Hidayat', 'PT. Bukit Baiduri Energi', 'Produksi'),
  PjaData('Agus Setiawan', 'PT. Khotai Makmur Insan Abadi', 'Maintenance'),
  PjaData('Bambang Purnomo', 'PT. Bukit Baiduri Energi', 'Engineering'),
  PjaData('Lintang Bhaskara', 'PT. Khotai Makmur Insan Abadi', 'HRD'),
  PjaData('Maya Putri', 'PT. Bukit Baiduri Energi', 'Logistik'),
  PjaData('Reza Firmansyah', 'PT. Khotai Makmur Insan Abadi', 'Security'),
  PjaData('Kevin Alfarisi', 'PT. Bukit Baiduri Energi', 'HSE'),
  PjaData('Deni Setiawan', 'PT. Khotai Makmur Insan Abadi', 'Produksi'),
  PjaData('Putri Wulandari', 'PT. Bukit Baiduri Energi', 'Maintenance'),
];

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
  static const _blue = Color(0xFF1A56C4);
  static const _bgColor = Color(0xFFF0F0F0);

  int _currentStep = 0;

  final _formKey1 = GlobalKey<FormState>();
  final _formKey2 = GlobalKey<FormState>();

  String? _selectedKategori;
  String? _selectedSubkategori;
  String? _selectedPerusahaan;
  String? _selectedDepartemen;
  String? _selectedTagOrang;

  final _titleCtrl = TextEditingController();
  ReportSeverity? _selectedSeverity;
  final _kronologiCtrl = TextEditingController();
  final _saranCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _pelaporLocationCtrl = TextEditingController();
  final _kejadianLocationCtrl = TextEditingController();
  final List<XFile> _photoFiles = [];
  final _picker = ImagePicker();

  bool _isPublic = true;
  bool _isSubmitting = false;

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

  List<String> get _subkategoriList {
    if (_selectedKategori == 'TTA (Tindakan Tidak Aman)') {
      return _subkategoriTTA;
    }
    if (_selectedKategori == 'KTA (Kondisi Tidak Aman)') {
      return _subkategoriKTA;
    }
    return [];
  }

  List<String> get _filteredPjaList {
    return _pjaList
        .where((pja) {
          final matchPerusahaan = _selectedPerusahaan == null ||
              pja.perusahaan == _selectedPerusahaan;
          final matchDepartemen = _selectedDepartemen == null ||
              pja.departemen == _selectedDepartemen;
          return matchPerusahaan && matchDepartemen;
        })
        .map((e) => e.nama)
        .toList();
  }

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

  Future<void> _getCurrentLocation(TextEditingController ctrl) async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Layanan lokasi tidak aktif.')));
      }
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Izin lokasi ditolak.')));
        }
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Izin lokasi ditolak permanen.')));
      }
      return;
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        ctrl.text = '${position.latitude}, ${position.longitude}';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal mendapatkan lokasi: $e')));
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final picked = await _picker.pickMultiImage(
          imageQuality: 80,
          maxWidth: 1280,
        );
        if (picked.isNotEmpty) setState(() => _photoFiles.addAll(picked));
      } else {
        final picked = await _picker.pickImage(
          source: source,
          imageQuality: 80,
          maxWidth: 1280,
        );
        if (picked != null) setState(() => _photoFiles.add(picked));
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

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKey1.currentState!.validate()) return;
      if (_selectedPerusahaan == null ||
          _selectedDepartemen == null ||
          _selectedTagOrang == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Perusahaan, Departemen, dan Tag Orang wajib diisi'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() => _currentStep++);
    } else if (_currentStep == 1) {
      if (!_formKey2.currentState!.validate()) return;
      if (_selectedSeverity == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Status risiko wajib dipilih'),
          backgroundColor: Colors.red,
        ));
        return;
      }
      setState(() => _currentStep++);
    } else {
      _submitReport();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    }
  }

  Future<void> _submitReport() async {
    setState(() => _isSubmitting = true);

    final online = await CloudSaveService.isOnline();
    final data = {
      'title': _titleCtrl.text.trim(),
      'kronologi': _kronologiCtrl.text.trim(),
      'saran': _saranCtrl.text.trim(),
      'location': _locationCtrl.text.trim(),
      'pelaporLocation': _pelaporLocationCtrl.text.trim(),
      'kejadianLocation': _kejadianLocationCtrl.text.trim(),
      'perusahaan': _selectedPerusahaan,
      'tagOrang': _selectedTagOrang,
      'severity': _selectedSeverity?.name,
      'kategori': _selectedKategori,
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
        final severity = _selectedSeverity?.name ?? 'low';
        final category = _selectedKategori != null
            ? _selectedKategori!.split(' ').first
            : null;
        await ReportStore.instance.createHazardReport(
          title: _titleCtrl.text.trim(),
          description: _kronologiCtrl.text.trim(),
          location: _locationCtrl.text.trim(),
          severity: severity,
          namePja: _selectedTagOrang,
          department: _selectedDepartemen,
          hazardCategory: category,
          hazardSubcategory: _selectedSubkategori,
          suggestion: _saranCtrl.text.trim(),
          imagePath: _photoFiles.isNotEmpty ? _photoFiles.first.path : null,
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(16),
          ),
        );
      }
    }
  }

  void _showResultDialog(
      {required bool isOffline,
      required String title,
      required String message}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) Navigator.pop(context);
                });
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

  InputDecoration _inputDeco({required String hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
      prefixIcon:
          icon != null ? Icon(icon, size: 20, color: Colors.grey) : null,
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
    );
  }

  InputDecorationTheme _dropdownTheme() {
    return InputDecorationTheme(
      hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
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
      constraints: const BoxConstraints(maxHeight: 50),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.black87)),
      );

  Widget _buildStep1() {
    return Form(
      key: _formKey1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label('Kategori Hazard *'),
          DropdownButtonFormField<String>(
            initialValue: _selectedKategori,
            validator: (v) => v == null ? 'Wajib dipilih' : null,
            decoration: _inputDeco(
                hint: 'Pilih Kategori', icon: Icons.category_outlined),
            items: ['TTA (Tindakan Tidak Aman)', 'KTA (Kondisi Tidak Aman)']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (v) => setState(() {
              _selectedKategori = v;
              _selectedSubkategori = null;
            }),
          ),
          const SizedBox(height: 14),
          _label('Subkategori Hazard *'),
          DropdownButtonFormField<String>(
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
            onChanged: (v) => setState(() => _selectedSubkategori = v),
          ),
          const SizedBox(height: 14),
          _label('Perusahaan (Ketik untuk mencari) *'),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              width: constraints.maxWidth,
              enableSearch: true,
              enableFilter: true,
              requestFocusOnTap: true,
              initialSelection: _selectedPerusahaan,
              hintText: 'Pilih / Cari Perusahaan',
              inputDecorationTheme: _dropdownTheme(),
              onSelected: (v) => setState(() {
                _selectedPerusahaan = v;
                _selectedTagOrang = null;
              }),
              dropdownMenuEntries: _perusahaanList
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _label('Departemen *'),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              width: constraints.maxWidth,
              enableSearch: true,
              enableFilter: true,
              requestFocusOnTap: true,
              initialSelection: _selectedDepartemen,
              hintText: 'Pilih / Cari Departemen',
              inputDecorationTheme: _dropdownTheme(),
              onSelected: (v) => setState(() {
                _selectedDepartemen = v;
                _selectedTagOrang = null;
              }),
              dropdownMenuEntries: _departemenList
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
            ),
          ),
          const SizedBox(height: 14),
          _label('PJA (Penanggung Jawab Area) *'),
          LayoutBuilder(
            builder: (context, constraints) => DropdownMenu<String>(
              key: ValueKey('$_selectedPerusahaan-$_selectedDepartemen'),
              width: constraints.maxWidth,
              enableSearch: true,
              enableFilter: true,
              requestFocusOnTap: true,
              initialSelection: _selectedTagOrang,
              hintText: 'Pilih / Cari Orang',
              inputDecorationTheme: _dropdownTheme(),
              onSelected: (v) => setState(() => _selectedTagOrang = v),
              dropdownMenuEntries: _filteredPjaList
                  .map((e) => DropdownMenuEntry(value: e, label: e))
                  .toList(),
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
          _label('Judul Laporan *'),
          TextFormField(
            controller: _titleCtrl,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(hint: 'Judul laporan'),
          ),
          const SizedBox(height: 14),
          _label('Status Resiko *'),
          Row(
            children: [
              ReportSeverity.low,
              ReportSeverity.high,
              ReportSeverity.critical
            ].map((s) {
              final isSelected = _selectedSeverity == s;
              final colors = {
                ReportSeverity.low: Colors.green,
                ReportSeverity.high: Colors.orange,
                ReportSeverity.critical: Colors.red,
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedSeverity = s),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? colors[s]
                          : colors[s]!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: colors[s]!, width: isSelected ? 2 : 1),
                    ),
                    child: Text(s.name.toUpperCase(),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: isSelected ? Colors.white : colors[s],
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ),
              );
            }).toList(),
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
          _label('Deskripsi Saran *'),
          TextFormField(
            controller: _saranCtrl,
            maxLines: 3,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(hint: 'Saran perbaikan...'),
          ),
          const SizedBox(height: 14),
          _label('Lokasi Kejadian (Keterangan) *'),
          TextFormField(
            controller: _locationCtrl,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(
                hint: 'Detail lokasi kejadian',
                icon: Icons.location_on_outlined),
          ),
          const SizedBox(height: 14),
          _label('Pinpoint Lokasi Pelapor *'),
          TextFormField(
            controller: _pelaporLocationCtrl,
            readOnly: true,
            validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
            decoration: _inputDeco(
              hint: 'Koordinat Pelapor',
              icon: Icons.my_location,
            ).copyWith(
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.gps_fixed),
                    onPressed: () => _getCurrentLocation(_pelaporLocationCtrl),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () => _pickLocationFromMap(_pelaporLocationCtrl),
                  ),
                ],
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
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.gps_fixed),
                    onPressed: () => _getCurrentLocation(_kejadianLocationCtrl),
                  ),
                  IconButton(
                    icon: const Icon(Icons.map_outlined),
                    onPressed: () =>
                        _pickLocationFromMap(_kejadianLocationCtrl),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _label('Foto *'),
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
                              ? Image.network(photo.path, fit: BoxFit.cover)
                              : Image.file(File(photo.path), fit: BoxFit.cover),
                        ),
                        Positioned(
                          right: 4,
                          top: 4,
                          child: GestureDetector(
                            onTap: () =>
                                setState(() => _photoFiles.removeAt(index)),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
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
              const Text('Preview Laporan Akhir',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const Divider(),
              _previewItem(
                  'Kategori', '$_selectedKategori - $_selectedSubkategori'),
              _previewItem('Perusahaan', '$_selectedPerusahaan'),
              _previewItem('Departemen', '$_selectedDepartemen'),
              _previewItem('PJA', '$_selectedTagOrang'),
              _previewItem('Judul', _titleCtrl.text),
              _previewItem(
                  'Resiko', _selectedSeverity?.name.toUpperCase() ?? '-'),
              _previewItem('Kronologi', _kronologiCtrl.text),
              _previewItem('Saran', _saranCtrl.text),
              _previewItem('Lokasi', _locationCtrl.text),
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
                                ? Image.network(photo.path, fit: BoxFit.cover)
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
                groupValue: _isPublic,
                activeColor: _blue,
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
              RadioListTile<bool>(
                title: const Text('Private'),
                subtitle: const Text(
                    'Laporan hanya dilihat oleh Anda dan pihak terkait',
                    style: TextStyle(fontSize: 12)),
                value: false,
                groupValue: _isPublic,
                activeColor: _blue,
                onChanged: (v) => setState(() => _isPublic = v!),
              ),
            ],
          ),
        ),
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
              width: 100,
              child: Text(label,
                  style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const Text(': ', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
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
                          padding: const EdgeInsets.symmetric(vertical: 14)),
                      child: const Text('Kembali'),
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : details.onStepContinue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isLastStep ? 'Kirim Laporan' : 'Selanjutnya',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
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
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            title: const Text('Data', style: TextStyle(fontSize: 12)),
            content: _buildStep1(),
          ),
          Step(
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            title: const Text('Detail', style: TextStyle(fontSize: 12)),
            content: _buildStep2(),
          ),
          Step(
            isActive: _currentStep >= 2,
            title: const Text('Preview', style: TextStyle(fontSize: 12)),
            content: _buildStep3(),
          ),
        ],
      ),
    );
  }
}
