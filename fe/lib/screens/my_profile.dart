import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sapahse/models/profile_model.dart';
import 'package:sapahse/models/department_model.dart';
import 'package:sapahse/services/company_service.dart';
import 'package:sapahse/services/department_service.dart';
import 'package:sapahse/services/profile_service.dart';
import 'package:sapahse/services/storage_service.dart';
import 'package:sapahse/utils/approval_status_ui.dart';
import 'package:sapahse/utils/value_parser.dart';
import 'package:sapahse/utils/url_helper.dart';
import 'package:sapahse/main.dart';
import 'package:sapahse/widgets/app_safe_insets.dart';
import 'package:sapahse/widgets/fab_notched_bottom_bar.dart';

class _FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget Function(BuildContext) builder;
  _FadePageRoute({required this.builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 200),
        );
}

String _displayValue(String? value) =>
    parseNullableDisplayName(value)?.trim() ?? '';

String companyLookupKey(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[.,]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ');
  return normalized.startsWith('pt ')
      ? normalized.substring(3).trim()
      : normalized;
}

String formatCompanyAffiliation({
  required String? tipeAfiliasi,
  required String? ownerCompany,
  required String? contractorCompany,
  required String? subContractorCompany,
  Map<String, String> ownerCompanyCodeLookup = const {},
  Map<String, String> companyCodeLookup = const {},
}) {
  final type = _displayValue(tipeAfiliasi).toLowerCase();
  final owner = _displayValue(ownerCompany);
  final contractor = _displayValue(contractorCompany);
  final subContractor = _displayValue(subContractorCompany);

  String getCode(String name) {
    if (name.isEmpty) return '';
    final key = companyLookupKey(name);
    return companyCodeLookup[key] ?? ownerCompanyCodeLookup[key] ?? '';
  }

  if (type == 'kontraktor') {
    final code = getCode(contractor);
    final contractorText = code.isNotEmpty ? '$contractor ($code)' : contractor;
    final ownerCode = getCode(owner);
    final ownerText = ownerCode.isNotEmpty ? ownerCode : owner;
    return owner.isNotEmpty ? '$contractorText - $ownerText' : contractorText;
  }
  if (type == 'sub-kontraktor' || type == 'sub-kont.') {
    final code = getCode(subContractor);
    final subText = code.isNotEmpty ? '$subContractor ($code)' : subContractor;
    final ownerCode = getCode(owner);
    final ownerText = ownerCode.isNotEmpty ? ownerCode : owner;
    return owner.isNotEmpty ? '$subText - $ownerText' : subText;
  }
  return owner.isNotEmpty ? owner : '-';
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
  List<String> _ownerList = [];
  Map<String, String> _ownerCodeByName = const {};
  Map<String, String> _companyCodeLookup = const {};
  List<String> _kontraktorList = [];
  List<String> _subkontraktorList = [];
  bool _isFetchingCompanies = false;
  String? _userRole;

  // Persistent State for License Form
  final TextEditingController _licenseNameController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _licenseIssuerController =
      TextEditingController();
  DateTime? _licenseObtainedAt;
  DateTime? _licenseSelectedDate;

  // Persistent State for Certification Form
  final TextEditingController _certNameController = TextEditingController();
  final TextEditingController _certNumberController = TextEditingController();
  final TextEditingController _certIssuerController = TextEditingController();
  DateTime? _certObtainedAt;
  DateTime? _certExpiredAt;
  XFile? _licenseImage;
  XFile? _certImage;

  @override
  void dispose() {
    _licenseNameController.dispose();
    _licenseNumberController.dispose();
    _licenseIssuerController.dispose();
    _certNameController.dispose();
    _certNumberController.dispose();
    _certIssuerController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _fetchCompanyData();
    if (widget.initialAction == 'add_license') {
      _selectedSubTab = 2; // Lisensi is now index 2
    } else if (widget.initialAction == 'add_certification') {
      _selectedSubTab = 4; // Sertifikat is now index 4
    } else if (widget.initialAction == 'edit_medical') {
      _selectedSubTab = 1; // Medis is now index 1
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLoading) {
        _showLoadingDialog('Memuat Profil...');
      }
    });
    _loadProfile().then((_) {
      _dismissLoadingDialog();
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

  Future<void> _fetchCompanyData() async {
    if (_isFetchingCompanies) return;
    _isFetchingCompanies = true;

    try {
      final results = await Future.wait([
        CompanyService.getCompanies(category: 'owner', active: true),
        CompanyService.getCompanies(category: 'kontraktor', active: true),
        CompanyService.getCompanies(category: 'subkontraktor', active: true),
      ]);

      if (!mounted) return;
      setState(() {
        _ownerList = results[0].map((e) => e.name).toList();
        _ownerCodeByName = {
          for (final company in results[0])
            if ((company.code ?? '').trim().isNotEmpty)
              companyLookupKey(company.name): company.code!.trim(),
          for (final company in results[0])
            if ((company.code ?? '').trim().isNotEmpty)
              companyLookupKey(company.code!): company.code!.trim(),
        };
        _kontraktorList = results[1].map((e) => e.name).toList();
        _subkontraktorList = results[2].map((e) => e.name).toList();

        final allComps = [...results[0], ...results[1], ...results[2]];
        _companyCodeLookup = {
          for (final company in allComps)
            if ((company.code ?? '').trim().isNotEmpty)
              companyLookupKey(company.name): company.code!.trim(),
        };
      });
    } catch (e) {
      debugPrint('Error fetching companies in Profile: $e');
    } finally {
      _isFetchingCompanies = false;
    }
  }

  Future<void> _loadProfile() async {
    final cached = await StorageService.getUser();
    if (mounted) {
      setState(() {
        _cachedUser = cached;
        _userRole = cached?['role']?.toString();
      });
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
        padding: EdgeInsets.fromLTRB(
          0,
          20,
          0,
          AppSafeInsets.sheetBottomPadding(ctx, base: 20),
        ),
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
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF1A56C4)),
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
        padding: EdgeInsets.fromLTRB(
          0,
          20,
          0,
          AppSafeInsets.sheetBottomPadding(ctx, base: 20),
        ),
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
              leading:
                  const Icon(Icons.photo_library, color: Color(0xFF1A56C4)),
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

      _showLoadingDialog('Mengunggah Foto...');
      setState(() {
        _avatarFile = XFile(croppedFile.path);
      });

      final result = await ProfileService.updateProfile(
        imagePath: croppedFile.path,
      );

      if (!mounted) return;
      _dismissLoadingDialog();
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(result.errorMessage ?? 'Gagal mengunggah foto profil')),
        );
        return;
      }

      await _loadProfile();
      _dismissLoadingDialog();
      if (!mounted) return;
      setState(() => _avatarFile = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto profil berhasil diperbarui')),
      );
    } catch (_) {
      if (!mounted) return;
      _dismissLoadingDialog();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi masalah saat memilih atau crop foto.'),
        ),
      );
    }
  }

  void _showFullScreenProfileImage() {
    final imageProvider = _getAvatarImage();
    if (imageProvider == null) {
      _pickImage();
      return;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Stack(
        children: [
          Center(
            child: InteractiveViewer(
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.all(20),
                child: Image(
                  image: imageProvider,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          Positioned(
            top: 40,
            right: 20,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Material(
                color: Colors.transparent,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _pickImage();
                  },
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text('Ubah Foto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                      side: const BorderSide(color: Colors.white),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  final List<Map<String, dynamic>> _subTabs = [
    {
      'label': 'Biodata',
      'icon': Icons.person,
      'color': const Color(0xFF1A56C4)
    },
    {
      'label': 'Medis',
      'icon': Icons.medical_services,
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
      body: _profileData == null && _isLoading
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              child: Column(
                children: [
                  _buildProfileHeader(),
                  _buildSubTabBar(),
                  const SizedBox(height: 20),
                  _buildSubTabContent(),
                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(context),
                  ),
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
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      extendBody: true,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: FabNotchedBottomBar(
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
            const SizedBox(width: 56),
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
    );
  }

  void _showLoadingDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.3),
      builder: (ctx) => PopScope(
        canPop: false,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A56C4)),
                ),
                const SizedBox(height: 20),
                Text(message, style: Theme.of(ctx).textTheme.titleSmall),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _dismissLoadingDialog() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Widget _buildProfileHeader() {
    final name = parseNullableDisplayName(_profileData?.fullName) ??
        parseNullableDisplayName(_cachedUser?['full_name']) ??
        '-';
    final positionVal = parseNullableDisplayName(_profileData?.position) ??
        parseNullableDisplayName(_cachedUser?['position']);
    final jabatanVal = parseNullableDisplayName(_profileData?.jabatan) ??
        parseNullableDisplayName(_cachedUser?['jabatan']);
    final position =
        (jabatanVal != null && positionVal != null && jabatanVal != positionVal)
            ? '$jabatanVal • $positionVal'
            : (jabatanVal ?? positionVal ?? '-');
    final department = parseNullableDisplayName(_profileData?.department) ??
        parseNullableDisplayName(_cachedUser?['department']) ??
        '-';
    final employeeId = parseNullableDisplayName(_profileData?.employeeId) ??
        parseNullableDisplayName(_cachedUser?['employee_id']) ??
        '-';
    final company = formatCompanyAffiliation(
      tipeAfiliasi: _profileData?.tipeAfiliasi ?? _cachedUser?['tipe_afiliasi'],
      ownerCompany: _profileData?.company ?? _cachedUser?['company'],
      contractorCompany: _profileData?.perusahaanKontraktor ??
          _cachedUser?['perusahaan_kontraktor'],
      subContractorCompany:
          _profileData?.subKontraktor ?? _cachedUser?['sub_kontraktor'],
      ownerCompanyCodeLookup: _ownerCodeByName,
      companyCodeLookup: _companyCodeLookup,
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                      _showLoadingDialog('Memuat Profil...');
                      _loadProfile();
                    },
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
          Stack(
            children: [
              GestureDetector(
                onTap: _showFullScreenProfileImage,
                child: CircleAvatar(
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
          Text(employeeId,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text('$position • $department',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: Colors.grey.shade600, fontSize: 13, height: 1.3)),
          ),
          const SizedBox(height: 4),
          Text(company,
              textAlign: TextAlign.center,
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

    final fromCacheProfilePhoto = normalizeStorageUrl(
        parseNullableDisplayName(_cachedUser?['profile_photo']));
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
              width: 72,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected ? tab['color'] : Colors.grey.shade200,
                  width: isSelected ? 1.4 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab['icon'],
                      color: isSelected ? tab['color'] : Colors.grey.shade400,
                      size: 24),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(tab['label'],
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: isSelected
                                ? tab['color']
                                : Colors.grey.shade600,
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal)),
                  ),
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
        return _BiodataContent(
          data: _profileData,
          ownerCompanyCodeLookup: _ownerCodeByName,
        );
      case 1:
        return _MedicalContent(medicals: _profileData?.medicals ?? []);
      case 2:
        return _LicenseContent(
          licenses: _profileData?.licenses ?? [],
          onAdd: _showAddLicenseForm,
          onEdit: (license) {
            _showAddLicenseForm(editLicense: license);
          },
          onDelete: (license) {
            _showDeleteLicenseConfirm(license);
          },
        );
      case 3:
        return _ViolationContent(violations: _profileData?.violations ?? []);
      case 4:
        return _CertificationContent(
          certifications: _profileData?.certifications ?? [],
          onAdd: _showAddCertificationForm,
          onEdit: (cert) {
            _showAddCertificationForm(editCert: cert);
          },
          onDelete: (cert) {
            _showDeleteCertificationConfirm(cert);
          },
        );
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
    final jobCtrl = TextEditingController(text: _profileData?.jabatan);
    final posCtrl = TextEditingController(text: _profileData?.position);
    final addressCtrl = TextEditingController(text: _profileData?.address);
    final phoneFocusNode = FocusNode();
    final formKey = GlobalKey<FormState>();
    XFile? localImageFile;
    final existingProfilePhoto =
        parseNullableDisplayName(_resolveProfilePhoto());
    final emailRegex = RegExp(r'^[\w\-.]+@([\w-]+\.)+[\w-]{2,4}$');
    String localTipeAfiliasi = _profileData?.tipeAfiliasi ?? 'Owner';
    if (localTipeAfiliasi == 'Sub-Kontraktor') {
      localTipeAfiliasi = 'Sub-Kont.';
    }
    String? localSelectedPerusahaan = _profileData?.company;
    String? localSelectedPerusahaanKontraktor =
        _profileData?.perusahaanKontraktor;
    String? localSelectedSubKontraktor = _profileData?.subKontraktor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFFF5F5F5),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            bottom: AppSafeInsets.keyboardOrSystemBottom(modalContext),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        phoneFocusNode.dispose();
                        Navigator.pop(sheetContext);
                      },
                    ),
                    const Expanded(
                      child: Text(
                        'Edit Profil',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
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
                                  ? Icon(Icons.person,
                                      size: 50, color: Colors.grey.shade400)
                                  : null,
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: GestureDetector(
                                onTap: () async {
                                  final picked = await _pickImageForForm();
                                  if (picked != null) {
                                    setModalState(
                                        () => localImageFile = picked);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A56C4),
                                    shape: BoxShape.circle,
                                    border: Border.fromBorderSide(BorderSide(
                                        color: Colors.white, width: 2)),
                                  ),
                                  child: const Icon(Icons.camera_alt,
                                      color: Colors.white, size: 16),
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
                              _buildSheetField('Employee Id', nikCtrl,
                                  enabled: false),
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
                              _buildPhoneField(phoneCtrl, phoneFocusNode),
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
                                enabled: _userRole == 'admin' ||
                                    _userRole == 'superadmin',
                                readOnly: _userRole == 'admin' ||
                                    _userRole == 'superadmin',
                                onTap: _userRole == 'admin' ||
                                        _userRole == 'superadmin'
                                    ? () => _showDepartmentPicker(
                                        modalContext, deptCtrl, setModalState)
                                    : null,
                                maxLength: 25,
                                suffixIcon: _userRole == 'admin' ||
                                        _userRole == 'superadmin'
                                    ? Icons.arrow_drop_down
                                    : null,
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
                                'Posisi',
                                posCtrl,
                                enabled: false,
                                maxLength: 25,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Posisi wajib diisi';
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
                              const SizedBox(height: 16),
                              const Text(
                                'Tipe Afiliasi *',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 8),
                              _buildAfiliasiButtons(localTipeAfiliasi, (val) {
                                setModalState(() {
                                  localTipeAfiliasi = val;
                                  if (val == 'Owner') {
                                    localSelectedPerusahaanKontraktor = null;
                                    localSelectedSubKontraktor = null;
                                  } else if (val == 'Kontraktor') {
                                    localSelectedSubKontraktor = null;
                                  }
                                });
                              }),
                              const SizedBox(height: 16),
                              _buildDropdownField(
                                'Perusahaan Owner',
                                localSelectedPerusahaan,
                                _ownerList,
                                (v) => setModalState(
                                    () => localSelectedPerusahaan = v),
                                required: true,
                              ),
                              if (localTipeAfiliasi == 'Kontraktor' ||
                                  localTipeAfiliasi == 'Sub-Kont.') ...[
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  'Perusahaan Kontraktor',
                                  localSelectedPerusahaanKontraktor,
                                  _kontraktorList,
                                  (v) => setModalState(() =>
                                      localSelectedPerusahaanKontraktor = v),
                                  required: true,
                                ),
                              ],
                              if (localTipeAfiliasi == 'Sub-Kont.') ...[
                                const SizedBox(height: 16),
                                _buildDropdownField(
                                  'Sub-Kontraktor',
                                  localSelectedSubKontraktor,
                                  _subkontraktorList,
                                  (v) => setModalState(
                                      () => localSelectedSubKontraktor = v),
                                  required: true,
                                ),
                              ],
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

                            phoneFocusNode.dispose();
                            Navigator.pop(sheetContext);
                            _showLoadingDialog('Menyimpan Profil...');

                            final result = await ProfileService.updateProfile(
                              fullName: nameCtrl.text.trim(),
                              personalEmail: emailCtrl.text.trim(),
                              workEmail: workEmailCtrl.text.trim(),
                              phoneNumber: '+62${phoneCtrl.text.trim()}',
                              department: deptCtrl.text.trim(),
                              position: posCtrl.text.trim(),
                              jabatan: jobCtrl.text.trim(),
                              address: addressCtrl.text.trim(),
                              tipeAfiliasi: localTipeAfiliasi == 'Sub-Kont.'
                                  ? 'Sub-Kontraktor'
                                  : localTipeAfiliasi,
                              company: localSelectedPerusahaan,
                              perusahaanKontraktor:
                                  localSelectedPerusahaanKontraktor ?? '',
                              subKontraktor: localSelectedSubKontraktor ?? '',
                              imagePath: localImageFile?.path,
                            );

                            if (!mounted) return;
                            if (result.success) {
                              await _loadProfile();
                              _dismissLoadingDialog();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content:
                                        Text('Profil berhasil diperbarui')),
                              );
                            } else {
                              _dismissLoadingDialog();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(result.errorMessage ??
                                        'Gagal memperbarui')),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A56C4),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('SIMPAN PERUBAHAN',
                              style: TextStyle(fontWeight: FontWeight.bold)),
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
      bool readOnly = false,
      TextInputType? keyboardType,
      int maxLines = 1,
      int? maxLength,
      IconData? suffixIcon,
      String? Function(String?)? validator,
      bool liveValidate = false,
      VoidCallback? onTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          maxLines: maxLines,
          maxLength: maxLength,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          validator: validator,
          style: const TextStyle(fontSize: 14),
          onChanged: liveValidate
              ? (v) {
                  Form.of(context).validate();
                }
              : null,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey.shade100,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade300)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFF1A56C4))),
            disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: Colors.grey.shade200)),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(
      TextEditingController controller, FocusNode focusNode) {
    return FormField<String>(
      initialValue: controller.text,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (v) {
        final value = (v ?? '').trim();
        if (value.isEmpty) {
          return 'Nomor telepon wajib diisi';
        }
        if (!RegExp(r'^8[0-9]{7,12}$').hasMatch(value)) {
          return 'Mulai dengan angka 8 (8-13 digit)';
        }
        return null;
      },
      builder: (FormFieldState<String> state) {
        bool hasError = state.hasError;
        Color borderColor = hasError
            ? Colors.red
            : (focusNode.hasFocus
                ? const Color(0xFF1A56C4)
                : Colors.grey.shade300);
        Color prefixBg = hasError ? Colors.red.shade50 : Colors.grey.shade100;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Nomor Telepon',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.bold)),
                const SizedBox(width: 4),
                Text('(Mulai dengan angka 8)',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                        fontStyle: FontStyle.italic)),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: prefixBg,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(7),
                          bottomLeft: Radius.circular(7),
                        ),
                        border: Border(
                          right: BorderSide(color: borderColor, width: 1),
                        ),
                      ),
                      child: const Text('+62',
                          style:
                              TextStyle(color: Colors.black87, fontSize: 14)),
                    ),
                    Expanded(
                      child: TextFormField(
                        controller: controller,
                        focusNode: focusNode,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
                        maxLength: 13,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: '812xxxxxxxx',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 13),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          counterText: '',
                        ),
                        onChanged: (v) {
                          state.didChange(v);
                          state.validate();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 4),
                child: Text(
                  state.errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showDepartmentPicker(BuildContext context,
      TextEditingController controller, StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DepartmentPickerSheet(
        initialValue: controller.text,
        onSelected: (val) {
          setModalState(() {
            controller.text = val;
          });
        },
      ),
    );
  }

  Widget _buildAfiliasiButtons(
      String selectedType, Function(String) onSelected) {
    final types = ['Owner', 'Kontraktor', 'Sub-Kont.'];
    return Row(
      children: types.map((type) {
        final isSelected = selectedType == type;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => onSelected(type),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF1A56C4) : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1A56C4)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isSelected)
                      const Icon(Icons.check, color: Colors.white, size: 16),
                    if (isSelected) const SizedBox(width: 4),
                    Text(
                      type,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDropdownField(String label, String? value, List<String> items,
      Function(String?) onChanged,
      {bool required = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label + (required ? ' *' : ''),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: items.contains(value) ? value : null,
          validator: required
              ? (v) {
                  if (v == null || v.trim().isEmpty) {
                    return '$label wajib dipilih';
                  }
                  return null;
                }
              : null,
          decoration: InputDecoration(
            fillColor: Colors.grey.shade50,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items
              .map((e) => DropdownMenuItem(
                    value: e,
                    child: Text(e, style: const TextStyle(fontSize: 13)),
                  ))
              .toList(),
          onChanged: onChanged,
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
    final allergiesCtrl = TextEditingController(text: latest?.allergies);
    final lastMedicationCtrl =
        TextEditingController(text: latest?.lastMedication);
    final currentMedicationCtrl =
        TextEditingController(text: latest?.currentMedication);
    final currentIllnessCtrl =
        TextEditingController(text: latest?.currentIllness);
    String systolic = '';
    String diastolic = '';
    if (latest?.bloodPressure != null && latest!.bloodPressure!.contains('/')) {
      final parts = latest.bloodPressure!.split('/');
      systolic = parts[0].trim();
      diastolic = parts.length > 1 ? parts[1].trim() : '';
    }
    final systolicCtrl = TextEditingController(text: systolic);
    final diastolicCtrl = TextEditingController(text: diastolic);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: AppSafeInsets.sheetBottomPadding(modalContext),
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
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close)),
                  ],
                ),
                const SizedBox(height: 20),
                _buildFieldLabel('Golongan Darah'),
                InkWell(
                  onTap: () => _showBloodTypePicker(
                      modalContext, bloodTypeCtrl, setModalState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Text(
                          bloodTypeCtrl.text.isEmpty
                              ? 'Pilih Golongan Darah'
                              : bloodTypeCtrl.text,
                          style: TextStyle(
                            color: bloodTypeCtrl.text.isEmpty
                                ? Colors.grey.shade400
                                : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Tinggi Badan (cm)'),
                InkWell(
                  onTap: () => _showHeightPicker(
                      modalContext, heightCtrl, setModalState),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        Text(
                          heightCtrl.text.isEmpty
                              ? 'Pilih Tinggi Badan'
                              : '${heightCtrl.text} cm',
                          style: TextStyle(
                            color: heightCtrl.text.isEmpty
                                ? Colors.grey.shade400
                                : Colors.black,
                            fontSize: 14,
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.arrow_drop_down,
                            color: Colors.grey.shade400),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Berat Badan (kg)'),
                TextField(
                  controller: weightCtrl,
                  keyboardType: TextInputType.number,
                  decoration: _buildInputDecoration('Contoh: 65'),
                ),
                const SizedBox(height: 16),
                _buildFieldLabel('Tekanan Darah (Sistolik / Diastolik)'),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: systolicCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('Sistolik (ex: 120)'),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('/',
                          style: TextStyle(fontSize: 20, color: Colors.grey)),
                    ),
                    Expanded(
                      child: TextField(
                        controller: diastolicCtrl,
                        keyboardType: TextInputType.number,
                        decoration: _buildInputDecoration('Diastolik (ex: 80)'),
                      ),
                    ),
                  ],
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
                            decoration:
                                _buildInputDecoration('Contoh: Paracetamol'),
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
                            decoration:
                                _buildInputDecoration('Contoh: Metformin'),
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
                  decoration:
                      _buildInputDecoration('Contoh: Diabetes, Hipertensi...'),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(sheetContext);
                      _showLoadingDialog('Menyimpan Data Medis...');

                      final result = await ProfileService.updateMedical(
                        id: latest?.id,
                        bloodType: bloodTypeCtrl.text,
                        height: heightCtrl.text,
                        weight: weightCtrl.text,
                        bloodPressure: systolicCtrl.text.isNotEmpty &&
                                diastolicCtrl.text.isNotEmpty
                            ? '${systolicCtrl.text}/${diastolicCtrl.text}'
                            : '',
                        allergies: allergiesCtrl.text,
                        lastMedication: lastMedicationCtrl.text,
                        currentMedication: currentMedicationCtrl.text,
                        currentIllness: currentIllnessCtrl.text,
                      );

                      if (!mounted) return;
                      if (result.success) {
                        await _loadProfile();
                        _dismissLoadingDialog();
                      } else {
                        _dismissLoadingDialog();
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(result.message)));
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

  void _showBloodTypePicker(BuildContext context, TextEditingController ctrl,
      StateSetter setModalState) {
    final types = ['A', 'B', 'AB', 'O'];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          AppSafeInsets.sheetBottomPadding(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Pilih Golongan Darah',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...types.map((type) => ListTile(
                  title: Text(type,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () {
                    setModalState(() => ctrl.text = type);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }

  void _showHeightPicker(BuildContext context, TextEditingController ctrl,
      StateSetter setModalState) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.6,
        padding: EdgeInsets.fromLTRB(
          0,
          20,
          0,
          AppSafeInsets.sheetBottomPadding(context, base: 20),
        ),
        child: Column(
          children: [
            const Text('Pilih Tinggi Badan (cm)',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: 251,
                itemBuilder: (context, index) {
                  final height = (index + 50).toString();
                  return ListTile(
                    title: Text('$height cm', textAlign: TextAlign.center),
                    onTap: () {
                      setModalState(() => ctrl.text = height);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddLicenseForm({UserLicense? editLicense}) {
    if (editLicense != null) {
      _licenseNameController.text = editLicense.name;
      _licenseNumberController.text = editLicense.licenseNumber;
      _licenseIssuerController.text = editLicense.issuer ?? '';
      _licenseObtainedAt = editLicense.obtainedAt != null
          ? DateTime.parse(editLicense.obtainedAt!)
          : null;
      _licenseSelectedDate = editLicense.expiredAt != null
          ? DateTime.parse(editLicense.expiredAt!)
          : null;
      _licenseImage = null;
    } else {
      _licenseNameController.clear();
      _licenseNumberController.clear();
      _licenseIssuerController.clear();
      _licenseObtainedAt = null;
      _licenseSelectedDate = null;
      _licenseImage = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: AppSafeInsets.sheetBottomPadding(modalContext),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                      editLicense != null
                          ? 'Edit Lisensi'
                          : 'Tambah Lisensi Baru',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Nama Lisensi'),
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
              _buildFieldLabel('Lembaga Penerbit'),
              TextField(
                controller: _licenseIssuerController,
                decoration:
                    _buildInputDecoration('Contoh: Polri, Kemnaker RI...'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Tanggal Diperoleh'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: modalContext,
                    initialDate: _licenseObtainedAt ?? DateTime.now(),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365 * 5)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setModalState(() => _licenseObtainedAt = picked);
                  }
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
                        _licenseObtainedAt == null
                            ? 'Pilih Tanggal'
                            : '${_licenseObtainedAt!.day}/${_licenseObtainedAt!.month}/${_licenseObtainedAt!.year}',
                        style: TextStyle(
                            color: _licenseObtainedAt == null
                                ? Colors.grey.shade500
                                : Colors.black),
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
                    context: modalContext,
                    initialDate: _licenseSelectedDate ?? DateTime.now(),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365 * 5)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setModalState(() => _licenseSelectedDate = picked);
                  }
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
                  if (picked != null) {
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

                    Navigator.pop(sheetContext);
                    _showLoadingDialog(editLicense != null
                        ? 'Memperbarui Lisensi...'
                        : 'Menyimpan Lisensi...');

                    final result = editLicense != null
                        ? await ProfileService.updateLicense(
                            id: editLicense.id.toString(),
                            name: _licenseNameController.text,
                            licenseNumber: _licenseNumberController.text,
                            issuer: _licenseIssuerController.text,
                            obtainedAt: _licenseObtainedAt != null
                                ? '${_licenseObtainedAt!.year}-${_licenseObtainedAt!.month.toString().padLeft(2, '0')}-${_licenseObtainedAt!.day.toString().padLeft(2, '0')}'
                                : null,
                            expiredAt: _licenseSelectedDate != null
                                ? '${_licenseSelectedDate!.year}-${_licenseSelectedDate!.month.toString().padLeft(2, '0')}-${_licenseSelectedDate!.day.toString().padLeft(2, '0')}'
                                : null,
                            imageFile: _licenseImage,
                          )
                        : await ProfileService.addLicense(
                            name: _licenseNameController.text,
                            licenseNumber: _licenseNumberController.text,
                            issuer: _licenseIssuerController.text,
                            obtainedAt: _licenseObtainedAt != null
                                ? '${_licenseObtainedAt!.year}-${_licenseObtainedAt!.month.toString().padLeft(2, '0')}-${_licenseObtainedAt!.day.toString().padLeft(2, '0')}'
                                : null,
                            expiredAt: _licenseSelectedDate != null
                                ? '${_licenseSelectedDate!.year}-${_licenseSelectedDate!.month.toString().padLeft(2, '0')}-${_licenseSelectedDate!.day.toString().padLeft(2, '0')}'
                                : null,
                            imageFile: _licenseImage,
                          );

                    if (!mounted) return;
                    _dismissLoadingDialog();
                    if (result.success) {
                      _licenseNameController.clear();
                      _licenseNumberController.clear();
                      _licenseIssuerController.clear();
                      _licenseObtainedAt = null;
                      _licenseSelectedDate = null;
                      _licenseImage = null;
                      await _loadProfile();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                      editLicense != null
                          ? 'Simpan Perubahan'
                          : 'Simpan Lisensi',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCertificationForm({UserCertification? editCert}) {
    if (editCert != null) {
      _certNameController.text = editCert.name;
      _certNumberController.text = editCert.certificationNumber ?? '';
      _certIssuerController.text = editCert.issuer;
      _certObtainedAt = editCert.obtainedAt != null
          ? DateTime.parse(editCert.obtainedAt!)
          : null;
      _certExpiredAt = editCert.expiredAt != null
          ? DateTime.parse(editCert.expiredAt!)
          : null;
      _certImage = null;
    } else {
      _certNameController.clear();
      _certNumberController.clear();
      _certIssuerController.clear();
      _certObtainedAt = null;
      _certExpiredAt = null;
      _certImage = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: AppSafeInsets.sheetBottomPadding(modalContext),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                      editCert != null
                          ? 'Edit Sertifikat'
                          : 'Tambah Sertifikat Baru',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                      onPressed: () => Navigator.pop(sheetContext),
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
              _buildFieldLabel('Nomor Sertifikat'),
              TextField(
                controller: _certNumberController,
                decoration: _buildInputDecoration('Contoh: SERT-2024-001234'),
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
                    context: modalContext,
                    initialDate: _certObtainedAt ?? DateTime.now(),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365 * 10)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setModalState(() => _certObtainedAt = picked);
                  }
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
                        _certObtainedAt == null
                            ? 'Pilih Tanggal'
                            : '${_certObtainedAt!.day}/${_certObtainedAt!.month}/${_certObtainedAt!.year}',
                        style: TextStyle(
                            color: _certObtainedAt == null
                                ? Colors.grey.shade500
                                : Colors.black),
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
                    context: modalContext,
                    initialDate: _certExpiredAt ?? DateTime.now(),
                    firstDate:
                        DateTime.now().subtract(const Duration(days: 365 * 10)),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) {
                    setModalState(() => _certExpiredAt = picked);
                  }
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
                        _certExpiredAt == null
                            ? 'Pilih Tanggal'
                            : '${_certExpiredAt!.day}/${_certExpiredAt!.month}/${_certExpiredAt!.year}',
                        style: TextStyle(
                            color: _certExpiredAt == null
                                ? Colors.grey.shade500
                                : Colors.black),
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

                    Navigator.pop(sheetContext);
                    _showLoadingDialog(editCert != null
                        ? 'Memperbarui Sertifikat...'
                        : 'Menyimpan Sertifikat...');

                    final result = editCert != null
                        ? await ProfileService.updateCertification(
                            id: editCert.id.toString(),
                            name: _certNameController.text,
                            certificationNumber: _certNumberController.text,
                            issuer: _certIssuerController.text,
                            obtainedAt: _certObtainedAt != null
                                ? '${_certObtainedAt!.year}-${_certObtainedAt!.month.toString().padLeft(2, '0')}-${_certObtainedAt!.day.toString().padLeft(2, '0')}'
                                : null,
                            expiredAt: _certExpiredAt != null
                                ? '${_certExpiredAt!.year}-${_certExpiredAt!.month.toString().padLeft(2, '0')}-${_certExpiredAt!.day.toString().padLeft(2, '0')}'
                                : null,
                            imageFile: _certImage,
                          )
                        : await ProfileService.addCertification(
                            name: _certNameController.text,
                            certificationNumber: _certNumberController.text,
                            issuer: _certIssuerController.text,
                            obtainedAt: _certObtainedAt != null
                                ? '${_certObtainedAt!.year}-${_certObtainedAt!.month.toString().padLeft(2, '0')}-${_certObtainedAt!.day.toString().padLeft(2, '0')}'
                                : null,
                            expiredAt: _certExpiredAt != null
                                ? '${_certExpiredAt!.year}-${_certExpiredAt!.month.toString().padLeft(2, '0')}-${_certExpiredAt!.day.toString().padLeft(2, '0')}'
                                : null,
                            imageFile: _certImage,
                          );

                    if (!mounted) return;
                    _dismissLoadingDialog();
                    if (result.success) {
                      _certNameController.clear();
                      _certNumberController.clear();
                      _certIssuerController.clear();
                      _certObtainedAt = null;
                      _certExpiredAt = null;
                      _certImage = null;
                      await _loadProfile();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(result.message)));
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: Text(
                      editCert != null
                          ? 'Simpan Perubahan'
                          : 'Simpan Sertifikat',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteLicenseConfirm(UserLicense license) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Lisensi',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Apakah Anda yakin ingin menghapus lisensi "${license.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _showLoadingDialog('Menghapus Lisensi...');
              final result =
                  await ProfileService.deleteLicense(license.id.toString());
              if (!mounted) return;
              _dismissLoadingDialog();
              if (result.success) {
                await _loadProfile();
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lisensi berhasil dihapus')),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
              }
            },
            child: const Text('Hapus',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showDeleteCertificationConfirm(UserCertification certification) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Hapus Sertifikat',
            style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(
            'Apakah Anda yakin ingin menghapus sertifikat "${certification.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Batal', style: TextStyle(color: Colors.grey.shade600)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              _showLoadingDialog('Menghapus Sertifikat...');
              final result = await ProfileService.deleteCertification(
                  certification.id.toString());
              if (!mounted) return;
              _dismissLoadingDialog();
              if (result.success) {
                await _loadProfile();
                if (!mounted) return;
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sertifikat berhasil dihapus')),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(result.message)),
                );
              }
            },
            child: const Text('Hapus',
                style:
                    TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
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
  final Map<String, String> ownerCompanyCodeLookup;
  const _BiodataContent({
    this.data,
    this.ownerCompanyCodeLookup = const {},
  });

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
          _buildTitle('PERSONAL INFORMATION '),
          _buildCard([
            _buildRow(context, 'Employee ID', data?.employeeId ?? '-',
                onTap: () =>
                    _copyToClipboard(context, 'Employee ID', data?.employeeId)),
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
                  waNumber = '628${waNumber.substring(2)}';
                }
                _launchUrl('https://wa.me/$waNumber');
              }
            }),
            _buildRow(context, 'Alamat', data?.address ?? '-',
                onTap: () =>
                    _copyToClipboard(context, 'Alamat', data?.address)),
          ]),
          const SizedBox(height: 24),
          _buildTitle('EMPLOYEE INFORMATION'),
          _buildCard([
            _buildRow(context, 'Tipe Afiliasi', data?.tipeAfiliasi ?? '-'),
            _buildRow(context, 'Perusahaan Owner', data?.company ?? '-'),
            if (_displayValue(data?.tipeAfiliasi).toLowerCase() ==
                    'kontraktor' ||
                _displayValue(data?.tipeAfiliasi).toLowerCase() ==
                    'sub-kontraktor' ||
                _displayValue(data?.tipeAfiliasi).toLowerCase() == 'sub-kont.')
              _buildRow(context, 'Perusahaan Kontraktor',
                  data?.perusahaanKontraktor ?? '-'),
            if (_displayValue(data?.tipeAfiliasi).toLowerCase() ==
                    'sub-kontraktor' ||
                _displayValue(data?.tipeAfiliasi).toLowerCase() == 'sub-kont.')
              _buildRow(context, 'Sub-Kontraktor', data?.subKontraktor ?? '-'),
            _buildRow(context, 'Departemen', data?.department ?? '-'),
            _buildRow(context, 'Jabatan', data?.jabatan ?? '-'),
            _buildRow(context, 'Posisi', data?.position ?? '-'),
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
  final Function(UserLicense) onEdit;
  final Function(UserLicense) onDelete;

  const _LicenseContent({
    required this.licenses,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...licenses.map((l) {
            final isAktif = l.isActive;
            final approvalStatus = l.approvalStatus.toLowerCase();
            final approvalStyle = approvalStatusStyle(approvalStatus);
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _LicenseDetailPage(
                      license: l,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isAktif
                            ? Colors.grey.shade200
                            : Colors.red.shade100),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (l.fileUrl != null && l.fileUrl!.isNotEmpty)
                          ? Image.network(
                              l.fileUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.badge_outlined,
                                      color: Color(0xFF1E88E5), size: 24),
                            )
                          : const Icon(Icons.badge_outlined,
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
                          if (l.issuer != null && l.issuer!.isNotEmpty)
                            Text('Penerbit: ${l.issuer}',
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
                          if (approvalStatus == 'rejected' &&
                              (l.rejectionReason ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title:
                                        const Text('Alasan Penolakan Lisensi'),
                                    content: Text(l.rejectionReason!.trim()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Tutup'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: const Text('Lihat Alasan'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: approvalStyle.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: approvalStyle.fg.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            approvalStyle.label,
                            style: TextStyle(
                              color: approvalStyle.fg,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        if (!isAktif) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Color(0xFFD32F2F).withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Expired',
                              style: TextStyle(
                                color: Color(0xFFD32F2F),
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
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
  final Function(UserCertification) onEdit;
  final Function(UserCertification) onDelete;

  const _CertificationContent({
    required this.certifications,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...certifications.map((c) {
            final isAktif = c.isActive;
            final approvalStatus = c.approvalStatus.toLowerCase();
            final approvalStyle = approvalStatusStyle(approvalStatus);
            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _CertificationDetailPage(
                      certification: c,
                      onEdit: onEdit,
                      onDelete: onDelete,
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (c.fileUrl != null && c.fileUrl!.isNotEmpty)
                          ? Image.network(
                              c.fileUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.workspace_premium_outlined,
                                      color: Color(0xFF6A1B9A), size: 24),
                            )
                          : const Icon(Icons.workspace_premium_outlined,
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
                          if (c.certificationNumber != null &&
                              c.certificationNumber!.isNotEmpty)
                            Text('No. ${c.certificationNumber}',
                                style: TextStyle(
                                    color: Colors.grey.shade500, fontSize: 13)),
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
                          if (approvalStatus == 'rejected' &&
                              (c.rejectionReason ?? '').trim().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            TextButton.icon(
                              onPressed: () {
                                showDialog<void>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text(
                                        'Alasan Penolakan Sertifikat'),
                                    content: Text(c.rejectionReason!.trim()),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Tutup'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: const Text('Lihat Alasan'),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: approvalStyle.bg,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: approvalStyle.fg.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            approvalStyle.label,
                            style: TextStyle(
                              color: approvalStyle.fg,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                        if (!isAktif) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3E0),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                  color: Color(0xFFEF6C00).withValues(alpha: 0.3)),
                            ),
                            child: const Text(
                              'Renew',
                              style: TextStyle(
                                color: Color(0xFFEF6C00),
                                fontWeight: FontWeight.bold,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
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

            return InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _ViolationDetailPage(violation: v),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: isAktif
                            ? Colors.red.shade100
                            : Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4))
                    ]),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isAktif
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: (v.fileUrl != null && v.fileUrl!.isNotEmpty)
                          ? Image.network(
                              v.fileUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(
                                Icons.warning_amber_rounded,
                                color: isAktif
                                    ? const Color(0xFFD32F2F)
                                    : const Color(0xFF757575),
                                size: 24,
                              ),
                            )
                          : Icon(
                              Icons.warning_amber_rounded,
                              color: isAktif
                                  ? const Color(0xFFD32F2F)
                                  : const Color(0xFF757575),
                              size: 24,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            v.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            v.location ?? '-',
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tanggal: ${v.dateOfViolation ?? "-"}',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                          if (v.expiredAt != null &&
                              v.expiredAt!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Berlaku s/d: ${v.expiredAt}',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                          if (v.sanction != null && v.sanction!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Sanksi: ${v.sanction}',
                              style: TextStyle(
                                color: color,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(
                                color: color.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            v.status,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _LicenseDetailPage extends StatelessWidget {
  final UserLicense license;
  final Function(UserLicense) onEdit;
  final Function(UserLicense) onDelete;

  const _LicenseDetailPage({
    required this.license,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final approvalStyle = approvalStatusStyle(license.approvalStatus);
    final activeColor =
        license.isActive ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F);
    final activeBg =
        license.isActive ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

    final hasImage = license.fileUrl != null && license.fileUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text('Detail Lisensi',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: hasImage ? EdgeInsets.zero : AppSafeInsets.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Image.network(
                      license.fileUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Row(
                      children: [
                        _StatusPill(
                          label: approvalStyle.label,
                          foreground: approvalStyle.fg,
                          background: approvalStyle.bg,
                        ),
                        if (!license.isActive) ...[
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: 'Expired',
                            foreground: activeColor,
                            background: activeBg,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
            Padding(
              padding: hasImage
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                  : EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailHeader(
                    icon: Icons.badge_outlined,
                    iconColor: const Color(0xFF1E88E5),
                    iconBgColor: const Color(0xFFE3F2FD),
                    title: license.name,
                    subtitle: 'No. ${license.licenseNumber}',
                  ),
                  if (!hasImage) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: approvalStyle.label,
                          foreground: approvalStyle.fg,
                          background: approvalStyle.bg,
                        ),
                        if (!license.isActive)
                          _StatusPill(
                            label: 'Expired',
                            foreground: activeColor,
                            background: activeBg,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DetailCard(
                    children: [
                      _DetailInfoRow('Nama Lisensi', license.name),
                      _DetailInfoRow('Nomor Lisensi', license.licenseNumber),
                      _DetailInfoRow(
                          'Tanggal Diperoleh',
                          license.obtainedAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(license.obtainedAt!))
                              : '-'),
                      _DetailInfoRow(
                          'Berlaku Sampai',
                          license.expiredAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(license.expiredAt!))
                              : '-'),
                      _DetailInfoRow('Status', license.status),
                      _DetailInfoRow(
                          'Diajukan',
                          license.submittedAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(license.submittedAt!))
                              : '-'),
                      _DetailInfoRow(
                          'Direview',
                          license.reviewedAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(license.reviewedAt!))
                              : '-'),
                    ],
                  ),
                  if ((license.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _RejectionReasonCard(reason: license.rejectionReason!.trim()),
                  ],
                  const SizedBox(height: 24),
                  if (license.approvalStatus.toLowerCase() == 'rejected') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onEdit(license);
                        },
                        icon: const Icon(Icons.edit_note, color: Colors.white),
                        label: const Text(
                          'Edit & Pengajuan Ulang',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ] else if (!license.isActive) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                onDelete(license);
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text(
                                'Hapus Lisensi',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                onEdit(license);
                              },
                              icon: const Icon(Icons.history, color: Colors.white),
                              label: const Text(
                                'Perpanjang',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onEdit(license);
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit Lisensi',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CertificationDetailPage extends StatelessWidget {
  final UserCertification certification;
  final Function(UserCertification) onEdit;
  final Function(UserCertification) onDelete;

  const _CertificationDetailPage({
    required this.certification,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final approvalStyle = approvalStatusStyle(certification.approvalStatus);
    final activeColor = certification.isActive
        ? const Color(0xFF2E7D32)
        : const Color(0xFFEF6C00);
    final activeBg = certification.isActive
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFF3E0);

    final hasImage = certification.fileUrl != null && certification.fileUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text('Detail Sertifikat',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: hasImage ? EdgeInsets.zero : AppSafeInsets.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Image.network(
                      certification.fileUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Row(
                      children: [
                        _StatusPill(
                          label: approvalStyle.label,
                          foreground: approvalStyle.fg,
                          background: approvalStyle.bg,
                        ),
                        if (!certification.isActive) ...[
                          const SizedBox(width: 8),
                          _StatusPill(
                            label: 'Renew',
                            foreground: activeColor,
                            background: activeBg,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
            Padding(
              padding: hasImage
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                  : EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailHeader(
                    icon: Icons.workspace_premium_outlined,
                    iconColor: const Color(0xFF6A1B9A),
                    iconBgColor: const Color(0xFFF3E5F5),
                    title: certification.name,
                    subtitle: certification.issuer,
                  ),
                  if (!hasImage) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: approvalStyle.label,
                          foreground: approvalStyle.fg,
                          background: approvalStyle.bg,
                        ),
                        if (!certification.isActive)
                          _StatusPill(
                            label: 'Renew',
                            foreground: activeColor,
                            background: activeBg,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DetailCard(
                    children: [
                      _DetailInfoRow('Nama Sertifikat', certification.name),
                      _DetailInfoRow('Lembaga Penerbit', certification.issuer),
                      _DetailInfoRow(
                          'Tanggal Diperoleh',
                          certification.obtainedAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(certification.obtainedAt!))
                              : '-'),
                      _DetailInfoRow(
                          'Berlaku Sampai',
                          certification.expiredAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(certification.expiredAt!))
                              : '-'),
                      _DetailInfoRow('Status', certification.status),
                      _DetailInfoRow(
                          'Diajukan',
                          certification.submittedAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(certification.submittedAt!))
                              : '-'),
                      _DetailInfoRow(
                          'Direview',
                          certification.reviewedAt != null
                              ? DateFormat('dd MMM yyyy, HH:mm')
                                  .format(DateTime.parse(certification.reviewedAt!))
                              : '-'),
                    ],
                  ),
                  if ((certification.rejectionReason ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _RejectionReasonCard(
                        reason: certification.rejectionReason!.trim()),
                  ],
                  const SizedBox(height: 24),
                  if (certification.approvalStatus.toLowerCase() == 'rejected') ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onEdit(certification);
                        },
                        icon: const Icon(Icons.edit_note, color: Colors.white),
                        label: const Text(
                          'Edit & Pengajuan Ulang',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ] else if (!certification.isActive) ...[
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                onDelete(certification);
                              },
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              label: const Text(
                                'Hapus Sertifikat',
                                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: Colors.red),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 50,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                onEdit(certification);
                              },
                              icon: const Icon(Icons.history, color: Colors.white),
                              label: const Text(
                                'Perpanjang',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1E88E5),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          onEdit(certification);
                        },
                        icon: const Icon(Icons.edit, color: Colors.white),
                        label: const Text(
                          'Edit Sertifikat',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViolationDetailPage extends StatelessWidget {
  final UserViolation violation;
  const _ViolationDetailPage({required this.violation});

  @override
  Widget build(BuildContext context) {
    final isAktif = violation.status.toLowerCase() == 'aktif';
    final color = isAktif ? Colors.red.shade700 : Colors.grey.shade700;
    final bgColor = isAktif ? Colors.red.shade50 : Colors.grey.shade100;

    final hasImage = violation.fileUrl != null && violation.fileUrl!.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        title: const Text('Detail Pelanggaran',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: hasImage ? EdgeInsets.zero : AppSafeInsets.pagePadding(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (hasImage) ...[
              Stack(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 220,
                    child: Image.network(
                      violation.fileUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey.shade200,
                        child: const Icon(Icons.broken_image, size: 48, color: Colors.grey),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            Colors.black.withValues(alpha: 0.6),
                          ],
                          stops: const [0.6, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 16,
                    child: Row(
                      children: [
                        _StatusPill(
                          label: violation.status,
                          foreground: color,
                          background: bgColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            Padding(
              padding: hasImage
                  ? const EdgeInsets.symmetric(horizontal: 16, vertical: 16)
                  : EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DetailHeader(
                    icon: Icons.warning_amber_rounded,
                    iconColor: color,
                    iconBgColor: bgColor,
                    title: violation.title,
                    subtitle: violation.location ?? '-',
                  ),
                  if (!hasImage) ...[
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusPill(
                          label: violation.status,
                          foreground: color,
                          background: bgColor,
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  _DetailCard(
                    children: [
                      _DetailInfoRow('Pelanggaran', violation.title),
                      _DetailInfoRow('Deskripsi', (violation.description != null && violation.description!.isNotEmpty) ? violation.description! : '-'),
                      _DetailInfoRow('Lokasi', violation.location ?? '-'),
                      _DetailInfoRow('Tanggal', violation.dateOfViolation ?? '-'),
                      _DetailInfoRow('Berlaku Sampai', violation.expiredAt ?? '-'),
                      _DetailInfoRow('Status', violation.status),
                      _DetailInfoRow('Sanksi', violation.sanction ?? '-'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;

  const _DetailHeader({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 17)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final List<Widget> children;
  const _DetailCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: children
            .asMap()
            .entries
            .map((entry) => Column(
                  children: [
                    entry.value,
                    if (entry.key < children.length - 1)
                      Divider(
                        height: 1,
                        color: Colors.grey.shade100,
                        indent: 16,
                        endIndent: 16,
                      ),
                  ],
                ))
            .toList(),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailInfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;

  const _StatusPill({
    required this.label,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _RejectionReasonCard extends StatelessWidget {
  final String reason;
  const _RejectionReasonCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFD32F2F), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reason,
              style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
            ),
          ),
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
      margin: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        AppSafeInsets.sheetBottomPadding(context, base: 32),
      ),
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

class _DepartmentPickerSheet extends StatefulWidget {
  final String initialValue;
  final Function(String) onSelected;

  const _DepartmentPickerSheet({
    required this.initialValue,
    required this.onSelected,
  });

  @override
  State<_DepartmentPickerSheet> createState() => _DepartmentPickerSheetState();
}

class _DepartmentPickerSheetState extends State<_DepartmentPickerSheet> {
  List<DepartmentData> _allDepartments = [];
  List<DepartmentData> _filteredDepartments = [];
  String? _selectedValue;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.initialValue;
    _fetchDepartments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDepartments() async {
    try {
      final deps = await DepartmentService.getDepartments();
      if (!mounted) return;
      setState(() {
        _allDepartments = deps;
        _filteredDepartments = deps;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterDepartments(String query) {
    setState(() {
      _filteredDepartments = _allDepartments
          .where((d) => d.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 16, 16),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Pilih Departemen',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A56C4),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              onChanged: _filterDepartments,
              decoration: InputDecoration(
                hintText: 'Cari...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                prefixIcon: Icon(Icons.search, color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFF0F4F8),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'DAFTAR DEPARTEMEN',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: _filteredDepartments.length,
                    itemBuilder: (context, index) {
                      final dep = _filteredDepartments[index];
                      final isSelected = _selectedValue == dep.name;
                      return InkWell(
                        onTap: () => setState(() => _selectedValue = dep.name),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade100),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  dep.name,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              Icon(
                                isSelected
                                    ? Icons.radio_button_checked
                                    : Icons.radio_button_off,
                                color: isSelected
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFF1A56C4)
                                        .withValues(alpha: 0.5),
                                size: 24,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              AppSafeInsets.sheetBottomPadding(context),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _selectedValue == null
                    ? null
                    : () {
                        widget.onSelected(_selectedValue!);
                        Navigator.pop(context);
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56C4),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Simpan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

