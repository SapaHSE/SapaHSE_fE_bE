import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../config/supabase_config.dart';
import '../services/auth_service.dart';
import '../services/supabase_storage_service.dart';
import '../services/violation_service.dart';
import 'app_safe_insets.dart';

String _userInitial(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '?' : text[0].toUpperCase();
}

class ViolationFormSheet extends StatefulWidget {
  final ViolationItem? item;
  final String initialType;
  final Map<String, dynamic>? preSelectedUser;
  final VoidCallback onSuccess;

  const ViolationFormSheet({
    super.key,
    this.item,
    this.initialType = 'Violation',
    this.preSelectedUser,
    required this.onSuccess,
  });

  @override
  State<ViolationFormSheet> createState() => _ViolationFormSheetState();
}

class _ViolationFormSheetState extends State<ViolationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _expiredDateController = TextEditingController();
  final _sanctionController = TextEditingController();
  XFile? _violationImage;
  Timer? _debounce;
  String _status = 'Aktif';
  String _type = 'Violation';
  int _level = 1;
  ViolationCategoryData? _selectedCategory;
  ViolationSubcategoryData? _selectedSubcategory;
  List<ViolationCategoryData> _categories = [];

  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userResults = [];
  bool _isSearchingUser = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _type = widget.item?.type ?? widget.initialType;
    _selectedUser = widget.preSelectedUser;
    if (widget.item != null) {
      _titleController.text = widget.item!.title;
      _descriptionController.text = widget.item!.description ?? '';
      _locationController.text = widget.item!.location ?? '';
      _expiredDateController.text = widget.item!.expiredAt ?? '';
      _sanctionController.text = widget.item!.sanction ?? '';
      _status = widget.item!.status;
      _level = widget.item!.level.clamp(1, 3).toInt();
      _selectedUser = widget.item!.user;
      _violationImage = null;
    }
    _loadCategories();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _expiredDateController.dispose();
    _sanctionController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final categories = await ViolationService.getViolationCategories();
    if (!mounted) return;
    setState(() {
      _categories = categories;
      if (widget.item?.violationCategory != null) {
        _selectedCategory = _categories.cast<ViolationCategoryData?>().firstWhere(
              (c) => c?.code == widget.item!.violationCategory,
              orElse: () => null,
            );
      }
      if (_selectedCategory != null && widget.item?.violationSubcategory != null) {
        _selectedSubcategory = _selectedCategory!.subcategories
            .cast<ViolationSubcategoryData?>()
            .firstWhere(
              (s) => s?.name == widget.item!.violationSubcategory,
              orElse: () => null,
            );
      }
    });
  }

  Future<void> _searchUsers(String query) async {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (query.length < 3) {
        setState(() => _userResults = []);
        return;
      }
      setState(() => _isSearchingUser = true);
      final response = await AuthService.listUsers(search: query);
      if (!mounted) return;
      setState(() {
        _isSearchingUser = false;
        if (response.success) {
          _userResults = List<Map<String, dynamic>>.from(response.data['data']);
        }
      });
    });
  }

  Future<void> _selectExpiredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 180)),
      firstDate: now,
      lastDate: DateTime(now.year + 2, 12, 31),
    );
    if (picked != null) {
      setState(() {
        _expiredDateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _selectedUser == null) {
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih user terlebih dahulu')),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    String? uploadedUrl;
    if (_violationImage != null) {
      uploadedUrl = await SupabaseStorageService.uploadImage(
        imagePath: _violationImage!.path,
        folder: SupabaseConfig.violationsFolder,
      );
      if (uploadedUrl == null) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunggah foto ke Supabase')),
        );
        return;
      }
    } else {
      uploadedUrl = widget.item?.fileUrl;
    }

    final data = {
      'title': _titleController.text.trim(),
      'violation_category': _selectedCategory?.code,
      'violation_subcategory': _selectedSubcategory?.name,
      'type': _type,
      'level': _level,
      'description': _descriptionController.text.trim(),
      'location': _locationController.text.trim(),
      'expired_at':
          _expiredDateController.text.isEmpty ? null : _expiredDateController.text,
      'status': _status,
      'sanction': _sanctionController.text.trim(),
      'file_url': uploadedUrl,
    };

    final result = widget.item == null
        ? await ViolationService.storeViolation(
            _selectedUser!['id'].toString(),
            data,
          )
        : await ViolationService.updateViolation(widget.item!.id, data);

    if (!mounted) return;
    setState(() => _isSaving = false);

    if (result.success) {
      widget.onSuccess();
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Data berhasil disimpan')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Gagal menyimpan data')),
      );
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Data'),
        content: const Text('Apakah Anda yakin ingin menghapus data ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isSaving = true);
      final result = await ViolationService.deleteViolation(widget.item!.id);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (result.success) {
        widget.onSuccess();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data berhasil dihapus')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: AppSafeInsets.keyboardOrSystemBottom(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildUserPicker(),
                    const SizedBox(height: 20),
                    _buildTypePicker(),
                    const SizedBox(height: 16),
                    _buildLevelPicker(),
                    const SizedBox(height: 16),
                    _buildCategoryPicker(),
                    const SizedBox(height: 16),
                    _buildSubcategoryPicker(),
                    const SizedBox(height: 16),
                    _buildField(
                      _type == 'Incident' ? 'Judul Incident' : 'Judul Pelanggaran',
                      _titleController,
                      hint: 'Contoh: Tidak memakai helm',
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      'Deskripsi',
                      _descriptionController,
                      hint: 'Tuliskan deskripsi kronologi...',
                      maxLines: 3,
                      isRequired: false,
                    ),
                    const SizedBox(height: 16),
                    _buildField(
                      'Lokasi',
                      _locationController,
                      hint: 'Contoh: Pit A / Area Workshop',
                      isRequired: false,
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: _selectExpiredDate,
                      child: IgnorePointer(
                        child: _buildField(
                          'Masa Berlaku',
                          _expiredDateController,
                          hint: 'YYYY-MM-DD',
                          icon: Icons.event_available,
                          isRequired: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatusPicker(),
                    const SizedBox(height: 16),
                    _buildField(
                      'Sanksi / Tindakan',
                      _sanctionController,
                      hint: 'Contoh: SP1 / Teguran Lisan',
                      isRequired: false,
                    ),
                    const SizedBox(height: 16),
                    _buildImagePicker(),
                    const SizedBox(height: 32),
                    _buildFooterButtons(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
      ),
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.item == null ? 'Tambah $_type' : 'Edit $_type',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildUserPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'User / Karyawan',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (_selectedUser != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF1A56C4).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(child: Text(_userInitial(_selectedUser!['full_name']))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedUser!['full_name'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        _selectedUser!['employee_id'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                if (widget.item == null && widget.preSelectedUser == null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => setState(() => _selectedUser = null),
                  ),
              ],
            ),
          )
        else
          Column(
            children: [
              TextField(
                decoration: InputDecoration(
                  hintText: 'Cari nama atau ID karyawan...',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color(0xFFF8F9FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: _searchUsers,
              ),
              if (_isSearchingUser)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(),
                ),
              if (_userResults.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _userResults.length,
                    itemBuilder: (ctx, idx) {
                      final u = _userResults[idx];
                      return ListTile(
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text(_userInitial(u['full_name'])),
                        ),
                        title: Text(
                          u['full_name'] ?? '',
                          style: const TextStyle(fontSize: 14),
                        ),
                        subtitle: Text(
                          u['employee_id'] ?? '',
                          style: const TextStyle(fontSize: 12),
                        ),
                        onTap: () => setState(() {
                          _selectedUser = u;
                          _userResults = [];
                        }),
                      );
                    },
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildTypePicker() {
    return _buildDropdown<String>(
      label: 'Tipe',
      value: _type,
      items: const ['Violation', 'Incident'],
      itemLabel: (item) => item,
      onChanged: widget.item == null ? (value) => setState(() => _type = value) : null,
    );
  }

  Widget _buildLevelPicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Level',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [1, 2, 3].map((level) {
            final selected = _level == level;
            final color = switch (level) {
              1 => Colors.green,
              2 => Colors.orange,
              _ => Colors.red,
            };
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: level == 3 ? 0 : 8),
                child: ChoiceChip(
                  label: Text('Level $level'),
                  selected: selected,
                  selectedColor: color,
                  backgroundColor: color.withValues(alpha: 0.08),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (_) => setState(() => _level = level),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildCategoryPicker() {
    return _buildDropdown<ViolationCategoryData>(
      label: 'Tipe Pelanggaran',
      value: _selectedCategory,
      items: _categories,
      itemLabel: (item) => item.code == null ? item.name : '${item.code} - ${item.name}',
      onChanged: (value) => setState(() {
        _selectedCategory = value;
        _selectedSubcategory = null;
      }),
    );
  }

  Widget _buildSubcategoryPicker() {
    final items = _selectedCategory?.subcategories
            .where((item) => item.isActive)
            .toList() ??
        [];
    return _buildDropdown<ViolationSubcategoryData>(
      label: 'Sub Tipe',
      value: _selectedSubcategory,
      items: items,
      itemLabel: (item) => item.name,
      onChanged: _selectedCategory == null
          ? null
          : (value) => setState(() => _selectedSubcategory = value),
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) itemLabel,
    required ValueChanged<T>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8F9FA),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              value: value,
              isExpanded: true,
              hint: Text('Pilih $label', style: const TextStyle(fontSize: 14)),
              items: items
                  .map((item) => DropdownMenuItem<T>(
                        value: item,
                        child: Text(
                          itemLabel(item),
                          style: const TextStyle(fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ))
                  .toList(),
              onChanged: onChanged == null ? null : (value) => onChanged(value as T),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildImagePicker() {
    final hasRemoteUrl = widget.item?.fileUrl != null && widget.item!.fileUrl!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Foto / Lampiran',
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picker = ImagePicker();
            final picked = await picker.pickImage(
              source: ImageSource.gallery,
              imageQuality: 70,
            );
            if (picked != null) {
              setState(() => _violationImage = picked);
            }
          },
          child: Container(
            height: 140,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _violationImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(File(_violationImage!.path), fit: BoxFit.cover),
                  )
                : (hasRemoteUrl
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(widget.item!.fileUrl!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo_outlined,
                              color: Colors.grey.shade400, size: 32),
                          const SizedBox(height: 8),
                          Text(
                            'Ambil atau Pilih Foto',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                        ],
                      )),
          ),
        ),
      ],
    );
  }

  Widget _buildField(
    String label,
    TextEditingController controller, {
    required String hint,
    IconData? icon,
    bool isRequired = true,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          validator:
              isRequired ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: icon != null ? Icon(icon, size: 20) : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FA),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusPicker() {
    return _buildDropdown<String>(
      label: 'Status',
      value: _status,
      items: const ['Aktif', 'Selesai'],
      itemLabel: (item) => item,
      onChanged: (value) => setState(() => _status = value),
    );
  }

  Widget _buildFooterButtons() {
    return Row(
      children: [
        if (widget.item != null) ...[
          IconButton(
            onPressed: _isSaving ? null : _delete,
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            style: IconButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              padding: const EdgeInsets.all(14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56C4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'SIMPAN DATA',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
