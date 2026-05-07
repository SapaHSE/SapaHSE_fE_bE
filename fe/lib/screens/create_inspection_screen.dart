import 'dart:io' show File;
import 'dart:math' show Random;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../data/report_store.dart';
import '../services/cloud_save_service.dart';
import '../services/report_service.dart';
import '../widgets/minimal_dropdown.dart';

class CreateInspectionScreen extends StatefulWidget {
  const CreateInspectionScreen({super.key});

  @override
  State<CreateInspectionScreen> createState() => _CreateInspectionScreenState();
}

class _CreateInspectionScreenState extends State<CreateInspectionScreen> {
  // ── Constants (sama dengan create_hazard_screen) ───────────────────────────
  static const _blue = Color(0xFF1A56C4);
  static const _blueLight = Color(0xFFEFF4FF);
  static const _bgColor = Color(0xFFF0F0F0);

  // ── Form ───────────────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  final _inspectorController = TextEditingController();

  String _selectedArea = 'Area Tambang';
  String _selectedResult = 'Sesuai';
  bool _isSubmitting = false;

  // ── Foto inspeksi (multi-image) ────────────────────────────────────────────
  final List<XFile> _photoFiles = [];
  final _picker = ImagePicker();

  // ── Department tagging ─────────────────────────────────────────────────────
  // Departemen yang di-tag akan disimpan ke `reported_department` (comma-joined).
  // User dengan `users.department` cocok akan menerima laporan ini di tab Tugas
  // dan punya akses update yang sama dengan inspector yang di-tag namanya.
  List<String> _apiDepartments = [];
  bool _isLoadingDepts = true;
  final Set<String> _selectedDepts = {};

  final List<String> _areas = [
    'Area Tambang',
    'Workshop',
    'Gudang',
    'Kantor',
    'Area Parkir',
    'Lantai Produksi',
  ];

  final List<Map<String, dynamic>> _checklistItems = [
    {'label': 'APD tersedia dan layak pakai', 'checked': false},
    {'label': 'APAR dalam kondisi baik', 'checked': false},
    {'label': 'Jalur evakuasi bebas hambatan', 'checked': false},
    {'label': 'Rambu K3 terpasang dan terbaca', 'checked': false},
    {'label': 'Alat berat dalam kondisi prima', 'checked': false},
    {'label': 'Instalasi listrik aman', 'checked': false},
  ];

  @override
  void initState() {
    super.initState();
    _loadDepartments();
  }

