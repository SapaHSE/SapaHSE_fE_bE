import 'package:flutter/material.dart';

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
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    _inspectorController.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isSubmitting = false);
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
              decoration: const BoxDecoration(
                  color: _blueLight, shape: BoxShape.circle),
              child:
                  const Icon(Icons.check_circle, color: _blue, size: 42),
            ),
            const SizedBox(height: 16),
            const Text('Inspeksi Terkirim!',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 8),
            const Text(
              'Laporan inspeksi Anda telah berhasil dikirim dan akan segera diproses.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 13, height: 1.5),
            ),
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
                backgroundColor: _blue,
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
              // ── Photo placeholder ─────────────────────────────────────
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: _blue.withOpacity(0.3), width: 1.5),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                          color: _blueLight, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_outlined,
                          color: _blue, size: 28),
                    ),
                    const SizedBox(height: 10),
                    const Text('Tambah Foto Inspeksi',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: _blue,
                            fontSize: 14)),
                    const SizedBox(height: 2),
                    const Text('Kamera atau Galeri',
                        style:
                            TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),

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
                _label('Hasil Inspeksi *'),
                _buildResultSelector(),
              ]),

              const SizedBox(height: 12),

              // ── Checklist card ────────────────────────────────────────
              _buildCard(children: [
                const Text('Checklist Inspeksi',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
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
                                color: checked
                                    ? _blue
                                    : Colors.grey.shade400,
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
                                color: checked
                                    ? Colors.black87
                                    : Colors.black54,
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
                    disabledBackgroundColor: _blue.withOpacity(0.5),
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
                color: isSelected ? color : color.withOpacity(0.08),
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
              color: Colors.black.withOpacity(0.05),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FF),
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}
