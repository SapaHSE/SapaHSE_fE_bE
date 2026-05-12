import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sapahse/models/profile_model.dart';
import 'package:sapahse/services/profile_service.dart';
import 'package:sapahse/services/storage_service.dart';
import 'package:sapahse/utils/value_parser.dart';
import 'package:sapahse/utils/url_helper.dart';
import 'package:sapahse/main.dart';

class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;
  _FadePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
}

class MyProfileScreen extends StatefulWidget {
  final String? initialAction;
  const MyProfileScreen({super.key, this.initialAction});

  @override
  State<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends State<MyProfileScreen> {
  XFile? _avatarFile;
  int _selectedSubTab = 0;
  bool _isLoading = true;
  ProfileData? _profileData;
  Map<String, dynamic>? _cachedUser;
  String? _loadError;

  // Persistent State for License Form
  final TextEditingController _licenseNameController = TextEditingController();
  final TextEditingController _licenseNumberController = TextEditingController();
  DateTime? _licenseObtainedAt;
  DateTime? _licenseSelectedDate;

  // Persistent State for Certification Form
  final TextEditingController _certNameController = TextEditingController();
  final TextEditingController _certIssuerController = TextEditingController();
  DateTime? _certObtainedAt;
  DateTime? _certExpiredAt;
  XFile? _licenseImage;
  XFile? _certImage;  

  @override
  void dispose() {
    _licenseNameController.dispose();
    _licenseNumberController.dispose();
    _certNameController.dispose();
    _certIssuerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialAction == 'add_license') {
      _selectedSubTab = 1;
    } else if (widget.initialAction == 'add_certification') {
      _selectedSubTab = 3;
    } else if (widget.initialAction == 'edit_medical') {
      _selectedSubTab = 4;
    }
    _loadProfile().then((_) {
      if (widget.initialAction == 'edit_biodata') {
        _showEditProfileSheet();
      } else if (widget.initialAction == 'add_license') {
        _showAddLicenseForm();
      } else if (widget.initialAction == 'add_certification') {
        _showAddCertificationForm();
      } else if (widget.initialAction == 'edit_medical') {
        _showEditMedicalForm();
      }
    });
  }

  Future<void> _loadProfile() async {
    final cached = await StorageService.getUser();
    if (mounted) {
      setState(() => _cachedUser = cached);
    }

    final result = await ProfileService.getProfile();
    if (!mounted) return;
    if (result.success) {
      setState(() {
        _profileData = result.data;
        _loadError = null;
        _isLoading = false;
      });
    } else {
      setState(() {
        _loadError = result.errorMessage ?? 'Gagal memuat profil.';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImage() async {
    _showPhotoOptions();
  }

  Future<XFile?> _pickImageForForm() async {
    if (kIsWeb) {
      final picker = ImagePicker();
      return picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    }

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Sumber Foto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1A56C4)),
              title: const Text('Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1A56C4)),
              title: const Text('Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return null;
    final picker = ImagePicker();
    return picker.pickImage(source: source, imageQuality: 90);
  }

  void _showPhotoOptions() {
    if (kIsWeb) {
      _pickImageFromSource(ImageSource.gallery);
      return;
    }
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Sumber Foto',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF1A56C4)),
              title: const Text('Kamera'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF1A56C4)),
              title: const Text('Galeri'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromSource(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return;

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: picked.path,
        compressQuality: 90,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Foto Profil',
            toolbarColor: const Color(0xFF1A56C4),
            toolbarWidgetColor: Colors.white,
            statusBarColor: const Color(0xFF1A56C4),
            activeControlsWidgetColor: const Color(0xFF1A56C4),
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
            hideBottomControls: true,
          ),
          IOSUiSettings(
            title: 'Crop Foto Profil',
            aspectRatioLockEnabled: true,
          ),
        ],
      );
      if (croppedFile == null) return;

      setState(() {
        _isLoading = true;
        _avatarFile = XFile(croppedFile.path);
      });

      final result = await ProfileService.updateProfile(
        imagePath: croppedFile.path,
      );

      if (!mounted) return;
      if (!result.success) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result.errorMessage ?? 'Gagal mengunggah foto profil')),
        );
        return;
      }

      await _loadProfile();
      if (!mounted) return;
      setState(() => _avatarFile = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui')),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi masalah saat memilih atau crop foto.'),
        ),
      );
    }
  }