  Future<void> _loadDepartments() async {
    try {
      final list = await ReportService.getDepartments();
      if (!mounted) return;
      setState(() {
        _apiDepartments = list;
        _isLoadingDepts = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingDepts = false);
    }
  }

  String? get _reportedDepartment =>
      _selectedDepts.isEmpty ? null : _selectedDepts.join(', ');

  Future<void> _openDeptPicker() async {
    if (_isLoadingDepts) return;
    final tempSelected = Set<String>.from(_selectedDepts);
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Tag Departemen',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih departemen yang bertanggung jawab. User dengan dept tsb akan menerima laporan di tab Tugas.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),
                    Flexible(
                      child: _apiDepartments.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Center(
                                child: Text('Tidak ada data departemen.',
                                    style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _apiDepartments.length,
                              itemBuilder: (_, i) {
                                final dept = _apiDepartments[i];
                                final selected = tempSelected.contains(dept);
                                return CheckboxListTile(
                                  dense: true,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  activeColor: _blue,
                                  value: selected,
                                  title: Text(dept,
                                      style: const TextStyle(fontSize: 13)),
                                  onChanged: (v) => setSheet(() {
                                    if (v == true) {
                                      tempSelected.add(dept);
                                    } else {
                                      tempSelected.remove(dept);
                                    }
                                  }),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(ctx, tempSelected),
                            child: const Text('Simpan'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (result != null) {
      setState(() {
        _selectedDepts
          ..clear()
          ..addAll(result);
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _inspectorController.dispose();
    super.dispose();
  }

  // ── Photo picker (mengikuti pola create_hazard_screen) ────────────────────
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

  void _showPhotoSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tambah Foto Inspeksi',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _pickPhoto(ImageSource.camera);
                        },
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Kamera'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _pickPhoto(ImageSource.gallery);
                        },
                        icon: const Icon(Icons.photo),
                        label: const Text('Galeri'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    final online = await CloudSaveService.isOnline();

    if (!online) {
      // ── OFFLINE: simpan draft ──────────────────────────────────────────
      final draft = ReportDraft(
        id: 'inspection_${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(9999)}',
        type: DraftType.inspection,
        title: _titleController.text.trim(),
        data: {
          'title': _titleController.text.trim(),
          'location': _locationController.text.trim(),
          'inspector': _inspectorController.text.trim(),
          'reported_department': _reportedDepartment,
          'notes': _notesController.text.trim(),
          'area': _selectedArea,
          'result': _selectedResult,
          'checklist': _checklistItems
              .map((e) => {'label': e['label'], 'checked': e['checked']})
              .toList(),
          'photoPaths': _photoFiles.map((f) => f.path).toList(),
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
            'Tidak ada koneksi internet. Laporan inspeksi disimpan secara lokal dan akan dikirim saat Anda kembali online.',
      );
    } else {
      try {
        final notes = _notesController.text.trim();
        final description = notes.isNotEmpty
            ? notes
            : 'Hasil inspeksi $_selectedResult pada area $_selectedArea.';

        await ReportStore.instance.createInspectionReport(
          title: _titleController.text.trim(),
          description: description,
          location: _locationController.text.trim(),
          area: _selectedArea,
          inspector: _inspectorController.text.trim(),
          reportedDepartment: _reportedDepartment,
          result: _resultToApi(_selectedResult),
          notes: notes,
          checklistItems: _checklistItems
              .map((e) => {
                    'label': e['label'],
                    'checked': e['checked'],
                  })
              .toList(),
          imagePaths: _photoFiles.map((f) => f.path).toList(),
        );

        if (!mounted) return;
        setState(() => _isSubmitting = false);
        _showResultDialog(
          isOffline: false,
          title: 'Inspeksi Terkirim!',
          message:
              'Laporan inspeksi Anda telah berhasil dikirim dan akan segera diproses.',
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

  String _resultToApi(String uiResult) {
    switch (uiResult) {
      case 'Sesuai':
        return 'compliant';
      case 'Tidak Sesuai':
        return 'non_compliant';
      case 'Perlu Tindak Lanjut':
        return 'needs_follow_up';
      default:
        return 'compliant';
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
                color: isOffline ? const Color(0xFFFFF3E0) : _blueLight,
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
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFFFF9800).withValues(alpha: 0.4)),
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
                Future.delayed(const Duration(milliseconds: 100), () {
                  if (context.mounted) Navigator.pop(context);
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isOffline ? const Color(0xFFFF9800) : _blue,
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
        title: const Text('Buat Laporan Inspeksi',
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
              // ── Photo picker (multi-image) ────────────────────────────
              InkWell(
                onTap: _showPhotoSourceSheet,
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: _blue.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                            color: _blueLight, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_outlined,
                            color: _blue, size: 16),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tambah Foto Inspeksi',
                              style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _blue,
                                  fontSize: 12)),
                          Text(
                            _photoFiles.isEmpty
                                ? 'Kamera atau Galeri'
                                : '${_photoFiles.length} foto dipilih',
                            style: const TextStyle(
                                fontSize: 10, color: Colors.grey),
                          ),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
              if (_photoFiles.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _photoFiles.length,
                    itemBuilder: (context, index) {
                      final photo = _photoFiles[index];
                      return Container(
                        margin: const EdgeInsets.only(right: 8),
                        width: 100,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: kIsWeb
                                  ? Image.network(photo.path, fit: BoxFit.cover)
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
                                      color: Colors.white, size: 14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ── Form card ─────────────────────────────────────────────
              _buildCard(children: [
                _label('Judul Inspeksi *'),
                _textField(
                  controller: _titleController,
                  hint: 'Masukkan judul inspeksi',
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                _label('Area *'),
                _dropdownField(
                  value: _selectedArea,
                  items: _areas,
                  onChanged: (v) {
                    if (v != null) setState(() => _selectedArea = v);
                  },
                ),
                const SizedBox(height: 14),
                _label('Lokasi Spesifik *'),
                _textField(
                  controller: _locationController,
                  hint: 'Contoh: Sektor B - Titik 3',
                  icon: Icons.location_on_outlined,
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                _label('Nama Inspektor *'),
                _textField(
                  controller: _inspectorController,
                  hint: 'Masukkan nama inspektor',
                  icon: Icons.person_outline,
                  validator: (v) => v!.trim().isEmpty ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                _label('Tag Departemen'),
                _buildDeptPickerField(),
                const SizedBox(height: 14),
                _label('Hasil Inspeksi *'),
                _buildResultSelector(),
              ]),

              const SizedBox(height: 12),

              // ── Checklist card ────────────────────────────────────────
              _buildCard(children: [
                const Text('Checklist Inspeksi',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                const Text('Centang item yang sudah diperiksa',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 12),
                ...List.generate(_checklistItems.length, (i) {
                  final item = _checklistItems[i];
                  final checked = item['checked'] as bool;
                  return InkWell(
                    onTap: () => setState(
                        () => _checklistItems[i]['checked'] = !checked),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: checked ? _blue : Colors.transparent,
                              borderRadius: BorderRadius.circular(5),
                              border: Border.all(
                                color: checked ? _blue : Colors.grey.shade400,
                                width: 2,
                              ),
                            ),
                            child: checked
                                ? const Icon(Icons.check,
                                    color: Colors.white, size: 14)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              item['label'] as String,
                              style: TextStyle(
                                fontSize: 13,
                                color:
                                    checked ? Colors.black87 : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ]),

              const SizedBox(height: 12),

              // ── Notes card ────────────────────────────────────────────
              _buildCard(children: [
                _label('Catatan Tambahan'),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  decoration: _inputDeco(
                      hint: 'Tambahkan catatan atau temuan lainnya...'),
                ),
              ]),

              const SizedBox(height: 24),

              // ── Submit button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _blue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: _blue.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text('Kirim Laporan Inspeksi',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  // ── Department picker field ────────────────────────────────────────────────
  Widget _buildDeptPickerField() {
    final hasSelection = _selectedDepts.isNotEmpty;
    return InkWell(
      onTap: _isLoadingDepts ? null : _openDeptPicker,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F9FF),
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.apartment_outlined,
                size: 20, color: Colors.grey),
            const SizedBox(width: 10),
            Expanded(
              child: _isLoadingDepts
                  ? const Text('Memuat departemen…',
                      style: TextStyle(color: Colors.grey, fontSize: 13))
                  : hasSelection
                      ? Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: _selectedDepts
                              .map((d) => Chip(
                                    label: Text(d,
                                        style: const TextStyle(fontSize: 11)),
                                    backgroundColor:
                                        _blue.withValues(alpha: 0.1),
                                    labelStyle: const TextStyle(color: _blue),
                                    visualDensity: VisualDensity.compact,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onDeleted: () => setState(() {
                                      _selectedDepts.remove(d);
                                    }),
                                  ))
                              .toList(),
                        )
                      : const Text(
                          'Pilih departemen yang ditugaskan (opsional)',
                          style:
                              TextStyle(color: Colors.grey, fontSize: 13)),
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ── Hasil inspeksi selector ────────────────────────────────────────────────
  Widget _buildResultSelector() {
    const resultColors = {
      'Sesuai': Color(0xFF4CAF50),
      'Tidak Sesuai': Color(0xFFF44336),
      'Perlu Tindak Lanjut': Color(0xFFFF9800),
    };
    return Row(
      children: resultColors.keys.map((r) {
        final isSelected = _selectedResult == r;
        final color = resultColors[r]!;
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedResult = r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 11),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: color, width: isSelected ? 2 : 1),
              ),
              child: Text(
                r,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: children),
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
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Colors.red, width: 1.5)),
    );
  }

  Widget _dropdownField({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return MinimalDropdown<String>(
      value: value,
      onChanged: onChanged,
      items: items
          .map((e) => DropdownMenuItem(
              value: e,
              child: Text(e, style: kMinimalDropdownTextStyle)))
          .toList(),
    );
  }
}
