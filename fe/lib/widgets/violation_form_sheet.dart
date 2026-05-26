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
import 'minimal_dropdown.dart';

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
  int? _level;
  bool _isPermanentSanction = false;
  ViolationCategoryData? _selectedCategory;
  ViolationSubcategoryData? _selectedSubcategory;
  List<ViolationCategoryData> _categories = [];

  Map<String, dynamic>? _selectedUser;
  List<Map<String, dynamic>> _userResults = [];
  bool _isSearchingUser = false;
  bool _isSaving = false;
  bool _hasTriedSubmit = false;

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
      _isPermanentSanction = widget.item!.isPermanent;
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
    setState(() => _hasTriedSubmit = true);

    if (!_formKey.currentState!.validate() ||
        _selectedUser == null ||
        _level == null) {
      if (_selectedUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih user terlebih dahulu')),
        );
      }
      if (_level == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Silakan pilih level terlebih dahulu')),
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
          _isPermanentSanction || _expiredDateController.text.isEmpty
              ? null
              : _expiredDateController.text,
      'is_permanent': _isPermanentSanction,
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
    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return SafeArea(
      top: false,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          bottom: AppSafeInsets.keyboardOrSystemBottom(context),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildUserPicker(),
                        const SizedBox(height: 12),
                        _buildTypeLevelRow(),
                        const SizedBox(height: 12),
                        _buildCategoryPicker(),
                        const SizedBox(height: 12),
                        _buildSubcategoryPicker(),
                        const SizedBox(height: 12),
                        _buildField(
                          _type == 'Incident'
                              ? 'Judul Incident'
                              : 'Judul Pelanggaran',
                          _titleController,
                          hint: 'Contoh: Tidak memakai helm',
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          'Deskripsi',
                          _descriptionController,
                          hint: 'Tuliskan deskripsi kronologi...',
                          maxLines: 3,
                          isRequired: false,
                        ),
                        const SizedBox(height: 12),
                        _buildField(
                          'Lokasi',
                          _locationController,
                          hint: 'Contoh: Pit A / Area Workshop',
                          isRequired: false,
                        ),
                        const SizedBox(height: 12),
                        InkWell(
                          onTap: _isPermanentSanction ? null : _selectExpiredDate,
                          child: IgnorePointer(
                            child: _buildField(
                              'Masa Berlaku',
                              _expiredDateController,
                              hint: _isPermanentSanction
                                  ? 'Permanen'
                                  : 'YYYY-MM-DD',
                              icon: Icons.event_available,
                              isRequired: false,
                              enabled: !_isPermanentSanction,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildSanctionPeriodPicker(),
                        const SizedBox(height: 12),
                        _buildStatusPicker(),
                        const SizedBox(height: 12),
                        _buildField(
                          'Sanksi / Tindakan',
                          _sanctionController,
                          hint: 'Contoh: SP1 / Teguran Lisan',
                          isRequired: false,
                        ),
                        const SizedBox(height: 12),
                        _buildImagePicker(),
                      ],
                    ),
                  ),
                ),
              ),
              Divider(height: 1, color: Colors.grey.shade100),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: _buildFooterButtons(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFF5F5F5))),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item == null ? 'Tambah $_type' : 'Edit $_type',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUserPicker() {
    final showUserError = _hasTriedSubmit && _selectedUser == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('User / Karyawan', isRequired: true),
        const SizedBox(height: 8),
        if (_selectedUser != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
              border: Border.all(
                color: showUserError
                    ? Colors.red
                    : const Color(0xFF1A56C4).withValues(alpha: 0.3),
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
                decoration: _userSearchDecoration(showUserError),
                onChanged: _searchUsers,
              ),
              if (showUserError)
                const Padding(
                  padding: EdgeInsets.only(left: 12, top: 6),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Wajib dipilih',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
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
                    borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
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

  Widget _buildTypeLevelRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _buildTypePicker()),
        const SizedBox(width: 12),
        Expanded(child: _buildLevelPicker()),
      ],
    );
  }

  Widget _buildLevelPicker() {
    final showLevelError = _hasTriedSubmit && _level == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Level', isRequired: true),
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
                  label: Text(level.toString()),
                  selected: selected,
                  selectedColor: color,
                  backgroundColor: color.withValues(alpha: 0.08),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(kMinimalDropdownRadius),
                    side: BorderSide(
                      color:
                          selected ? color : color.withValues(alpha: 0.25),
                    ),
                  ),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : color,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  onSelected: (_) => setState(() => _level = level),
                ),
              ),
            );
          }).toList(),
        ),
        if (showLevelError)
          const Padding(
            padding: EdgeInsets.only(left: 12, top: 6),
            child: Text(
              'Wajib dipilih',
              style: TextStyle(color: Colors.red, fontSize: 12),
            ),
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
      isRequired: true,
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
      isRequired: true,
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
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        Container(
          decoration: kMinimalFieldContainerDecoration,
          child: DropdownButtonFormField<T>(
            initialValue: value,
            icon: kMinimalDropdownChevron,
            borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
            style: kMinimalDropdownTextStyle,
            decoration: minimalFieldDecoration(hintText: 'Pilih $label'),
            validator:
                isRequired ? (value) => value == null ? 'Wajib dipilih' : null : null,
            items: items
                .map((item) => DropdownMenuItem<T>(
                      value: item,
                      child: Text(
                        itemLabel(item),
                        style: kMinimalDropdownTextStyle,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ))
                .toList(),
            onChanged: onChanged == null
                ? null
                : (selectedValue) {
                    if (selectedValue != null) onChanged(selectedValue);
                  },
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
            height: 112,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _violationImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
                    child: Image.file(File(_violationImage!.path), fit: BoxFit.cover),
                  )
                : (hasRemoteUrl
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(kMinimalDropdownRadius),
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
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel(label, isRequired: isRequired),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          enabled: enabled,
          maxLines: maxLines,
          validator:
              isRequired ? (v) => v == null || v.isEmpty ? 'Wajib diisi' : null : null,
          style: const TextStyle(fontSize: 14),
          decoration: minimalFieldDecoration(
            hintText: hint,
            prefixIcon: icon,
          ),
        ),
      ],
    );
  }

  Widget _buildSanctionPeriodPicker() {
    Widget option({
      required bool permanent,
      required String title,
      required String subtitle,
      required IconData icon,
    }) {
      final selected = _isPermanentSanction == permanent;
      final color = selected ? const Color(0xFF1A56C4) : Colors.grey.shade500;

      return Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
          onTap: () => setState(() {
            _isPermanentSanction = permanent;
            if (permanent) _expiredDateController.clear();
          }),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? const Color(0xFF1A56C4).withValues(alpha: 0.08)
                  : Colors.white,
              borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
              border: Border.all(
                color: selected
                    ? const Color(0xFF1A56C4)
                    : Colors.grey.shade300,
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: selected
                              ? const Color(0xFF1A56C4)
                              : Colors.grey.shade800,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 11,
                          height: 1.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLabel('Jenis Masa Sangsi'),
        const SizedBox(height: 8),
        Row(
          children: [
            option(
              permanent: false,
              title: 'Tanggal',
              subtitle: 'Berlaku sampai tanggal',
              icon: Icons.event_available,
            ),
            const SizedBox(width: 10),
            option(
              permanent: true,
              title: 'Permanen',
              subtitle: 'Tetap aktif tanpa tanggal',
              icon: Icons.all_inclusive,
            ),
          ],
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
              ),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A56C4),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
                ),
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

  Widget _buildLabel(String label, {bool isRequired = false}) {
    if (!isRequired) {
      return Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      );
    }

    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.black,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        children: const [
          TextSpan(text: ' *'),
        ],
      ),
    );
  }

  InputDecoration _userSearchDecoration(bool showError) {
    final decoration = minimalFieldDecoration(
      hintText: 'Cari nama atau ID karyawan...',
      prefixIcon: Icons.search,
    );

    if (!showError) return decoration;

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
      borderSide: const BorderSide(color: Colors.red),
    );

    return decoration.copyWith(
      enabledBorder: errorBorder,
      focusedBorder: errorBorder,
    );
  }
}