final List<Map<String, dynamic>> _subTabs = [
  {
    'label': 'Biodata',
    'icon': Icons.person,
    'color': const Color(0xFF1A56C4)
  },
  {'label': 'Lisensi', 'icon': Icons.badge, 'color': const Color(0xFF1A56C4)},
  {
    'label': 'Pelanggaran',
    'icon': Icons.warning_amber_rounded,
    'color': const Color(0xFF1A56C4)
  },
  {
    'label': 'Sertifikat',
    'icon': Icons.workspace_premium,
    'color': const Color(0xFF1A56C4)
  },
  {
    'label': 'Medis',
    'icon': Icons.medical_services,
    'color': const Color(0xFF1A56C4)
  },
];

  void _onTabTapped(int index) {
    if (index == 4) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      _FadePageRoute(builder: (_) => MainScreen(initialIndex: index)),
    );
  }

  void _openFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProfileFabMenuSheet(
        onEditBiodata: () {
          Navigator.pop(context);
          _showEditProfileSheet();
        },
        onAddLicense: () {
          Navigator.pop(context);
          _showAddLicenseForm();
        },
        onAddCertification: () {
          Navigator.pop(context);
          _showAddCertificationForm();
        },
        onEditMedical: () {
          Navigator.pop(context);
          _showEditMedicalForm();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading){
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            _buildSubTabBar(),
            const SizedBox(height: 20),
            _buildSubTabContent(),
            const SizedBox(height: 40),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openFabMenu,
        backgroundColor: const Color(0xFF1A56C4),
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: 4,
        child: const Icon(Icons.add, size: 30),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        color: Colors.white,
        elevation: 8,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ProfileNavItem(
                  icon: Icons.home,
                  label: 'Home',
                  index: 0,
                  currentIndex: 4,
                  onTap: _onTabTapped),
              _ProfileNavItem(
                  icon: Icons.article_outlined,
                  label: 'News',
                  index: 1,
                  currentIndex: 4,
                  onTap: _onTabTapped),
              const SizedBox(width: 48),
              _ProfileNavItem(
                  icon: Icons.inbox_outlined,
                  label: 'Inbox',
                  index: 3,
                  currentIndex: 4,
                  onTap: _onTabTapped),
              _ProfileNavItem(
                  icon: Icons.menu,
                  label: 'Menu',
                  index: 4,
                  currentIndex: 4,
                  onTap: _onTabTapped),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = parseNullableDisplayName(_profileData?.fullName) ??
        parseNullableDisplayName(_cachedUser?['full_name']) ??
        '-';
    final position = parseNullableDisplayName(_profileData?.position) ??
        parseNullableDisplayName(_cachedUser?['position']) ??
        '-';
    final department = parseNullableDisplayName(_profileData?.department) ??
        parseNullableDisplayName(_cachedUser?['department']) ??
        '-';
    final company = parseNullableDisplayName(_profileData?.company) ??
        parseNullableDisplayName(_cachedUser?['company']) ??
        '-';
    final initials = name
        .split(' ')
        .take(2)
        .map((e) => e.isNotEmpty ? e[0] : '')
        .join()
        .toUpperCase();
    final hasAvatar = _avatarFile != null || _resolveProfilePhoto() != null;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          if (_loadError != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFFE082)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFB28704), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Menampilkan data tersimpan. ${_loadError!}',
                      style: const TextStyle(
                          color: Color(0xFF7A5A00), fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _isLoading = true;
                        _loadError = null;
                      });
                      _loadProfile();
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF1A56C4),
                backgroundImage: _getAvatarImage(),
                child: !hasAvatar
                    ? Text(initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.bold))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                        color: Color(0xFF1A56C4), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$position — Dept. $department',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(company,
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  String? _resolveProfilePhoto() {
    final fromProfile = normalizeStorageUrl(_profileData?.profilePhoto);
    if (parseNullableDisplayName(fromProfile) != null) return fromProfile;

    final fromCacheProfilePhoto =
        normalizeStorageUrl(parseNullableDisplayName(_cachedUser?['profile_photo']));
    if (parseNullableDisplayName(fromCacheProfilePhoto) != null) {
      return fromCacheProfilePhoto;
    }

    final fromCacheProfilePhotoUrl = normalizeStorageUrl(
      parseNullableDisplayName(_cachedUser?['profile_photo_url']),
    );
    if (parseNullableDisplayName(fromCacheProfilePhotoUrl) != null) {
      return fromCacheProfilePhotoUrl;
    }
    return null;
  }

  ImageProvider? _getAvatarImage() {
    if (_avatarFile != null) {
      return FileImage(File(_avatarFile!.path));
    }
    final photo = _resolveProfilePhoto();
    final resolved = parseNullableDisplayName(photo);
    if (resolved != null) {
      return NetworkImage(resolved);
    }
    return null;
  }

  Widget _buildSubTabBar() {
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _subTabs.length,
        itemBuilder: (context, index) {
          final tab = _subTabs[index];
          final isSelected = _selectedSubTab == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedSubTab = index),
            child: Container(
              width: 80,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? tab['color'].withOpacity(0.1)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isSelected ? tab['color'] : Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab['icon'],
                      color: isSelected ? tab['color'] : Colors.grey.shade400,
                      size: 24),
                  const SizedBox(height: 8),
                  Text(tab['label'],
                      style: TextStyle(
                          color:
                              isSelected ? tab['color'] : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSubTabContent() {
    switch (_selectedSubTab) {
      case 0:
        return _BiodataContent(data: _profileData);
      case 1:
        return _LicenseContent(
          licenses: _profileData?.licenses ?? [],
          onAdd: _showAddLicenseForm,
        );
      case 2:
        return _ViolationContent(violations: _profileData?.violations ?? []);
      case 3:
        return _CertificationContent(
          certifications: _profileData?.certifications ?? [],
          onAdd: _showAddCertificationForm,
        );
      case 4:
        return _MedicalContent(medicals: _profileData?.medicals ?? []);
      default:
        return const SizedBox();
    }
  }


  void _showEditProfileSheet() {
    if (_profileData == null) return;

    final nikCtrl = TextEditingController(text: _profileData?.employeeId);
    final nameCtrl = TextEditingController(text: _profileData?.fullName);
    final emailCtrl = TextEditingController(text: _profileData?.personalEmail);
    final phoneCtrl = TextEditingController(
        text: (_profileData?.phoneNumber ?? '').replaceFirst('+62', ''));
    final workEmailCtrl = TextEditingController(text: _profileData?.workEmail);
    final deptCtrl = TextEditingController(text: _profileData?.department);
    final jobCtrl = TextEditingController(text: _profileData?.position);
    final addressCtrl = TextEditingController(text: _profileData?.address);
    final formKey = GlobalKey<FormState>();
    XFile? localImageFile;
    final existingProfilePhoto = parseNullableDisplayName(_resolveProfilePhoto());
    final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Edit Profil',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Center(
                        child: Stack(
                          children: [
                            CircleAvatar(
                              radius: 50,
                              backgroundColor: Colors.white,
                              backgroundImage: localImageFile != null
                                  ? FileImage(File(localImageFile!.path))
                                  : (existingProfilePhoto != null
                                      ? NetworkImage(existingProfilePhoto)
                                      : null) as ImageProvider?,
                              child: (localImageFile == null &&
                                      existingProfilePhoto == null)
                                  ? Icon(Icons.person, size: 50, color: Colors.grey.shade400)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await _pickImageForForm();
                                  if (picked != null) {
                                    setModalState(() => localImageFile = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A56C4),
                                    shape: BoxShape.circle,
                                    border: Border.fromBorderSide(BorderSide(color: Colors.white, width: 2)),
                                  ),
                                  child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Form(
                        key: formKey,
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSheetField('NIK', nikCtrl, enabled: false),
                              const SizedBox(height: 16),
                              _buildSheetField(
                                'Nama Lengkap',
                                nameCtrl,
                                maxLength: 25,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Nama lengkap wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildSheetField(
                                'Email',
                                emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                maxLength: 100,
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) return 'Email wajib diisi';
                                  if (!emailRegex.hasMatch(value)) {
                                    return 'Format email tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Nomor Telepon',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  IntrinsicHeight(
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.only(
                                              left: 12, right: 6),
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade100,
                                            border: Border.all(
                                                color: Colors.grey.shade300),
                                            borderRadius:
                                                const BorderRadius.only(
                                                    topLeft:
                                                        Radius.circular(8),
                                                    bottomLeft:
                                                        Radius.circular(8)),
                                          ),
                                          child: const Text('+62',
                                              style: TextStyle(
                                                  color: Colors.black87,
                                                  fontSize: 14)),
                                        ),
                                        Expanded(
                                          child: TextFormField(
                                            controller: phoneCtrl,
                                            keyboardType: TextInputType.phone,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly
                                            ],
                                              maxLength: 13,
                                              style: const TextStyle(
                                                  fontSize: 14),
                                            autovalidateMode: AutovalidateMode
                                                .onUserInteraction,
                                            decoration: InputDecoration(
                                              hintText: '812xxxxxxxx',
                                              hintStyle: const TextStyle(
                                                  color: Colors.grey,
                                                  fontSize: 13),
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 10),
                                              border: OutlineInputBorder(
                                                  borderRadius:
                                                      const BorderRadius.only(
                                                          topRight:
                                                              Radius.circular(
                                                                  8),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  8)),
                                                  borderSide: BorderSide(
                                                      color: Colors
                                                          .grey.shade300)),
                                              enabledBorder:
                                                  OutlineInputBorder(
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                          topRight:
                                                              Radius.circular(
                                                                  8),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  8),
                                                        ),
                                                      borderSide: BorderSide(
                                                          color: Colors
                                                              .grey.shade300)),
                                              focusedBorder:
                                                  OutlineInputBorder(
                                                      borderRadius:
                                                          const BorderRadius
                                                              .only(
                                                          topRight:
                                                              Radius.circular(
                                                                  8),
                                                          bottomRight:
                                                              Radius.circular(
                                                                  8)),
                                                      borderSide:
                                                          const BorderSide(
                                                              color: Color(
                                                                  0xFF1A56C4))),
                                              filled: true,
                                              fillColor:
                                                  Colors.white,
                                              counterText: '',
                                            ),
                                            validator: (v) {
                                              final value =
                                                  (v ?? '').trim();
                                              if (value.isEmpty) {
                                                return 'Nomor telepon wajib diisi';
                                              }
                                              if (!RegExp(r'^8[0-9]{7,12}$')
                                                  .hasMatch(value)) {
                                                return 'Masukkan 8-13 digit setelah +62';
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _buildSheetField(
                                'Email Kantor (Opsional)',
                                workEmailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                maxLength: 100,
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isEmpty) return null;
                                  if (!emailRegex.hasMatch(value)) {
                                    return 'Format email kantor tidak valid';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildSheetField(
                                'Departemen',
                                deptCtrl,
                                enabled: false,
                                maxLength: 25,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Departemen wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildSheetField(
                                'Jabatan',
                                jobCtrl,
                                enabled: false,
                                maxLength: 25,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Jabatan wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              _buildSheetField(
                                'Alamat',
                                addressCtrl,
                                maxLines: 2,
                                maxLength: 255,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Alamat wajib diisi';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!formKey.currentState!.validate()) {
                              return;
                            }

                            Navigator.pop(context);
                            setState(() => _isLoading = true);

                            final result = await ProfileService.updateProfile(
                              fullName: nameCtrl.text.trim(),
                              personalEmail: emailCtrl.text.trim(),
                              workEmail: workEmailCtrl.text.trim(),
                              phoneNumber: '+62${phoneCtrl.text.trim()}',
                              department: deptCtrl.text.trim(),
                              position: jobCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              imagePath: localImageFile?.path,
                            );

                            if (mounted) {
                              if (result.success) {
                                _loadProfile();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Profil berhasil diperbarui')),
                                );
                              } else {
                                setState(() => _isLoading = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(result.errorMessage ?? 'Gagal memperbarui')),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56C4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSheetField(String label, TextEditingController controller,
      {bool enabled = true,
      TextInputType? keyboardType,
      int maxLines = 1,
      int? maxLength,
      String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFF1A56C4))),
            disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      ],
    );
  }

  void _showEditMedicalForm() {
    final medicals = _profileData?.medicals ?? [];
    final latest = medicals.isNotEmpty ? medicals.first : null;

    final bloodTypeCtrl = TextEditingController(text: latest?.bloodType);
    final heightCtrl = TextEditingController(text: latest?.height);
    final weightCtrl = TextEditingController(text: latest?.weight);
    final bloodPressureCtrl =
        TextEditingController(text: latest?.bloodPressure);
    final allergiesCtrl = TextEditingController(text: latest?.allergies);
    final lastMedicationCtrl = TextEditingController(text: latest?.lastMedication);
    final currentMedicationCtrl = TextEditingController(text: latest?.currentMedication);
    final currentIllnessCtrl = TextEditingController(text: latest?.currentIllness);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Edit Information Medis',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Golongan Darah'),
                TextField(
                  controller: bloodTypeCtrl,
                  decoration: _buildInputDecoration('Contoh: O, A, B, AB'),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Tinggi Badan (cm)'),
                TextField(
                  controller: heightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Contoh: 170'),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Berat Badan (kg)'),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Contoh: 65'),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Tekanan Darah'),
                TextField(
                  controller: bloodPressureCtrl,
                  decoration: _buildInputDecoration('Contoh: 120/80'),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Alergi'),
                TextField(
                  controller: allergiesCtrl,
                  decoration: _buildInputDecoration('Contoh: Debu, Seafood...'),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Konsumsi Obat Terakhir'),
                          TextField(
                            controller: lastMedicationCtrl,
                            decoration: _buildInputDecoration('Contoh: Paracetamol'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFieldLabel('Obat Berjalan'),
                          TextField(
                            controller: currentMedicationCtrl,
                            decoration: _buildInputDecoration('Contoh: Metformin'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Penyakit yang Sedang Diderita'),
                TextField(
                  controller: currentIllnessCtrl,
                  maxLines: 2,
                  decoration: _buildInputDecoration('Contoh: Diabetes, Hipertensi...'),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      setState(() => _isLoading = true);

                      final result = await ProfileService.updateMedical(
                        bloodType: bloodTypeCtrl.text,
                        height: heightCtrl.text,
                        weight: weightCtrl.text,
                        bloodPressure: bloodPressureCtrl.text,
                        allergies: allergiesCtrl.text,
                        lastMedication: lastMedicationCtrl.text,
                        currentMedication: currentMedicationCtrl.text,
                        currentIllness: currentIllnessCtrl.text,
                      );

                      if (result.success) {
                        if (mounted) _loadProfile();
                      } else {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(result.message)));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C38FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Simpan Data Medis',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAddLicenseForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Tambah Lisensi Baru',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Nama Lisensi (SIM/SIO)'),
              TextField(
                controller: _licenseNameController,
                decoration:
                    _buildInputDecoration('Contoh: SIM A, SIO Excavator...'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Nomor Lisensi'),
              TextField(
                controller: _licenseNumberController,
                decoration: _buildInputDecoration('Contoh: SIM-2024-001234'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Tanggal Diperoleh'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null)
                    setModalState(() => _licenseObtainedAt = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Text(
                        _licenseObtainedAt == null
                            ? 'Pilih Tanggal'
                            : '${_licenseObtainedAt!.day}/${_licenseObtainedAt!.month}/${_licenseObtainedAt!.year}',
                        style: TextStyle(
                            color: _licenseObtainedAt == null ? Colors.grey.shade500 : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Berlaku Sampai'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365 * 5)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null)
                    setModalState(() => _licenseSelectedDate = picked);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today,
                          size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Text(
                        _licenseSelectedDate == null
                            ? 'Pilih Tanggal'
                            : '${_licenseSelectedDate!.day}/${_licenseSelectedDate!.month}/${_licenseSelectedDate!.year}',
                        style: TextStyle(
                            color: _licenseSelectedDate == null
                                ? Colors.grey.shade500
                                : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Foto Lisensi'),
              _buildImagePicker(
                image: _licenseImage,
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null){
                    setModalState(() => _licenseImage = picked);
                  }
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_licenseNameController.text.isEmpty ||
                        _licenseNumberController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Harap lengkapi semua data')));
                      return;
                    }

                    Navigator.pop(context); // Close modal
                    setState(() => _isLoading = true);

                    final result = await ProfileService.addLicense(
                      name: _licenseNameController.text,
                      licenseNumber: _licenseNumberController.text,
                      obtainedAt: _licenseObtainedAt != null
                          ? '${_licenseObtainedAt!.year}-${_licenseObtainedAt!.month.toString().padLeft(2, '0')}-${_licenseObtainedAt!.day.toString().padLeft(2, '0')}'
                          : null,
                      expiredAt: _licenseSelectedDate != null
                          ? '${_licenseSelectedDate!.year}-${_licenseSelectedDate!.month.toString().padLeft(2, '0')}-${_licenseSelectedDate!.day.toString().padLeft(2, '0')}'
                          : null,
                      imageFile: _licenseImage,
                    );

                    if (result.success) {
                      _licenseNameController.clear();
                      _licenseNumberController.clear();
                      _licenseObtainedAt = null;
                      _licenseSelectedDate = null;
                      _licenseImage = null;
                      if (mounted) _loadProfile(); // Refresh
                    } else {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result.message)));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Lisensi',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCertificationForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Tambah Sertifikat Baru',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Nama Sertifikat'),
              TextField(
                controller: _certNameController,
                decoration: _buildInputDecoration(
                    'Contoh: Ahli K3 Umum, Basic Safety...'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Lembaga Penerbit'),
              TextField(
                controller: _certIssuerController,
                decoration:
                    _buildInputDecoration('Contoh: Kemnaker RI, BNSP...'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Sertifikat Diperoleh'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setModalState(() => _certObtainedAt = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Text(
                        _certObtainedAt == null
                            ? 'Pilih Tanggal'
                            : '${_certObtainedAt!.day}/${_certObtainedAt!.month}/${_certObtainedAt!.year}',
                        style: TextStyle(
                            color: _certObtainedAt == null ? Colors.grey.shade500 : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Berlaku Sampai'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setModalState(() => _certExpiredAt = picked);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 12),
                      Text(
                        _certExpiredAt == null
                            ? 'Pilih Tanggal'
                            : '${_certExpiredAt!.day}/${_certExpiredAt!.month}/${_certExpiredAt!.year}',
                        style: TextStyle(
                            color: _certExpiredAt == null ? Colors.grey.shade500 : Colors.black),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Foto Sertifikat'),
              _buildImagePicker(
                image: _certImage,
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null) setModalState(() => _certImage = picked);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (_certNameController.text.isEmpty ||
                        _certIssuerController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Harap lengkapi nama dan penerbit')));
                      return;
                    }

                    Navigator.pop(context); // Close modal
                    setState(() => _isLoading = true);

                    final result = await ProfileService.addCertification(
                      name: _certNameController.text,
                      issuer: _certIssuerController.text,
                      obtainedAt: _certObtainedAt != null
                          ? '${_certObtainedAt!.year}-${_certObtainedAt!.month.toString().padLeft(2, '0')}-${_certObtainedAt!.day.toString().padLeft(2, '0')}'
                          : null,
                      expiredAt: _certExpiredAt != null
                          ? '${_certExpiredAt!.year}-${_certExpiredAt!.month.toString().padLeft(2, '0')}-${_certExpiredAt!.day.toString().padLeft(2, '0')}'
                          : null,
                      imageFile: _certImage,
                    );

                    if (result.success) {
                      _certNameController.clear();
                      _certIssuerController.clear();
                      _certObtainedAt = null;
                      _certExpiredAt = null;
                      _certImage = null;
                      if (mounted) _loadProfile(); // Refresh
                    } else {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result.message)));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Sertifikat',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Colors.black87)),
      );

  InputDecoration _buildInputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF1A56C4))),
      );

  Widget _buildImagePicker({XFile? image, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border:
              Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(image.path), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined,
                      color: Colors.grey.shade400, size: 32),
                  const SizedBox(height: 8),
                  Text('Ambil atau Pilih Foto',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
      ),
    );
  }

}

// ── SUB-TAB WIDGETS (INTERNAL) ──────────────────────────────────────────────

class _BiodataContent extends StatelessWidget {
  final ProfileData? data;
  const _BiodataContent({this.data});

  void _copyToClipboard(BuildContext context, String label, String? value) {
    if (value != null && value != '-' && value.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: value));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label berhasil disalin'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle('INFORMATION PERSONAL'),
          _buildCard([
            _buildRow(context, 'NIK', data?.employeeId ?? '-',
                onTap: () =>
                    _copyToClipboard(context, 'NIK', data?.employeeId)),
            _buildRow(context, 'Nama Lengkap', data?.fullName ?? '-',
                onTap: () =>
                    _copyToClipboard(context, 'Nama Lengkap', data?.fullName)),
            _buildRow(context, 'Email', data?.personalEmail ?? '-',
                onTap: () => _launchUrl('mailto:${data?.personalEmail ?? ""}')),
            _buildRow(context, 'Phone', data?.phoneNumber ?? '-', onTap: () {
              final phone = data?.phoneNumber ?? "";
              if (phone.isNotEmpty && phone != '-') {
                String waNumber = phone;
                if (waNumber.startsWith('08')) {
                  waNumber = '628' + waNumber.substring(2);
                }
                _launchUrl('https://wa.me/$waNumber');
              }
            }),
            _buildRow(context, 'Alamat', data?.address ?? '-',
                onTap: () =>
                    _copyToClipboard(context, 'Alamat', data?.address)),
          ]),
          const SizedBox(height: 24),
          _buildTitle('INFORMATION EMPLOYEE'),
          _buildCard([
            _buildRow(context, 'Tipe Afiliasi', data?.tipeAfiliasi ?? '-'),
            _buildRow(context, 'Perusahaan Owner', data?.company ?? '-'),
            if (data?.tipeAfiliasi == 'Kontraktor' ||
                data?.tipeAfiliasi == 'Sub-Kontraktor' ||
                data?.tipeAfiliasi == 'Sub-Kont.')
              _buildRow(context, 'Perusahaan Kontraktor',
                  data?.perusahaanKontraktor ?? '-'),
            if (data?.tipeAfiliasi == 'Sub-Kontraktor' ||
                data?.tipeAfiliasi == 'Sub-Kont.')
              _buildRow(context, 'Sub-Kontraktor',
                  data?.subKontraktor ?? '-'),
            _buildRow(context, 'Departemen', data?.department ?? '-'),
            _buildRow(context, 'Jabatan', data?.position ?? '-'),
          ]),
        ],
      ),
    );
  }

  Widget _buildTitle(String title) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(title,
            style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 11,
                fontWeight: FontWeight.bold)),
      );

  Widget _buildCard(List<Widget> children) => Container(
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200)),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: Column(
              children: children
                  .asMap()
                  .entries
                  .map((e) => Column(children: [
                        e.value,
                        if (e.key < children.length - 1)
                          Divider(
                              height: 1,
                              color: Colors.grey.shade100,
                              indent: 16,
                              endIndent: 16)
                      ]))
                  .toList()),
        ),
      );

  Widget _buildRow(BuildContext context, String label, String value,
      {VoidCallback? onTap}) {
    Widget content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 13))),
          const SizedBox(width: 12),
          Expanded(
              child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                  child: Text(value,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                           fontWeight: FontWeight.bold,
                           fontSize: 13,
                           height: 1.3))),
            ],
          )),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

class _LicenseContent extends StatelessWidget {
  final List<UserLicense> licenses;
  final VoidCallback onAdd;
  const _LicenseContent({required this.licenses, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...licenses.map((l) {
            final isAktif = l.isActive;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color:
                          isAktif ? Colors.grey.shade200 : Colors.red.shade100),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_outlined,
                        color: Color(0xFF1E88E5), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('No. ${l.licenseNumber}',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                        if (l.obtainedAt != null)
                          Text('Diperoleh: ${l.obtainedAt}',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12)),
                        if (l.expiredAt != null)
                          Text('Berlaku s/d: ${l.expiredAt}',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12)),
                        if (l.fileUrl != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              l.fileUrl!,
                              height: 60,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAktif
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAktif ? 'Aktif' : 'Expired',
                      style: TextStyle(
                        color: isAktif
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFD32F2F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CertificationContent extends StatelessWidget {
  final List<UserCertification> certifications;
  final VoidCallback onAdd;
  const _CertificationContent(
      {required this.certifications, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...certifications.map((c) {
            final isAktif = c.isActive;
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 10,
                        offset: const Offset(0, 4))
                  ]),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium_outlined,
                        color: Color(0xFF6A1B9A), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(c.issuer,
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 13)),
                        if (c.obtainedAt != null)
                          Text('Diperoleh: ${c.obtainedAt}',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12)),
                        if (c.expiredAt != null)
                          Text('Berlaku s/d: ${c.expiredAt}',
                              style: TextStyle(
                                  color: Colors.grey.shade400, fontSize: 12)),
                        if (c.fileUrl != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              c.fileUrl!,
                              height: 60,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const SizedBox(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAktif
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAktif ? 'Aktif' : 'Renew',
                      style: TextStyle(
                        color: isAktif
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFEF6C00),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MedicalContent extends StatelessWidget {
  final List<UserMedical> medicals;
  const _MedicalContent({required this.medicals});

  @override
  Widget build(BuildContext context) {
    final latest = medicals.isNotEmpty ? medicals.first : null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('INFORMATION MEDIS',
                style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 11,
                    fontWeight: FontWeight.bold)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                _buildMedicalRow('Golongan Darah', latest?.bloodType ?? '-'),
                _buildDivider(),
                _buildMedicalRow('Tinggi Badan', latest?.height ?? '-'),
                _buildDivider(),
                _buildMedicalRow('Berat Badan', latest?.weight ?? '-'),
                _buildDivider(),
                _buildMedicalRow('Tekanan Darah', latest?.bloodPressure ?? '-'),
                _buildDivider(),
                _buildMedicalRow('Alergi', latest?.allergies ?? 'Tidak Ada',
                    isBoldValue: true),
                _buildDivider(),
                _buildMedicalRow('MCU Terakhir', latest?.checkupDate ?? '-'),
                _buildDivider(),
                _buildMedicalRow('Hasil MCU', latest?.result ?? '-'),
                _buildDivider(),
                _buildMedicalRow(
                    'MCU Berikutnya', latest?.nextCheckupDate ?? '-'),
                _buildDivider(),
                _buildMedicalRow(
                    'Konsumsi Obat Terakhir', latest?.lastMedication ?? '-'),
                _buildDivider(),
                _buildMedicalRow(
                    'Obat Berjalan', latest?.currentMedication ?? '-'),
                _buildDivider(),
                _buildMedicalRow(
                    'Penyakit Diderita', latest?.currentIllness ?? '-',
                    isBoldValue: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.orange, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Information medis dikelola oleh Klinik & Dokter Perusahaan',
                    style: TextStyle(
                        color: Colors.indigo.shade800,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(
      height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16);

  Widget _buildMedicalRow(String label, String value,
          {bool isBoldValue = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                  fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500,
                  fontSize: 14,
                  color: isBoldValue ? Colors.black : Colors.grey.shade700,
                )),
          ],
        ),
      );
}

class _ViolationContent extends StatelessWidget {
  final List<UserViolation> violations;
  const _ViolationContent({required this.violations});

  @override
  Widget build(BuildContext context) {
    if (violations.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Tidak ada riwayat pelanggaran',
                  style: TextStyle(color: Colors.grey.shade600)),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'RIWAYAT PELANGGARAN',
              style: TextStyle(
                  color: Colors.grey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
          ),
          ...violations.map((v) {
            final isAktif = v.status.toLowerCase() == 'aktif';
            final color = isAktif ? Colors.red.shade700 : Colors.grey.shade700;
            final bgColor = isAktif ? Colors.red.shade50 : Colors.grey.shade100;

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.02),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                v.title,
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${v.location ?? "-"} · ${v.dateOfViolation ?? "-"}',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13),
                              ),
                              if (v.expiredAt != null &&
                                  v.expiredAt!.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  'Berlaku S/D: ${v.expiredAt}',
                                  style: TextStyle(
                                    color: Colors.blue.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            v.status,
                            style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.bold,
                                fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (v.sanction != null && v.sanction!.isNotEmpty) ...[
                    Divider(height: 1, color: Colors.grey.shade100),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Sanksi: ${v.sanction}',
                        style: TextStyle(color: color, fontSize: 13),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

// ── NAV ITEM ──────────────────────────────────────────────────────────────────
class _ProfileNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int index;
  final int currentIndex;
  final Function(int) onTap;

  const _ProfileNavItem({
    required this.icon,
    required this.label,
    required this.index,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isActive = currentIndex == index;
    return GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: isActive ? const Color(0xFF1A56C4) : Colors.grey,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileMenuTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileMenuTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 20),
            ],
          ),
        ),
      );
}

// ── FAB BOTTOM SHEET ──────────────────────────────────────────────────────────
class _ProfileFabMenuSheet extends StatelessWidget {
  final VoidCallback onEditBiodata;
  final VoidCallback onAddLicense;
  final VoidCallback onAddCertification;
  final VoidCallback onEditMedical;

  const _ProfileFabMenuSheet({
    required this.onEditBiodata,
    required this.onAddLicense,
    required this.onAddCertification,
    required this.onEditMedical,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text('Pilih Aksi Profil',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87)),
          ),
          const SizedBox(height: 8),
          _ProfileMenuTile(
            icon: Icons.person_outline,
            iconBgColor: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF8E24AA),
            title: 'Edit Profil',
            subtitle: 'Perbarui foto, email, telepon & alamat',
            onTap: onEditBiodata,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileMenuTile(
            icon: Icons.badge_outlined,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1E88E5),
            title: 'Tambah Lisensi',
            subtitle: 'Tambahkan SIM/SIO',
            onTap: onAddLicense,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileMenuTile(
            icon: Icons.workspace_premium_outlined,
            iconBgColor: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFEF6C00),
            title: 'Tambah Sertifikat',
            subtitle: 'Tambahkan sertifikasi keahlian',
            onTap: onAddCertification,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileMenuTile(
            icon: Icons.medical_services_outlined,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFE53935),
            title: 'Edit Information Medis',
            subtitle: 'Perbarui info kesehatan & alergi',
            onTap: onEditMedical,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade200)),
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
