import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../data/news_data.dart';
import '../services/news_service.dart';
import '../services/storage_service.dart';

class NewsCreateScreen extends StatefulWidget {
  const NewsCreateScreen({super.key});

  @override
  State<NewsCreateScreen> createState() => _NewsCreateScreenState();
}

class _NewsCreateScreenState extends State<NewsCreateScreen> {
  static const _primary = Color(0xFF1A56C4);

  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _authorCtrl = TextEditingController();
  final _excerptCtrl = TextEditingController();
  final _quillCtrl = quill.QuillController.basic();

  String? _category;
  DateTime _publishDate = DateTime.now();
  bool _isFeatured = false;
  XFile? _image;
  bool _submitting = false;
  bool _localeReady = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await initializeDateFormatting('id_ID', null);
    final user = await StorageService.getUser();
    if (!mounted) return;
    setState(() {
      _authorCtrl.text =
          (user?['full_name'] ?? user?['name'] ?? '').toString();
      _localeReady = true;
    });
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _authorCtrl.dispose();
    _excerptCtrl.dispose();
    _quillCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _image = picked);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _publishDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) {
      setState(() => _publishDate = picked);
    }
  }

  String _quillToHtml() {
    final ops = _quillCtrl.document.toDelta().toJson();
    final converter =
        QuillDeltaToHtmlConverter(List<Map<String, dynamic>>.from(ops));
    return converter.convert();
  }

  bool _quillEmpty() {
    final plain = _quillCtrl.document.toPlainText().trim();
    return plain.isEmpty;
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      _snack('Pilih kategori terlebih dahulu.');
      return;
    }
    if (_quillEmpty()) {
      _snack('Isi berita tidak boleh kosong.');
      return;
    }

    setState(() => _submitting = true);

    final fields = <String, String>{
      'title': _titleCtrl.text.trim(),
      'category': _category!,
      'excerpt': _excerptCtrl.text.trim(),
      'content': _quillToHtml(),
      'author_name': _authorCtrl.text.trim(),
      'publish_date': DateFormat('yyyy-MM-dd').format(_publishDate),
      'is_featured': _isFeatured ? '1' : '0',
    };

    List<int>? imageBytes;
    String? imageFilename;
    if (_image != null) {
      imageBytes = await _image!.readAsBytes();
      imageFilename = _image!.name;
    }

    final result = await NewsService.createNews(
      fields: fields,
      imageBytes: imageBytes,
      imageFilename: imageFilename,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (result.success) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Berita berhasil dipublikasikan.')),
      );
    } else {
      _snack(result.errorMessage ?? 'Gagal menyimpan berita.');
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red.shade600),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_localeReady) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final dateLabel =
        DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(_publishDate);
    final categories =
        newsCategories.where((c) => c != 'All News').toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        scrolledUnderElevation: 1,
        title: const Text(
          'Buat Berita',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        iconTheme: const IconThemeData(color: Colors.black87),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: _primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _primary.withValues(alpha: 0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text('Publikasikan',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _imagePickerCard(),
                const SizedBox(height: 16),
                _sectionLabel('Judul Berita'),
                _textField(
                  controller: _titleCtrl,
                  hint: 'Mis. Pelatihan K3 Q2 2026 selesai digelar',
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Judul wajib diisi' : null,
                ),
                const SizedBox(height: 14),
                _sectionLabel('Nama Penulis'),
                _textField(
                  controller: _authorCtrl,
                  hint: 'Nama penulis',
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nama penulis wajib diisi'
                      : null,
                ),
                const SizedBox(height: 14),
                _sectionLabel('Kategori'),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: _inputDecoration('Pilih kategori'),
                  items: categories
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) =>
                      v == null ? 'Kategori wajib dipilih' : null,
                ),
                const SizedBox(height: 14),
                _sectionLabel('Tanggal Publikasi'),
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: InputDecorator(
                    decoration: _inputDecoration('Pilih tanggal').copyWith(
                      prefixIcon: const Icon(Icons.calendar_today_outlined,
                          size: 18, color: _primary),
                    ),
                    child: Text(
                      dateLabel,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _sectionLabel('Ringkasan'),
                _textField(
                  controller: _excerptCtrl,
                  hint: 'Ringkasan singkat berita (1-2 kalimat)',
                  maxLines: 3,
                ),
                const SizedBox(height: 18),
                _sectionLabel('Isi Berita'),
                _quillCard(),
                const SizedBox(height: 18),
                _featuredSwitch(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Widgets ───────────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6, left: 2),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF455A64),
          ),
        ),
      );

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9AA5B1), fontSize: 14),
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFE0E4EA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: _inputDecoration(hint),
    );
  }

  Widget _imagePickerCard() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE0E4EA)),
          image: _image != null
              ? DecorationImage(
                  image: FileImage(File(_image!.path)),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: _image != null
            ? Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() => _image = null),
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(Icons.close,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ),
                ),
              )
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 42, color: _primary),
                  SizedBox(height: 6),
                  Text(
                    'Tap untuk pilih gambar utama',
                    style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF455A64),
                        fontWeight: FontWeight.w500),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'JPG / PNG, maks 2 MB',
                    style: TextStyle(fontSize: 11, color: Color(0xFF90A4AE)),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _quillCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E4EA)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          quill.QuillSimpleToolbar(
            controller: _quillCtrl,
            config: const quill.QuillSimpleToolbarConfig(
              multiRowsDisplay: false,
              showFontFamily: false,
              showFontSize: false,
              showColorButton: false,
              showBackgroundColorButton: false,
              showAlignmentButtons: false,
              showIndent: false,
              showDirection: false,
              showSubscript: false,
              showSuperscript: false,
              showCodeBlock: false,
              showInlineCode: false,
              showQuote: true,
              showSearchButton: false,
              showDividers: true,
              showHeaderStyle: true,
              showListNumbers: true,
              showListBullets: true,
              showListCheck: false,
              showStrikeThrough: false,
              showLink: true,
              showUndo: true,
              showRedo: true,
            ),
          ),
          const Divider(height: 1, color: Color(0xFFE0E4EA)),
          Container(
            constraints: const BoxConstraints(minHeight: 260),
            padding: const EdgeInsets.all(12),
            child: quill.QuillEditor.basic(
              controller: _quillCtrl,
              config: const quill.QuillEditorConfig(
                placeholder: 'Tulis isi berita di sini...',
                padding: EdgeInsets.zero,
                expands: false,
                autoFocus: false,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _featuredSwitch() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E4EA)),
      ),
      child: SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: _isFeatured,
        onChanged: (v) => setState(() => _isFeatured = v),
        activeThumbColor: _primary,
        title: const Text(
          'Berita Utama',
          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: const Text(
          'Tampilkan di carousel halaman berita',
          style: TextStyle(fontSize: 12, color: Color(0xFF7A8895)),
        ),
      ),
    );
  }
}
