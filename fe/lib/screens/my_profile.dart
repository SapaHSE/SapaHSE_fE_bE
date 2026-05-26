import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:math' show Random;
import 'dart:io';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:sapahse/models/profile_model.dart';
import 'package:sapahse/models/department_model.dart';
import 'package:sapahse/services/company_service.dart';
import 'package:sapahse/services/api_service.dart';
import 'package:sapahse/services/background_sync_service.dart';
import 'package:sapahse/services/cloud_save_service.dart';
import 'package:sapahse/services/department_service.dart';
import 'package:sapahse/services/profile_service.dart';
import 'package:sapahse/services/storage_service.dart';
import 'package:sapahse/utils/approval_status_ui.dart';
import 'package:sapahse/utils/value_parser.dart';
import 'package:sapahse/utils/url_helper.dart';
import 'package:sapahse/main.dart';
import 'package:sapahse/widgets/app_safe_insets.dart';
import 'package:sapahse/widgets/fab_notched_bottom_bar.dart';
import 'package:sapahse/widgets/report_style_detail_widgets.dart';

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
  final FocusNode _editProfilePhoneFocusNode = FocusNode();

  // Persistent State for License Form
  final TextEditingController _licenseNameController = TextEditingController();
  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _licenseIssuerController =
      TextEditingController();
  final TextEditingController _licenseVehicleEquipmentController =
      TextEditingController();
  final TextEditingController _licenseCategoryController =
      TextEditingController();
  String _licenseType = 'general';
  String? _licenseSimType;
  String? _licenseSimIndonesiaType;
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
    _licenseVehicleEquipmentController.dispose();
    _licenseCategoryController.dispose();
    _certNameController.dispose();
    _certNumberController.dispose();
    _certIssuerController.dispose();
    _editProfilePhoneFocusNode.dispose();
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
      });
    }

    final cachedProfile = await ProfileService.getProfile(
      cachePolicy: ApiCachePolicy.cacheOnly,
    );
    if (mounted && cachedProfile.success) {
      setState(() {
        _profileData = cachedProfile.data;
        _isLoading = false;
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

  Future<void> _onRefresh() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });
    await Future.wait([
      _loadProfile(),
      _fetchCompanyData(),
    ]);
  }

  Future<bool> _handleMinePermitAction() async {
    final licenses = _profileData?.licenses ?? [];
    final state = _MinePermitState.resolve(licenses);

    if (state.key == _MinePermitStateKey.pending ||
        state.key == _MinePermitStateKey.pendingChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Pengajuan Mine Permit masih menunggu approval.'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        ),
      );
      return false;
    }

    if (state.key == _MinePermitStateKey.approvedLocked) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Perpanjangan Belum Tersedia'),
          content: const Text(UserLicense.renewalBlockedMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return false;
    }

    _showLoadingDialog('Mengajukan Mine Permit...');
    final result = await ProfileService.requestMinePermit();
    if (!mounted) return false;
    _dismissLoadingDialog();

    if (result.success) {
      await _loadProfile();
      if (!mounted) return true;
      _showSuccessPopup(context, result.message);
      return true;
    }

    final msg = result.message;
    if (msg.contains('belum bisa dilakukan') || msg.contains('masih berlaku')) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Perpanjangan Belum Tersedia'),
          content: Text(msg),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup'),
            ),
          ],
        ),
      );
      return false;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      ),
    );
    return false;
  }

  void _showMinePermitDetail(_MinePermitState state) {
    Navigator.push(
      context,
      _FadePageRoute(
        builder: (_) => _MinePermitDetailPage(
          state: state,
          profileData: _profileData,
          cachedUser: _cachedUser,
          onAction: _handleMinePermitAction,
        ),
      ),
    );
  }

  String _formatDateForPayload(DateTime? value) {
    if (value == null) return '';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  String _buildDraftId(String prefix) {
    final now = DateTime.now().millisecondsSinceEpoch;
    return '${prefix}_${now}_${Random().nextInt(9999)}';
  }

  bool _isNoInternetMessage(String message) {
    final normalized = message.trim().toLowerCase();
    return normalized.contains('no internet') ||
        normalized.contains('koneksi internet') ||
        normalized.contains('internet connection') ||
        normalized.contains('socketexception');
  }

  Future<void> _saveApprovalDraft({
    required DraftType type,
    required String title,
    required Map<String, dynamic> data,
    required String successMessage,
  }) async {
    final draft = ReportDraft(
      id: _buildDraftId(type.name),
      type: type,
      title: title.trim().isEmpty ? 'Draft Approval' : title.trim(),
      data: data,
      createdAt: DateTime.now(),
    );
    await CloudSaveService.instance.saveDraft(draft);
    await BackgroundSyncService.instance.notifyDraftSaved();
    if (!mounted) return;
    _showSuccessPopup(context, successMessage);
  }

  Future<void> _pickImage() async {
    final picked = await _pickAndCropProfileImage();
    if (picked == null) return;
    await _uploadProfilePhoto(picked);
  }

  Future<ImageSource?> _pickProfileImageSource() async {
    if (kIsWeb) return ImageSource.gallery;
    return showModalBottomSheet<ImageSource>(
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
  }

  Future<XFile?> _pickAndCropProfileImage() async {
    final source = await _pickProfileImageSource();
    if (source == null) return null;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 95);
      if (picked == null) return null;

      if (kIsWeb) return picked;

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
      if (croppedFile == null) return null;
      return XFile(croppedFile.path);
    } catch (_) {
      if (!mounted) return null;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Terjadi masalah saat memilih atau crop foto.'),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(16, 16, 16, 16),
        ),
      );
      return null;
    }
  }

  Future<void> _uploadProfilePhoto(XFile pickedImage) async {
    _showLoadingDialog('Mengunggah Foto...');
    setState(() {
      _avatarFile = pickedImage;
    });

    final result = await ProfileService.updateProfile(
      imagePath: pickedImage.path,
    );

    if (!mounted) return;
    _dismissLoadingDialog();
    if (!result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage ?? 'Gagal mengunggah foto profil'),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        ),
      );
      return;
    }

    await _loadProfile();
    if (!mounted) return;
    setState(() => _avatarFile = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Foto profil berhasil diperbarui'),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(16, 16, 16, 16),
      ),
    );
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
      backgroundColor: const Color(0xFFF2F2F2),
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
          : RefreshIndicator(
              onRefresh: _onRefresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
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
        'NIP belum diisi';
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
        final mpState = _MinePermitState.resolve(_profileData?.licenses ?? []);
        return _LicenseContent(
          licenses: _profileData?.licenses ?? [],
          onDetail: _showLicenseDetail,
          onAdd: _showAddLicenseForm,
          onEdit: (license) {
            _showAddLicenseForm(editLicense: license);
          },
          onDelete: (license) {
            _showDeleteLicenseConfirm(license);
          },
          minePermitState: mpState,
          onMinePermitTap: () => _showMinePermitDetail(mpState),
        );
      case 3:
        return _ViolationContent(
          violations: _profileData?.violations ?? [],
          onDetail: _showViolationDetail,
        );
      case 4:
        return _CertificationContent(
          certifications: _profileData?.certifications ?? [],
          onDetail: _showCertificationDetail,
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

  void _showLicenseDetail(UserLicense license) {
    Navigator.push(
      context,
      _FadePageRoute(
        builder: (_) => _LicenseDetailPage(
          license: license,
          profileData: _profileData,
          cachedUser: _cachedUser,
          onEdit: (license) => _showAddLicenseForm(editLicense: license),
          onDelete: _showDeleteLicenseConfirm,
        ),
      ),
    );
  }

  void _showCertificationDetail(UserCertification certification) {
    Navigator.push(
      context,
      _FadePageRoute(
        builder: (_) => _CertificationDetailPage(
          certification: certification,
          profileData: _profileData,
          cachedUser: _cachedUser,
          onEdit: (cert) => _showAddCertificationForm(editCert: cert),
          onDelete: _showDeleteCertificationConfirm,
        ),
      ),
    );
  }

  void _showViolationDetail(UserViolation violation) {
    Navigator.push(
      context,
      _FadePageRoute(
        builder: (_) => _ViolationDetailPage(violation: violation),
      ),
    );
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
                        FocusScope.of(modalContext).unfocus();
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
                                  final picked =
                                      await _pickAndCropProfileImage();
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
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8E1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                      color: const Color(0xFFFFE082)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.info_outline,
                                        color: Color(0xFFB28704), size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Perubahan data profil memerlukan persetujuan admin.',
                                        style: TextStyle(
                                            color: Colors.orange.shade800,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildSheetField(
                                'NIP / Employee ID (Opsional)',
                                nikCtrl,
                                maxLength: 20,
                                validator: (v) {
                                  final value = (v ?? '').trim();
                                  if (value.isNotEmpty && value.length < 5) {
                                    return 'NIP minimal 5 karakter';
                                  }
                                  return null;
                                },
                              ),
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
                              _buildPhoneField(
                                  phoneCtrl, _editProfilePhoneFocusNode),
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
                                enabled: true,
                                readOnly: true,
                                onTap: () => _showDepartmentPicker(
                                    modalContext, deptCtrl, setModalState),
                                maxLength: 25,
                                suffixIcon: Icons.arrow_drop_down,
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
                                enabled: true,
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
                                enabled: true,
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

                            FocusScope.of(modalContext).unfocus();
                            Navigator.pop(sheetContext);
                            _showLoadingDialog('Menyimpan Profil...');

                            final result = await ProfileService.updateProfile(
                              employeeId: nikCtrl.text.trim(),
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
                              _showSuccessPopup(
                                context,
                                'Pengajuan perubahan profil berhasil dikirim. Menunggu persetujuan admin.',
                              );
                            } else {
                              final errorMsg = result.errorMessage ?? '';
                              final isOffline = _isNoInternetMessage(errorMsg);

                              if (isOffline) {
                                _dismissLoadingDialog();
                                // Save as draft for offline
                                await _saveApprovalDraft(
                                  type: DraftType.profileChange,
                                  title: 'Perubahan Profil',
                                  data: {
                                    'fullName': nameCtrl.text.trim(),
                                    'employeeId': nikCtrl.text.trim(),
                                    'personalEmail': emailCtrl.text.trim(),
                                    'workEmail': workEmailCtrl.text.trim(),
                                    'phoneNumber':
                                        '+62${phoneCtrl.text.trim()}',
                                    'department': deptCtrl.text.trim(),
                                    'position': posCtrl.text.trim(),
                                    'jabatan': jobCtrl.text.trim(),
                                    'address': addressCtrl.text.trim(),
                                    'tipeAfiliasi':
                                        localTipeAfiliasi == 'Sub-Kont.'
                                            ? 'Sub-Kontraktor'
                                            : localTipeAfiliasi,
                                    'company': localSelectedPerusahaan,
                                    'perusahaanKontraktor':
                                        localSelectedPerusahaanKontraktor ?? '',
                                    'subKontraktor':
                                        localSelectedSubKontraktor ?? '',
                                    'imagePath': localImageFile?.path,
                                  },
                                  successMessage:
                                      'Tidak ada koneksi internet. Draft perubahan profil disimpan di Inbox > MyPost > Draft.',
                                );
                              } else {
                                _dismissLoadingDialog();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(errorMsg.isEmpty
                                          ? 'Gagal memperbarui'
                                          : errorMsg),
                                      behavior: SnackBarBehavior.floating,
                                      margin: const EdgeInsets.fromLTRB(
                                          16, 16, 16, 16)),
                                );
                              }
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
    final selectedValue = items.contains(value) ? value : null;
    return FormField<String>(
      initialValue: selectedValue,
      validator: required
          ? (v) {
              if (v == null || v.trim().isEmpty) {
                return '$label wajib dipilih';
              }
              return null;
            }
          : null,
      builder: (state) {
        final currentValue = state.value;
        final hasError = state.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label + (required ? ' *' : ''),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _showCompanyPicker(
                context,
                title: 'Pilih $label',
                items: items,
                selectedValue: currentValue,
                onSelected: (selected) {
                  state.didChange(selected);
                  onChanged(selected);
                },
              ),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: hasError ? Colors.red : Colors.grey.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: currentValue == null
                            ? Colors.white
                            : const Color(0xFFEAF1FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Icon(
                        Icons.business_rounded,
                        color: currentValue == null
                            ? Colors.grey.shade400
                            : const Color(0xFF1A56C4),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        currentValue ?? 'Pilih $label',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: currentValue == null
                              ? Colors.grey.shade500
                              : Colors.black87,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(Icons.keyboard_arrow_down_rounded,
                        color: Colors.grey.shade500),
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

  void _showCompanyPicker(
    BuildContext context, {
    required String title,
    required List<String> items,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    var query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final filteredItems = items
              .where((item) => item.toLowerCase().contains(query.toLowerCase()))
              .toList();
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.78,
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
                  padding: const EdgeInsets.fromLTRB(24, 16, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A56C4),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: TextField(
                    onChanged: (value) => setSheetState(() => query = value),
                    decoration: InputDecoration(
                      hintText: 'Cari perusahaan...',
                      hintStyle: TextStyle(color: Colors.grey.shade400),
                      prefixIcon:
                          Icon(Icons.search, color: Colors.grey.shade400),
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
                const SizedBox(height: 16),
                Expanded(
                  child: filteredItems.isEmpty
                      ? Center(
                          child: Text(
                            'Perusahaan tidak ditemukan',
                            style: TextStyle(color: Colors.grey.shade500),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filteredItems.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final isSelected = item == selectedValue;
                            return InkWell(
                              onTap: () {
                                onSelected(item);
                                Navigator.pop(context);
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEAF1FF)
                                      : Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? const Color(0xFF1A56C4)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 34,
                                      height: 34,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(0xFF1A56C4)
                                            : Colors.white,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                            color: Colors.grey.shade200),
                                      ),
                                      child: Icon(
                                        isSelected
                                            ? Icons.check_rounded
                                            : Icons.business_rounded,
                                        color: isSelected
                                            ? Colors.white
                                            : const Color(0xFF1A56C4),
                                        size: 18,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        item,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.black87,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
                SizedBox(
                  height: AppSafeInsets.bottomNavScrollPadding(context),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showEditMedicalForm() {
    final medicals = _profileData?.medicals ?? [];
    final latest = medicals.isNotEmpty ? medicals.first : null;

    final bloodTypeCtrl = TextEditingController(text: latest?.bloodType);
    final heightCtrl = TextEditingController(text: latest?.height);
    final parsedHeight = int.tryParse(
      (latest?.height ?? '').replaceAll(RegExp(r'[^0-9]'), ''),
    );
    double selectedHeight = (parsedHeight ?? 170).clamp(50, 300).toDouble();
    heightCtrl.text = selectedHeight.round().toString();
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
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Text(
                            '50 cm',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                          const Spacer(),
                          Text(
                            '${selectedHeight.round()} cm',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A56C4),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '300 cm',
                            style: TextStyle(
                                color: Colors.grey.shade500, fontSize: 12),
                          ),
                        ],
                      ),
                      Slider(
                        value: selectedHeight,
                        min: 50,
                        max: 300,
                        divisions: 250,
                        label: '${selectedHeight.round()} cm',
                        activeColor: const Color(0xFF1A56C4),
                        onChanged: (value) {
                          setModalState(() {
                            selectedHeight = value;
                            heightCtrl.text = value.round().toString();
                          });
                        },
                      ),
                    ],
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
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.message),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 16)));
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
    final types = [
      'A',
      'A+',
      'A-',
      'B',
      'B+',
      'B-',
      'AB',
      'AB+',
      'AB-',
      'O',
      'O+',
      'O-',
    ];
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
            SizedBox(
              height: 260,
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childAspectRatio: 2.4,
                children: types
                    .map(
                      (type) => InkWell(
                        onTap: () {
                          setModalState(() => ctrl.text = type);
                          Navigator.pop(context);
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Text(
                            type,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ignore: unused_element
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

  void _showLicenseCategoryPicker(
    BuildContext context, {
    required String title,
    required List<String> options,
    required String? selectedValue,
    required ValueChanged<String> onSelected,
    Map<String, String> descriptions = const {},
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.fromLTRB(
          24,
          20,
          24,
          AppSafeInsets.sheetBottomPadding(context),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.25,
              children: options.map((option) {
                final isSelected = option == selectedValue;
                final description = descriptions[option];
                return InkWell(
                  onTap: () {
                    onSelected(option);
                    Navigator.pop(context);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF1A56C4)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF1A56C4)
                            : Colors.grey.shade200,
                      ),
                    ),
                    child: Text(
                      description == null ? option : '$option\n$description',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: description == null ? 16 : 12.5,
                        height: 1.15,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  void _showLicenseTypePicker(
    BuildContext context, {
    required String selectedValue,
    required ValueChanged<String> onSelected,
  }) {
    const options = [
      {
        'value': 'general',
        'label': 'License Umum',
        'description': 'Kategori bebas seperti U, SIO, K3',
      },
      {
        'value': 'simper',
        'label': 'SIMPER License',
        'description': 'Kategori DT, BD, BL, EX, WT, WL',
      },
      {
        'value': 'government',
        'label': 'License Pemerintah',
        'description': 'Kategori SIM Indonesia A sampai D1',
      },
      {
        'value': 'mine_permit',
        'label': 'Mine Permit',
        'description': 'Pengajuan mine permit dari profil',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.75;
        return ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              AppSafeInsets.sheetBottomPadding(context),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Pilih Tipe Lisensi',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: options.map((option) {
                        final value = option['value']!;
                        final isSelected = value == selectedValue;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: InkWell(
                            onTap: () {
                              onSelected(value);
                              Navigator.pop(context);
                            },
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEAF1FF)
                                    : Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFF1A56C4)
                                      : Colors.grey.shade200,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 34,
                                    height: 34,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(0xFF1A56C4)
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Colors.grey.shade200,
                                      ),
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_rounded
                                          : Icons.badge_outlined,
                                      color: isSelected
                                          ? Colors.white
                                          : const Color(0xFF1A56C4),
                                      size: 19,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option['label']!,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          option['description']!,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddLicenseForm({UserLicense? editLicense}) {
    if (editLicense != null) {
      _licenseNameController.text = editLicense.name;
      _licenseNumberController.text = editLicense.licenseNumber;
      _licenseIssuerController.text = editLicense.issuer ?? '';
      _licenseVehicleEquipmentController.text =
          editLicense.vehicleEquipment ?? '';
      _licenseType = editLicense.licenseType;
      _licenseSimType = editLicense.simType;
      _licenseSimIndonesiaType = editLicense.simIndonesiaType;
      _licenseCategoryController.text = editLicense.simIndonesiaType ?? '';
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
      _licenseVehicleEquipmentController.clear();
      _licenseCategoryController.clear();
      _licenseType = 'general';
      _licenseSimType = null;
      _licenseSimIndonesiaType = null;
      _licenseObtainedAt = null;
      _licenseSelectedDate = null;
      _licenseImage = null;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => StatefulBuilder(
        builder: (modalContext, setModalState) {
          const governmentCategories = [
            'A',
            'B1',
            'B2',
            'C',
            'C1',
            'C2',
            'D',
            'D1',
          ];
          const simperCategories = ['DT', 'BD', 'BL', 'EX', 'WT', 'WL'];
          const simTypeOptions = ['F', 'P', 'R', 'T', 'I'];
          const simTypeDescriptions = {
            'F': 'Full',
            'P': 'Probation',
            'R': 'Restricted',
            'T': 'Training',
            'I': 'Instructor',
          };
          final categoryOptions = _licenseType == 'government'
              ? governmentCategories
              : _licenseType == 'simper'
                  ? simperCategories
                  : null;
          final selectedCategory =
              categoryOptions?.contains(_licenseSimIndonesiaType) == true
                  ? _licenseSimIndonesiaType
                  : null;
          final selectedSimType =
              simTypeOptions.contains(_licenseSimType) ? _licenseSimType : null;
          const licenseTypeLabels = {
            'general': 'License Umum',
            'simper': 'SIMPER License',
            'government': 'License Pemerintah',
            'mine_permit': 'Mine Permit',
          };
          final selectedLicenseTypeLabel =
              licenseTypeLabels[_licenseType] ?? 'Pilih tipe lisensi';

          // Check if mine permit confirmation view should be shown
          final showMinePermitConfirmation =
              _licenseType == 'mine_permit' && editLicense == null;

          return Container(
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
                  _buildFieldLabel('Tipe Lisensi'),
                  InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => _showLicenseTypePicker(
                      modalContext,
                      selectedValue: _licenseType,
                      onSelected: (value) {
                        setModalState(() {
                          _licenseType = value;
                          if (value == 'government' &&
                              !governmentCategories
                                  .contains(_licenseSimIndonesiaType)) {
                            _licenseSimIndonesiaType = null;
                          } else if (value == 'simper' &&
                              !simperCategories
                                  .contains(_licenseSimIndonesiaType)) {
                            _licenseSimIndonesiaType = null;
                          } else if (value == 'general') {
                            _licenseCategoryController.text =
                                _licenseSimIndonesiaType ?? '';
                          }
                          if ((value == 'simper' || value == 'government') &&
                              _licenseNameController.text.trim().isEmpty) {
                            _licenseNameController.text = value == 'government'
                                ? 'License Pemerintah'
                                : 'SIMPER';
                          }
                        });
                      },
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: const Color(0xFFEAF1FF),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.badge_outlined,
                              color: Color(0xFF1A56C4),
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              selectedLicenseTypeLabel,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Icon(Icons.keyboard_arrow_down_rounded,
                              color: Colors.grey.shade500),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Mine Permit Confirmation View
                  if (showMinePermitConfirmation) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF90CAF9)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline,
                              color: Color(0xFF1A56C4), size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Data Mine Permit akan diambil otomatis dari profil Anda',
                              style: TextStyle(
                                color: Colors.blue.shade900,
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Informasi Pemohon',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildReadOnlyRow(
                              'Nama', _profileData?.fullName ?? '-'),
                          const SizedBox(height: 8),
                          _buildReadOnlyRow(
                              'NIP', _profileData?.employeeId ?? '-'),
                          const SizedBox(height: 8),
                          _buildReadOnlyRow(
                              'Perusahaan', _profileData?.company ?? '-'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () async {
                          // Check if can renew
                          final licenses = _profileData?.licenses ?? [];
                          final existingMinePermit = licenses
                              .where((l) =>
                                  l.licenseType == 'mine_permit' ||
                                  l.name.toLowerCase().trim() == 'mine permit')
                              .toList()
                            ..sort((a, b) => (b.expiredAt ?? '')
                                .compareTo(a.expiredAt ?? ''));
                          final existing = existingMinePermit.isNotEmpty
                              ? existingMinePermit.first
                              : null;

                          if (existing != null && !existing.canBeRenewedNow()) {
                            await showDialog<void>(
                              context: modalContext,
                              builder: (ctx) => AlertDialog(
                                title:
                                    const Text('Perpanjangan Belum Tersedia'),
                                content: const Text(
                                    UserLicense.renewalBlockedMessage),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: const Text('Tutup'),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }

                          Navigator.pop(sheetContext);
                          _showLoadingDialog('Mengajukan Mine Permit...');

                          final result =
                              await ProfileService.requestMinePermit();

                          if (!mounted) return;
                          _dismissLoadingDialog();

                          if (result.success) {
                            await _loadProfile();
                            if (!mounted) return;
                            _showSuccessPopup(
                              context,
                              result.message,
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                behavior: SnackBarBehavior.floating,
                                margin:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 16),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1A56C4),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        child: const Text('Ajukan Mine Permit',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],

                  // Regular License Form (hidden when mine_permit is selected)
                  if (!showMinePermitConfirmation) ...[
                    _buildFieldLabel('Nama Lisensi'),
                    TextField(
                      controller: _licenseNameController,
                      decoration: _buildInputDecoration(
                          'Contoh: SIM A, SIO Excavator...'),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Nomor Lisensi'),
                    TextField(
                      controller: _licenseNumberController,
                      decoration:
                          _buildInputDecoration('Contoh: SIM-2024-001234'),
                    ),
                    const SizedBox(height: 16),
                    _buildFieldLabel('Lembaga Penerbit'),
                    TextField(
                      controller: _licenseIssuerController,
                      decoration: _buildInputDecoration(
                          'Contoh: Polri, Kemnaker RI...'),
                    ),
                    if (_licenseType != 'mine_permit') ...[
                      const SizedBox(height: 16),
                      _buildFieldLabel(
                        _licenseType == 'government'
                            ? 'Kategori SIM Indonesia'
                            : _licenseType == 'simper'
                                ? 'Kategori SIMPER'
                                : 'Kategori Lisensi',
                      ),
                      if (categoryOptions == null)
                        TextField(
                          controller: _licenseCategoryController,
                          textCapitalization: TextCapitalization.characters,
                          decoration:
                              _buildInputDecoration('Contoh: U, SIO, K3'),
                          onChanged: (value) => _licenseSimIndonesiaType =
                              value.trim().isEmpty ? null : value.trim(),
                        )
                      else
                        InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _showLicenseCategoryPicker(
                            modalContext,
                            title: _licenseType == 'government'
                                ? 'Pilih Kategori SIM Indonesia'
                                : 'Pilih Kategori SIMPER',
                            options: categoryOptions,
                            selectedValue: selectedCategory,
                            onSelected: (value) {
                              setModalState(() {
                                _licenseSimIndonesiaType = value;
                                _licenseCategoryController.text = value;
                              });
                            },
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 13),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: selectedCategory == null
                                        ? Colors.white
                                        : const Color(0xFF1A56C4),
                                    borderRadius: BorderRadius.circular(10),
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Text(
                                    selectedCategory ?? '-',
                                    style: TextStyle(
                                      color: selectedCategory == null
                                          ? Colors.grey.shade400
                                          : Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    selectedCategory == null
                                        ? (_licenseType == 'government'
                                            ? 'Pilih A, B1, B2, C, C1, C2, D, D1'
                                            : 'Pilih DT, BD, BL, EX, WT, WL')
                                        : 'Kategori $selectedCategory',
                                    style: TextStyle(
                                      color: selectedCategory == null
                                          ? Colors.grey.shade500
                                          : Colors.black87,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Colors.grey.shade500),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('Vehicle Equipment'),
                      TextField(
                        controller: _licenseVehicleEquipmentController,
                        decoration: _buildInputDecoration(
                          'Contoh: DT (Dump Truck) Lumpur',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFieldLabel('SIM Type (LIC)'),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _showLicenseCategoryPicker(
                          modalContext,
                          title: 'Pilih SIM Type (LIC)',
                          options: simTypeOptions,
                          selectedValue: selectedSimType,
                          descriptions: simTypeDescriptions,
                          onSelected: (value) {
                            setModalState(() => _licenseSimType = value);
                          },
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 13),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: selectedSimType == null
                                      ? Colors.white
                                      : const Color(0xFF1A56C4),
                                  borderRadius: BorderRadius.circular(10),
                                  border:
                                      Border.all(color: Colors.grey.shade200),
                                ),
                                child: Text(
                                  selectedSimType ?? '-',
                                  style: TextStyle(
                                    color: selectedSimType == null
                                        ? Colors.grey.shade400
                                        : Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  selectedSimType == null
                                      ? 'Pilih F, P, R, T, I'
                                      : 'LIC $selectedSimType - ${simTypeDescriptions[selectedSimType]}',
                                  style: TextStyle(
                                    color: selectedSimType == null
                                        ? Colors.grey.shade500
                                        : Colors.black87,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Icon(Icons.keyboard_arrow_down_rounded,
                                  color: Colors.grey.shade500),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    _buildFieldLabel('Tanggal Diperoleh'),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: modalContext,
                          initialDate: _licenseObtainedAt ?? DateTime.now(),
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365 * 5)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setModalState(() => _licenseObtainedAt = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                          firstDate: DateTime.now()
                              .subtract(const Duration(days: 365 * 5)),
                          lastDate: DateTime.now()
                              .add(const Duration(days: 365 * 10)),
                        );
                        if (picked != null) {
                          setModalState(() => _licenseSelectedDate = picked);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Harap lengkapi semua data'),
                                    behavior: SnackBarBehavior.floating,
                                    margin:
                                        EdgeInsets.fromLTRB(16, 16, 16, 16)));
                            return;
                          }

                          Navigator.pop(sheetContext);
                          _showLoadingDialog(editLicense != null
                              ? 'Memperbarui Lisensi...'
                              : 'Menyimpan Lisensi...');

                          final isEdit = editLicense != null;
                          final licenseName =
                              _licenseNameController.text.trim();
                          final licenseNumber =
                              _licenseNumberController.text.trim();
                          final issuer = _licenseIssuerController.text.trim();
                          final vehicleEquipment =
                              _licenseVehicleEquipmentController.text.trim();
                          final simIndonesiaType = _licenseType == 'general'
                              ? _licenseCategoryController.text.trim()
                              : (_licenseSimIndonesiaType ?? '').trim();
                          final obtainedAt =
                              _formatDateForPayload(_licenseObtainedAt);
                          final expiredAt =
                              _formatDateForPayload(_licenseSelectedDate);
                          final imagePath = _licenseImage?.path;

                          void clearLicenseForm() {
                            _licenseNameController.clear();
                            _licenseNumberController.clear();
                            _licenseIssuerController.clear();
                            _licenseVehicleEquipmentController.clear();
                            _licenseCategoryController.clear();
                            _licenseType = 'general';
                            _licenseSimType = null;
                            _licenseSimIndonesiaType = null;
                            _licenseObtainedAt = null;
                            _licenseSelectedDate = null;
                            _licenseImage = null;
                          }

                          final draftPayload = <String, dynamic>{
                            'operation': isEdit ? 'update' : 'create',
                            if (isEdit) 'remoteId': editLicense.id,
                            if (isEdit) 'targetId': editLicense.id,
                            'name': licenseName,
                            'licenseNumber': licenseNumber,
                            'licenseType': _licenseType,
                            'vehicleEquipment': vehicleEquipment.isEmpty
                                ? null
                                : vehicleEquipment,
                            'simType': _licenseSimType,
                            'simIndonesiaType': simIndonesiaType.isEmpty
                                ? null
                                : simIndonesiaType,
                            'issuer': issuer.isEmpty ? null : issuer,
                            'obtainedAt':
                                obtainedAt.isEmpty ? null : obtainedAt,
                            'expiredAt': expiredAt.isEmpty ? null : expiredAt,
                            'imagePath': imagePath,
                          };

                          final online = await CloudSaveService.isOnline();
                          if (!online) {
                            if (!mounted) return;
                            _dismissLoadingDialog();
                            await _saveApprovalDraft(
                              type: isEdit
                                  ? DraftType.licenseUpdate
                                  : DraftType.licenseCreate,
                              title: licenseName,
                              data: draftPayload,
                              successMessage:
                                  'Tidak ada koneksi internet. Draft lisensi disimpan di Inbox > MyPost > Draft.',
                            );
                            clearLicenseForm();
                            return;
                          }

                          final result = isEdit
                              ? await ProfileService.updateLicense(
                                  id: editLicense.id.toString(),
                                  name: licenseName,
                                  licenseNumber: licenseNumber,
                                  issuer: issuer,
                                  licenseType: _licenseType,
                                  vehicleEquipment: vehicleEquipment,
                                  simType: _licenseSimType,
                                  simIndonesiaType: simIndonesiaType.isEmpty
                                      ? null
                                      : simIndonesiaType,
                                  obtainedAt:
                                      obtainedAt.isEmpty ? null : obtainedAt,
                                  expiredAt:
                                      expiredAt.isEmpty ? null : expiredAt,
                                  imageFile: _licenseImage,
                                )
                              : await ProfileService.addLicense(
                                  name: licenseName,
                                  licenseNumber: licenseNumber,
                                  issuer: issuer,
                                  licenseType: _licenseType,
                                  vehicleEquipment: vehicleEquipment,
                                  simType: _licenseSimType,
                                  simIndonesiaType: simIndonesiaType.isEmpty
                                      ? null
                                      : simIndonesiaType,
                                  obtainedAt:
                                      obtainedAt.isEmpty ? null : obtainedAt,
                                  expiredAt:
                                      expiredAt.isEmpty ? null : expiredAt,
                                  imageFile: _licenseImage,
                                );

                          if (!mounted) return;
                          _dismissLoadingDialog();
                          if (result.success) {
                            clearLicenseForm();
                            await _loadProfile();
                            if (mounted) {
                              _showSuccessPopup(
                                context,
                                isEdit
                                    ? 'Lisensi berhasil diperbarui'
                                    : 'Lisensi berhasil ditambahkan',
                              );
                            }
                          } else if (_isNoInternetMessage(result.message)) {
                            await _saveApprovalDraft(
                              type: isEdit
                                  ? DraftType.licenseUpdate
                                  : DraftType.licenseCreate,
                              title: licenseName,
                              data: draftPayload,
                              successMessage:
                                  'Koneksi internet terputus. Draft lisensi disimpan di Inbox > MyPost > Draft.',
                            );
                            clearLicenseForm();
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text(result.message),
                                behavior: SnackBarBehavior.floating,
                                margin:
                                    const EdgeInsets.fromLTRB(16, 16, 16, 16)));
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
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildReadOnlyRow(String label, String value) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey.shade600,
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
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
          child: SingleChildScrollView(
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
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 10)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 10)),
                    );
                    if (picked != null) {
                      setModalState(() => _certObtainedAt = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                      firstDate: DateTime.now()
                          .subtract(const Duration(days: 365 * 10)),
                      lastDate:
                          DateTime.now().add(const Duration(days: 365 * 10)),
                    );
                    if (picked != null) {
                      setModalState(() => _certExpiredAt = picked);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
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
                    if (picked != null) {
                      setModalState(() => _certImage = picked);
                    }
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
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Harap lengkapi nama dan penerbit'),
                                behavior: SnackBarBehavior.floating,
                                margin: EdgeInsets.fromLTRB(16, 16, 16, 16)));
                        return;
                      }

                      Navigator.pop(sheetContext);
                      _showLoadingDialog(editCert != null
                          ? 'Memperbarui Sertifikat...'
                          : 'Menyimpan Sertifikat...');

                      final isEdit = editCert != null;
                      final certName = _certNameController.text.trim();
                      final certNumber = _certNumberController.text.trim();
                      final issuer = _certIssuerController.text.trim();
                      final obtainedAt = _formatDateForPayload(_certObtainedAt);
                      final expiredAt = _formatDateForPayload(_certExpiredAt);
                      final imagePath = _certImage?.path;

                      void clearCertificationForm() {
                        _certNameController.clear();
                        _certNumberController.clear();
                        _certIssuerController.clear();
                        _certObtainedAt = null;
                        _certExpiredAt = null;
                        _certImage = null;
                      }

                      final draftPayload = <String, dynamic>{
                        'operation': isEdit ? 'update' : 'create',
                        if (isEdit) 'remoteId': editCert.id,
                        if (isEdit) 'targetId': editCert.id,
                        'name': certName,
                        'certificationNumber':
                            certNumber.isEmpty ? null : certNumber,
                        'issuer': issuer,
                        'obtainedAt': obtainedAt.isEmpty ? null : obtainedAt,
                        'expiredAt': expiredAt.isEmpty ? null : expiredAt,
                        'imagePath': imagePath,
                      };

                      final online = await CloudSaveService.isOnline();
                      if (!online) {
                        if (!mounted) return;
                        _dismissLoadingDialog();
                        await _saveApprovalDraft(
                          type: isEdit
                              ? DraftType.certificationUpdate
                              : DraftType.certificationCreate,
                          title: certName,
                          data: draftPayload,
                          successMessage:
                              'Tidak ada koneksi internet. Draft sertifikat disimpan di Inbox > MyPost > Draft.',
                        );
                        clearCertificationForm();
                        return;
                      }

                      final result = isEdit
                          ? await ProfileService.updateCertification(
                              id: editCert.id.toString(),
                              name: certName,
                              certificationNumber:
                                  certNumber.isEmpty ? null : certNumber,
                              issuer: issuer,
                              obtainedAt:
                                  obtainedAt.isEmpty ? null : obtainedAt,
                              expiredAt: expiredAt.isEmpty ? null : expiredAt,
                              imageFile: _certImage,
                            )
                          : await ProfileService.addCertification(
                              name: certName,
                              certificationNumber:
                                  certNumber.isEmpty ? null : certNumber,
                              issuer: issuer,
                              obtainedAt:
                                  obtainedAt.isEmpty ? null : obtainedAt,
                              expiredAt: expiredAt.isEmpty ? null : expiredAt,
                              imageFile: _certImage,
                            );

                      if (!mounted) return;
                      _dismissLoadingDialog();
                      if (result.success) {
                        clearCertificationForm();
                        await _loadProfile();
                        if (mounted) {
                          _showSuccessPopup(
                            context,
                            isEdit
                                ? 'Sertifikat berhasil diperbarui'
                                : 'Sertifikat berhasil ditambahkan',
                          );
                        }
                      } else if (_isNoInternetMessage(result.message)) {
                        await _saveApprovalDraft(
                          type: isEdit
                              ? DraftType.certificationUpdate
                              : DraftType.certificationCreate,
                          title: certName,
                          data: draftPayload,
                          successMessage:
                              'Koneksi internet terputus. Draft sertifikat disimpan di Inbox > MyPost > Draft.',
                        );
                        clearCertificationForm();
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(result.message),
                            behavior: SnackBarBehavior.floating,
                            margin: const EdgeInsets.fromLTRB(16, 16, 16, 16)));
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
                  const SnackBar(
                    content: Text('Lisensi berhasil dihapus'),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  ),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  ),
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
                  const SnackBar(
                    content: Text('Sertifikat berhasil dihapus'),
                    behavior: SnackBarBehavior.floating,
                    margin: EdgeInsets.fromLTRB(16, 16, 16, 16),
                  ),
                );
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(result.message),
                    behavior: SnackBarBehavior.floating,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  ),
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

  void _showSuccessPopup(BuildContext ctx, String message) {
    showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 60),
            const SizedBox(height: 16),
            const Text(
              'Berhasil!',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogCtx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A56C4),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Tutup',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
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
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 16),
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
            _buildRow(context, 'NIP', data?.employeeId ?? '-',
                onTap: () =>
                    _copyToClipboard(context, 'NIP', data?.employeeId)),
            _buildRow(context, 'Nama Lengkap', data?.fullName ?? '-',
                onTap: () =>
                    _copyToClipboard(context, 'Nama Lengkap', data?.fullName)),
            _buildRow(context, 'Email', data?.personalEmail ?? '-', onTap: () {
              final e = data?.personalEmail;
              if (e != null && e.isNotEmpty && e != '-') {
                _showEmailOptions(context, e);
              }
            }),
            _buildRow(context, 'Phone', data?.phoneNumber ?? '-', onTap: () {
              final phone = data?.phoneNumber ?? "";
              if (phone.isNotEmpty && phone != '-') {
                _showPhoneOptions(context, phone);
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

  void _showEmailOptions(BuildContext context, String email) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Hubungi via Email',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(Icons.email, color: Color(0xFFD32F2F)),
              ),
              title: const Text('Kirim Email'),
              subtitle: Text(email),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('mailto:$email');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.copy, color: Color(0xFFFB8C00)),
              ),
              title: const Text('Salin Email'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(context, 'Email', email);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showPhoneOptions(BuildContext context, String phone) {
    String cleanNumber = phone.replaceAll(RegExp(r'[^\d+]'), '');
    String waNumber = cleanNumber;
    if (waNumber.startsWith('0')) {
      waNumber = '62${waNumber.substring(1)}';
    }

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Text(
                'Hubungi Karyawan',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE3F2FD),
                child: Icon(Icons.phone, color: Color(0xFF1E88E5)),
              ),
              title: const Text('Panggilan Telepon'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('tel:$cleanNumber');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.message, color: Color(0xFF43A047)),
              ),
              title: const Text('WhatsApp'),
              subtitle: Text(phone),
              onTap: () {
                Navigator.pop(context);
                _launchUrl('https://wa.me/$waNumber');
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.copy, color: Color(0xFFFB8C00)),
              ),
              title: const Text('Salin Nomor'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(context, 'Nomor Telepon', phone);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

enum _MinePermitStateKey {
  none,
  pending,
  pendingChanges,
  approvedLocked,
  approvedRenewable,
  expired,
  rejected,
}

class _MinePermitState {
  final _MinePermitStateKey key;
  final UserLicense? license;
  const _MinePermitState({required this.key, this.license});

  static bool _isMinePermit(UserLicense l) =>
      l.licenseType == 'mine_permit' ||
      l.name.toLowerCase().trim() == 'mine permit';

  static _MinePermitState resolve(List<UserLicense> licenses, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final all = licenses.where(_isMinePermit).toList();
    if (all.isEmpty) {
      return const _MinePermitState(key: _MinePermitStateKey.none);
    }
    all.sort((a, b) {
      final sa = (a.submittedAt ?? a.expiredAt ?? '');
      final sb = (b.submittedAt ?? b.expiredAt ?? '');
      return sb.compareTo(sa);
    });
    final latest = all.first;
    final approved = UserLicense.findApprovedMinePermit(licenses);
    final status = latest.approvalStatus.toLowerCase();

    if (status == 'pending') {
      return _MinePermitState(
          key: _MinePermitStateKey.pending, license: latest);
    }
    if (status == 'pending_changes') {
      return _MinePermitState(
          key: _MinePermitStateKey.pendingChanges, license: approved ?? latest);
    }
    if (status == 'rejected') {
      return _MinePermitState(
          key: _MinePermitStateKey.rejected, license: latest);
    }
    if (status == 'approved' && approved != null) {
      final expiry = DateTime.tryParse((approved.expiredAt ?? '').trim());
      if (expiry != null && expiry.isBefore(ref)) {
        return _MinePermitState(
            key: _MinePermitStateKey.expired, license: approved);
      }
      if (approved.canBeRenewedNow(now: ref)) {
        return _MinePermitState(
            key: _MinePermitStateKey.approvedRenewable, license: approved);
      }
      return _MinePermitState(
          key: _MinePermitStateKey.approvedLocked, license: approved);
    }
    return _MinePermitState(key: _MinePermitStateKey.none, license: latest);
  }
}

class _MinePermitCard extends StatelessWidget {
  final _MinePermitState state;
  final VoidCallback onTap;

  const _MinePermitCard({required this.state, required this.onTap});

  ({Color bg, Color fg, Color border, String badge}) _statusColors() {
    switch (state.key) {
      case _MinePermitStateKey.approvedLocked:
        return (
          bg: const Color(0xFFE8F5E9),
          fg: const Color(0xFF2E7D32),
          border: const Color(0xFFC8E6C9),
          badge: 'Aktif',
        );
      case _MinePermitStateKey.approvedRenewable:
        return (
          bg: const Color(0xFFFFF8E1),
          fg: const Color(0xFFE65100),
          border: const Color(0xFFFFE082),
          badge: 'Akan Berakhir',
        );
      case _MinePermitStateKey.pending:
        return (
          bg: const Color(0xFFE3F2FD),
          fg: const Color(0xFF1565C0),
          border: const Color(0xFF90CAF9),
          badge: 'Menunggu',
        );
      case _MinePermitStateKey.pendingChanges:
        return (
          bg: const Color(0xFFFFF8E1),
          fg: const Color(0xFFE65100),
          border: const Color(0xFFFFE082),
          badge: 'Perpanjangan',
        );
      case _MinePermitStateKey.expired:
        return (
          bg: const Color(0xFFFFEBEE),
          fg: const Color(0xFFD32F2F),
          border: const Color(0xFFFFCDD2),
          badge: 'Kedaluwarsa',
        );
      case _MinePermitStateKey.rejected:
        return (
          bg: const Color(0xFFFFEBEE),
          fg: const Color(0xFFC62828),
          border: const Color(0xFFFFCDD2),
          badge: 'Ditolak',
        );
      case _MinePermitStateKey.none:
        return (
          bg: const Color(0xFFF5F5F5),
          fg: const Color(0xFF616161),
          border: const Color(0xFFE0E0E0),
          badge: 'Belum Ada',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _statusColors();
    final lic = state.license;
    final isNone = state.key == _MinePermitStateKey.none;
    final isExpired = state.key == _MinePermitStateKey.expired;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: isExpired ? Colors.red.shade100 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ],
        ),
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
              child: const Icon(Icons.badge_outlined,
                  color: Color(0xFF1E88E5), size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Mine Permit',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 4),
                  if (isNone)
                    Text('Tap untuk ajukan',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13))
                  else ...[
                    Text('No. ${lic?.licenseNumber ?? '-'}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 13)),
                    if ((lic?.issuer ?? '').isNotEmpty)
                      Text('Penerbit: ${lic!.issuer}',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 13)),
                    if ((lic?.expiredAt ?? '').isNotEmpty)
                      Text('Berlaku s/d: ${_formatDetailDate(lic!.expiredAt)}',
                          style: TextStyle(
                              color: Colors.grey.shade400, fontSize: 12)),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: colors.bg,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: colors.fg.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    colors.badge,
                    style: TextStyle(
                      color: colors.fg,
                      fontWeight: FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
                if (isExpired) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                          color:
                              const Color(0xFFD32F2F).withValues(alpha: 0.3)),
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
  }
}

class _LicenseContent extends StatelessWidget {
  final List<UserLicense> licenses;
  final Function(UserLicense) onDetail;
  final VoidCallback onAdd;
  final Function(UserLicense) onEdit;
  final Function(UserLicense) onDelete;
  final _MinePermitState minePermitState;
  final VoidCallback onMinePermitTap;

  const _LicenseContent({
    required this.licenses,
    required this.onDetail,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
    required this.minePermitState,
    required this.onMinePermitTap,
  });

  @override
  Widget build(BuildContext context) {
    final nonMinePermit =
        licenses.where((l) => !_MinePermitState._isMinePermit(l)).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          _MinePermitCard(state: minePermitState, onTap: onMinePermitTap),
          ...nonMinePermit.map((l) {
            final isAktif = l.isActive;
            final approvalStatus = l.approvalStatus.toLowerCase();
            final approvalStyle = approvalStatusStyle(approvalStatus);
            return InkWell(
              onTap: () => onDetail(l),
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
                                  builder: (ctx) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.error_outline,
                                                color: Colors.red.shade400,
                                                size: 32),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Alasan Penolakan Lisensi',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            l.rejectionReason!.trim(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                                height: 1.5),
                                          ),
                                          const SizedBox(height: 24),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1A56C4),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Text('Tutup',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                  color:
                                      Color(0xFFD32F2F).withValues(alpha: 0.3)),
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
  final Function(UserCertification) onDetail;
  final VoidCallback onAdd;
  final Function(UserCertification) onEdit;
  final Function(UserCertification) onDelete;

  const _CertificationContent({
    required this.certifications,
    required this.onDetail,
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
              onTap: () => onDetail(c),
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
                                  builder: (ctx) => Dialog(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(16),
                                            decoration: BoxDecoration(
                                              color: Colors.red.shade50,
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(Icons.error_outline,
                                                color: Colors.red.shade400,
                                                size: 32),
                                          ),
                                          const SizedBox(height: 16),
                                          const Text(
                                            'Alasan Penolakan Sertifikat',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            c.rejectionReason!.trim(),
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade700,
                                                height: 1.5),
                                          ),
                                          const SizedBox(height: 24),
                                          SizedBox(
                                            width: double.infinity,
                                            child: ElevatedButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    const Color(0xFF1A56C4),
                                                foregroundColor: Colors.white,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        vertical: 12),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                                elevation: 0,
                                              ),
                                              child: const Text('Tutup',
                                                  style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.bold)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
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
                                  color:
                                      Color(0xFFEF6C00).withValues(alpha: 0.3)),
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
  final Function(UserViolation) onDetail;

  const _ViolationContent({
    required this.violations,
    required this.onDetail,
  });

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
              onTap: () => onDetail(v),
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
                            border:
                                Border.all(color: color.withValues(alpha: 0.3)),
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

// ignore: unused_element
class _ViolationDetailSheet extends StatelessWidget {
  final UserViolation violation;

  const _ViolationDetailSheet({required this.violation});

  static const _activeColor = Color(0xFFD32F2F);
  static const _inactiveColor = Color(0xFF757575);

  bool get _isActive => violation.status.toLowerCase() == 'aktif';

  Color get _accent => _isActive ? _activeColor : _inactiveColor;

  Color get _statusBg =>
      _isActive ? const Color(0xFFFFEBEE) : const Color(0xFFF5F5F5);

  String _displayValue(String? value) {
    final text = value?.trim();
    return (text != null && text.isNotEmpty) ? text : '-';
  }

  String _formatDateText(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return '-';
    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed == null) return text;
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final local = parsed.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final fileUrl = normalizeStorageUrl(violation.fileUrl)?.trim() ?? '';
    final sheetHeight = MediaQuery.of(context).size.height * 0.85;
    final expiry =
        DateTime.tryParse((violation.expiredAt ?? '').replaceFirst(' ', 'T'))
            ?.toLocal();
    final isExpired =
        !violation.isPermanent && expiry != null && expiry.isBefore(DateTime.now());

    return SizedBox(
      height: sheetHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFF0F0F0),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                    child: ReportStyleDetailHero(
                      imageUrl: fileUrl,
                      accentColor: _accent,
                      fallbackIcon: Icons.warning_amber_rounded,
                      height: 200,
                      badges: [
                        ReportStyleDetailBadge(
                          label: violation.status,
                          color: _accent,
                          backgroundColor: _statusBg,
                        ),
                        ReportStyleDetailBadge(
                          label: 'PELANGGARAN',
                          color: _accent,
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ReportStyleDetailCard(
                          margin: EdgeInsets.zero,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                violation.title,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'PELANGGARAN',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _accent,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Divider(height: 24),
                              ReportStyleDetailRow(
                                icon: Icons.description_outlined,
                                label: 'Deskripsi',
                                value: _displayValue(violation.description),
                              ),
                              const SizedBox(height: 12),
                              ReportStyleDetailRow(
                                icon: Icons.location_on_outlined,
                                label: 'Lokasi',
                                value: _displayValue(violation.location),
                              ),
                              const SizedBox(height: 12),
                              ReportStyleDetailRow(
                                icon: Icons.event_outlined,
                                label: 'Tanggal Pelanggaran',
                                value:
                                    _formatDateText(violation.dateOfViolation),
                              ),
                              const SizedBox(height: 12),
                              ReportStyleDetailRow(
                                icon: Icons.event_busy_outlined,
                                label: 'Berlaku Sampai',
                                value: violation.isPermanent
                                    ? 'Permanen'
                                    : _formatDateText(violation.expiredAt),
                                valueColor: isExpired ? _accent : null,
                              ),
                              const SizedBox(height: 12),
                              ReportStyleDetailRow(
                                icon: Icons.info_outline,
                                label: 'Status',
                                value: _displayValue(violation.status),
                                valueColor: _accent,
                              ),
                            ],
                          ),
                        ),
                        if ((violation.sanction ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailCard(
                            margin: EdgeInsets.zero,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const ReportStyleSectionHeader(
                                  icon: Icons.gavel_rounded,
                                  title: 'Sanksi',
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFEBEE),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFFFCDD2),
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: _accent,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          violation.sanction!.trim(),
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFFB71C1C),
                                            height: 1.35,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0),
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A56C4),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Tutup'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _detailDisplayValue(dynamic value) {
  final text = parseNullableDisplayName(value?.toString())?.trim();
  return (text != null && text.isNotEmpty) ? text : '-';
}

String _firstDetailValue(List<dynamic> values) {
  for (final value in values) {
    final text = parseNullableDisplayName(value?.toString())?.trim();
    if (text != null && text.isNotEmpty && text != '-') return text;
  }
  return '-';
}

String _formatDetailDate(String? raw, {bool includeTime = false}) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return '-';
  final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
  if (parsed == null) return text;
  return DateFormat(includeTime ? 'dd MMM yyyy, HH:mm' : 'dd MMM yyyy')
      .format(parsed.toLocal());
}

class _ApplicantDetailCard extends StatelessWidget {
  final ProfileData? profileData;
  final Map<String, dynamic>? cachedUser;

  const _ApplicantDetailCard({
    required this.profileData,
    required this.cachedUser,
  });

  @override
  Widget build(BuildContext context) {
    return ReportStyleDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReportStyleSectionHeader(
            icon: Icons.person_outline,
            title: 'Informasi Pemohon',
          ),
          const SizedBox(height: 12),
          ReportStyleDetailRow(
            icon: Icons.person_outline,
            label: 'Pemohon',
            value: _firstDetailValue([
              profileData?.fullName,
              cachedUser?['full_name'],
              cachedUser?['name'],
            ]),
          ),
          const SizedBox(height: 12),
          ReportStyleDetailRow(
            icon: Icons.apartment_outlined,
            label: 'Departemen',
            value: _firstDetailValue(
                [profileData?.department, cachedUser?['department']]),
          ),
          const SizedBox(height: 12),
          ReportStyleDetailRow(
            icon: Icons.business_outlined,
            label: 'Perusahaan',
            value: _firstDetailValue(
                [profileData?.company, cachedUser?['company']]),
          ),
          const SizedBox(height: 12),
          ReportStyleDetailRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: _firstDetailValue([
              profileData?.personalEmail,
              profileData?.workEmail,
              cachedUser?['personal_email'],
              cachedUser?['work_email'],
            ]),
          ),
          const SizedBox(height: 12),
          ReportStyleDetailRow(
            icon: Icons.badge_outlined,
            label: 'NIP',
            value: _firstDetailValue(
                [profileData?.employeeId, cachedUser?['employee_id']]),
          ),
          const SizedBox(height: 12),
          ReportStyleDetailRow(
            icon: Icons.work_outline,
            label: 'Jabatan',
            value: _firstDetailValue([
              profileData?.position,
              profileData?.jabatan,
              cachedUser?['position'],
            ]),
          ),
          const SizedBox(height: 12),
          ReportStyleDetailRow(
            icon: Icons.phone_outlined,
            label: 'Telepon',
            value: _firstDetailValue(
                [profileData?.phoneNumber, cachedUser?['phone_number']]),
          ),
        ],
      ),
    );
  }
}

class _ProfileDetailAction {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileDetailAction({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
}

class _ProfileDetailRouteScaffold extends StatelessWidget {
  final String title;
  final String fabHeroTag;
  final String actionSheetTitle;
  final List<_ProfileDetailAction> actions;
  final Widget body;

  const _ProfileDetailRouteScaffold({
    required this.title,
    required this.fabHeroTag,
    required this.actionSheetTitle,
    required this.actions,
    required this.body,
  });

  void _onTabTapped(BuildContext context, int index) {
    Navigator.pushReplacement(
      context,
      _FadePageRoute(builder: (_) => MainScreen(initialIndex: index)),
    );
  }

  void _openActionSheet(BuildContext context) {
    if (actions.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProfileDetailActionSheet(
        title: actionSheetTitle,
        actions: actions,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActions = actions.isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      extendBody: true,
      floatingActionButtonAnimator: FloatingActionButtonAnimator.noAnimation,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        heroTag: fabHeroTag,
        onPressed: hasActions ? () => _openActionSheet(context) : null,
        backgroundColor:
            hasActions ? const Color(0xFF1A56C4) : Colors.grey.shade400,
        foregroundColor: Colors.white,
        shape: const CircleBorder(),
        elevation: hasActions ? 4 : 0,
        tooltip: hasActions ? actionSheetTitle : 'Tidak ada aksi tersedia',
        child: const Icon(Icons.edit_outlined, size: 26),
      ),
      bottomNavigationBar: FabNotchedBottomBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _ProfileNavItem(
              icon: Icons.home,
              label: 'Home',
              index: 0,
              currentIndex: -1,
              onTap: (index) => _onTabTapped(context, index),
            ),
            _ProfileNavItem(
              icon: Icons.article_outlined,
              label: 'News',
              index: 1,
              currentIndex: -1,
              onTap: (index) => _onTabTapped(context, index),
            ),
            const SizedBox(width: 56),
            _ProfileNavItem(
              icon: Icons.inbox_outlined,
              label: 'Inbox',
              index: 3,
              currentIndex: -1,
              onTap: (index) => _onTabTapped(context, index),
            ),
            _ProfileNavItem(
              icon: Icons.menu,
              label: 'Menu',
              index: 4,
              currentIndex: -1,
              onTap: (index) => _onTabTapped(context, index),
            ),
          ],
        ),
      ),
      appBar: AppBar(
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: body,
    );
  }
}

class _ProfileDetailActionSheet extends StatelessWidget {
  final String title;
  final List<_ProfileDetailAction> actions;

  const _ProfileDetailActionSheet({
    required this.title,
    required this.actions,
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
            offset: const Offset(0, -4),
          ),
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
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var i = 0; i < actions.length; i++) ...[
            _ProfileMenuTile(
              icon: actions[i].icon,
              iconBgColor: actions[i].iconBgColor,
              iconColor: actions[i].iconColor,
              title: actions[i].title,
              subtitle: actions[i].subtitle,
              onTap: () {
                Navigator.pop(context);
                actions[i].onTap();
              },
            ),
            if (i < actions.length - 1)
              Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          ],
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
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
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

class _LicenseDetailPage extends StatelessWidget {
  final UserLicense license;
  final ProfileData? profileData;
  final Map<String, dynamic>? cachedUser;
  final Function(UserLicense) onEdit;
  final Function(UserLicense) onDelete;

  const _LicenseDetailPage({
    required this.license,
    this.profileData,
    this.cachedUser,
    required this.onEdit,
    required this.onDelete,
  });

  List<_ProfileDetailAction> _buildActions(BuildContext context) {
    // Mine Permit actions live on the profile screen card, not here.
    if (license.licenseType == 'mine_permit') {
      return const [];
    }

    // Regular licenses: existing logic
    if (license.approvalStatus.toLowerCase() == 'rejected') {
      return [
        _ProfileDetailAction(
          icon: Icons.edit_note,
          iconBgColor: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1A56C4),
          title: 'Edit & Pengajuan Ulang',
          subtitle: 'Perbaiki data lisensi lalu ajukan ulang',
          onTap: () => onEdit(license),
        ),
      ];
    }

    if (license.approvalStatus.toLowerCase() == 'pending_changes') {
      return [
        _ProfileDetailAction(
          icon: Icons.edit,
          iconBgColor: const Color(0xFFFFF8E1),
          iconColor: const Color(0xFFE65100),
          title: 'Edit Lisensi',
          subtitle: 'Pengajuan perubahan sedang ditinjau admin',
          onTap: () => onEdit(license),
        ),
        _ProfileDetailAction(
          icon: Icons.delete_outline,
          iconBgColor: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
          title: 'Hapus Lisensi',
          subtitle: 'Batalkan pengajuan dan hapus lisensi',
          onTap: () => onDelete(license),
        ),
      ];
    }

    if (license.approvalStatus.toLowerCase() == 'pending_changes') {
      return [
        _ProfileDetailAction(
          icon: Icons.edit,
          iconBgColor: const Color(0xFFFFF8E1),
          iconColor: const Color(0xFFE65100),
          title: 'Edit Lisensi',
          subtitle: 'Pengajuan perubahan sedang ditinjau admin',
          onTap: () => onEdit(license),
        ),
        _ProfileDetailAction(
          icon: Icons.delete_outline,
          iconBgColor: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
          title: 'Hapus Lisensi',
          subtitle: 'Batalkan pengajuan dan hapus lisensi',
          onTap: () => onDelete(license),
        ),
      ];
    }

    if (!license.isActive) {
      return [
        _ProfileDetailAction(
          icon: Icons.history,
          iconBgColor: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1E88E5),
          title: 'Perpanjang Lisensi',
          subtitle: 'Perbarui masa berlaku lisensi',
          onTap: () => onEdit(license),
        ),
        _ProfileDetailAction(
          icon: Icons.delete_outline,
          iconBgColor: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
          title: 'Hapus Lisensi',
          subtitle: 'Hapus data lisensi ini',
          onTap: () => onDelete(license),
        ),
      ];
    }

    return [
      _ProfileDetailAction(
        icon: Icons.edit,
        iconBgColor: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1A56C4),
        title: 'Edit Lisensi',
        subtitle: 'Perbarui detail dan lampiran lisensi',
        onTap: () => onEdit(license),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final approvalStyle = approvalStatusStyle(license.approvalStatus);
    const typeColor = Color(0xFFEF6C00);
    final expiry =
        DateTime.tryParse((license.expiredAt ?? '').replaceFirst(' ', 'T'))
            ?.toLocal();
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());
    final imageUrl = normalizeStorageUrl(license.fileUrl)?.trim() ?? '';

    return _ProfileDetailRouteScaffold(
      title: 'Detail Lisensi',
      fabHeroTag: 'license_detail_fab_${license.id}',
      actionSheetTitle: 'Pilih Aksi Lisensi',
      actions: _buildActions(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportStyleDetailHero(
              imageUrl: imageUrl,
              accentColor: typeColor,
              fallbackIcon: Icons.badge_outlined,
              badges: [
                ReportStyleDetailBadge(
                  label: approvalStyle.label,
                  color: approvalStyle.fg,
                ),
                const ReportStyleDetailBadge(
                    label: 'Lisensi', color: typeColor),
                if (!license.isActive)
                  const ReportStyleDetailBadge(
                    label: 'Expired',
                    color: Color(0xFFD32F2F),
                    backgroundColor: Color(0xFFFFEBEE),
                  ),
              ],
            ),
            Padding(
              padding: AppSafeInsets.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReportStyleDetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          license.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Lisensi',
                          style: TextStyle(
                            fontSize: 13,
                            color: typeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Divider(height: 24),
                        ReportStyleDetailRow(
                          icon: Icons.numbers,
                          label: 'Nomor Lisensi',
                          value: _detailDisplayValue(license.licenseNumber),
                        ),
                        if ((license.vehicleEquipment ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.local_shipping_outlined,
                            label: 'Vehicle Equipment',
                            value:
                                _detailDisplayValue(license.vehicleEquipment),
                          ),
                        ],
                        if ((license.simIndonesiaType ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.credit_card_outlined,
                            label: 'SIM Indonesia',
                            value:
                                _detailDisplayValue(license.simIndonesiaType),
                          ),
                        ],
                        if ((license.simType ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.verified_user_outlined,
                            label: 'SIM Type (LIC)',
                            value: _detailDisplayValue(license.simType),
                          ),
                        ],
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.business_outlined,
                          label: 'Lembaga Penerbit',
                          value: _detailDisplayValue(license.issuer),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.info_outline,
                          label: 'Status Approval',
                          value: approvalStyle.label,
                          valueColor: approvalStyle.fg,
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.flag_outlined,
                          label: 'Status Dokumen',
                          value: license.isActive ? 'Aktif' : 'Expired',
                          valueColor: license.isActive
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD32F2F),
                        ),
                        if ((license.submittedAt ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.access_time,
                            label: 'Tanggal Pengajuan',
                            value: _formatDetailDate(
                              license.submittedAt,
                              includeTime: true,
                            ),
                          ),
                        ],
                        if ((license.reviewedAt ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.history,
                            label: 'Tanggal Review',
                            value: _formatDetailDate(
                              license.reviewedAt,
                              includeTime: true,
                            ),
                          ),
                        ],
                        if ((license.reviewedByName ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.verified_user_outlined,
                            label: 'Direview oleh',
                            value: license.reviewedByName!,
                          ),
                        ],
                        if ((license.rejectionReason ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFC62828),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Alasan Penolakan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        license.rejectionReason!.trim(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ReportStyleDetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ReportStyleSectionHeader(
                          icon: Icons.badge_outlined,
                          title: 'Detail Lisensi',
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.label_outline,
                          label: 'Nama',
                          value: _detailDisplayValue(license.name),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.numbers,
                          label: 'Nomor Lisensi',
                          value: _detailDisplayValue(license.licenseNumber),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.business_outlined,
                          label: 'Lembaga Penerbit',
                          value: _detailDisplayValue(license.issuer),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_outlined,
                          label: 'Tanggal Diperoleh',
                          value: _formatDetailDate(license.obtainedAt),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_busy_outlined,
                          label: 'Berlaku Sampai',
                          value: _formatDetailDate(license.expiredAt),
                          valueColor:
                              isExpired ? const Color(0xFFF44336) : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ApplicantDetailCard(
                    profileData: profileData,
                    cachedUser: cachedUser,
                  ),
                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(
                      context,
                      gap: 24,
                    ),
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

class _MinePermitDetailPage extends StatelessWidget {
  final _MinePermitState state;
  final ProfileData? profileData;
  final Map<String, dynamic>? cachedUser;
  final Future<bool> Function() onAction;

  const _MinePermitDetailPage({
    required this.state,
    this.profileData,
    this.cachedUser,
    required this.onAction,
  });

  Future<void> _runAction(BuildContext context) async {
    final changed = await onAction();
    if (changed && context.mounted) {
      Navigator.pop(context);
    }
  }

  List<_ProfileDetailAction> _buildActions(BuildContext context) {
    switch (state.key) {
      case _MinePermitStateKey.none:
        return [
          _ProfileDetailAction(
            icon: Icons.add_card,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1A56C4),
            title: 'Ajukan Mine Permit',
            subtitle: 'Data diambil otomatis dari profil Anda',
            onTap: () => _runAction(context),
          ),
        ];
      case _MinePermitStateKey.pending:
      case _MinePermitStateKey.pendingChanges:
        return const [];
      case _MinePermitStateKey.approvedLocked:
        return [
          _ProfileDetailAction(
            icon: Icons.lock_clock,
            iconBgColor: const Color(0xFFE8F5E9),
            iconColor: const Color(0xFF2E7D32),
            title: 'Perpanjang Mine Permit',
            subtitle: 'Belum tersedia — masih dalam masa berlaku',
            onTap: () => _runAction(context),
          ),
        ];
      case _MinePermitStateKey.approvedRenewable:
        return [
          _ProfileDetailAction(
            icon: Icons.refresh,
            iconBgColor: const Color(0xFFFFF8E1),
            iconColor: const Color(0xFFE65100),
            title: 'Perpanjang Mine Permit',
            subtitle: 'Masa berlaku akan segera habis',
            onTap: () => _runAction(context),
          ),
        ];
      case _MinePermitStateKey.expired:
        return [
          _ProfileDetailAction(
            icon: Icons.add_card,
            iconBgColor: const Color(0xFFFFEBEE),
            iconColor: const Color(0xFFD32F2F),
            title: 'Ajukan Mine Permit Baru',
            subtitle: 'Masa berlaku telah habis',
            onTap: () => _runAction(context),
          ),
        ];
      case _MinePermitStateKey.rejected:
        return [
          _ProfileDetailAction(
            icon: Icons.refresh,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1A56C4),
            title: 'Ajukan Ulang',
            subtitle: 'Submit ulang pengajuan Mine Permit',
            onTap: () => _runAction(context),
          ),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final lic = state.license;

    if (state.key == _MinePermitStateKey.none || lic == null) {
      return _ProfileDetailRouteScaffold(
        title: 'Detail Mine Permit',
        fabHeroTag: 'mine_permit_detail_fab_none',
        actionSheetTitle: 'Pilih Aksi Mine Permit',
        actions: _buildActions(context),
        body: SingleChildScrollView(
          padding: AppSafeInsets.pagePadding(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              ReportStyleDetailCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.shield_outlined,
                          color: Color(0xFF1A56C4), size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Belum Ada Mine Permit',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Mine Permit dibutuhkan untuk ekspor ID Card dan akses area tambang. Pengajuan diproses otomatis dari data profil Anda.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              _ApplicantDetailCard(
                profileData: profileData,
                cachedUser: cachedUser,
              ),
              SizedBox(
                height: AppSafeInsets.bottomNavScrollPadding(
                  context,
                  gap: 24,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final approvalStyle = approvalStatusStyle(lic.approvalStatus);
    const typeColor = Color(0xFF1A56C4);
    final expiry =
        DateTime.tryParse((lic.expiredAt ?? '').replaceFirst(' ', 'T'))
            ?.toLocal();
    final now = DateTime.now();
    final isExpired = expiry != null && expiry.isBefore(now);
    final imageUrl = normalizeStorageUrl(lic.fileUrl)?.trim() ?? '';

    String? renewalHint;
    if (state.key == _MinePermitStateKey.approvedRenewable && expiry != null) {
      final daysLeft = expiry.difference(now).inDays;
      renewalHint = 'Sisa $daysLeft hari sebelum berakhir';
    } else if (state.key == _MinePermitStateKey.approvedLocked &&
        expiry != null) {
      final renewalOpen = DateTime(expiry.year, expiry.month - 1, expiry.day);
      final daysToOpen = renewalOpen.difference(now).inDays;
      renewalHint = 'Perpanjangan tersedia dalam $daysToOpen hari';
    }

    return _ProfileDetailRouteScaffold(
      title: 'Detail Mine Permit',
      fabHeroTag: 'mine_permit_detail_fab_${lic.id}',
      actionSheetTitle: 'Pilih Aksi Mine Permit',
      actions: _buildActions(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportStyleDetailHero(
              imageUrl: imageUrl,
              accentColor: typeColor,
              fallbackIcon: Icons.shield_outlined,
              badges: [
                ReportStyleDetailBadge(
                  label: approvalStyle.label,
                  color: approvalStyle.fg,
                ),
                const ReportStyleDetailBadge(label: 'SIMPER', color: typeColor),
                if (isExpired)
                  const ReportStyleDetailBadge(
                    label: 'Expired',
                    color: Color(0xFFD32F2F),
                    backgroundColor: Color(0xFFFFEBEE),
                  ),
              ],
            ),
            Padding(
              padding: AppSafeInsets.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReportStyleDetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mine Permit',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Izin Tambang (SIMPER)',
                          style: TextStyle(
                            fontSize: 13,
                            color: typeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Divider(height: 24),
                        ReportStyleDetailRow(
                          icon: Icons.numbers,
                          label: 'Nomor Permit',
                          value: _detailDisplayValue(lic.licenseNumber),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.business_outlined,
                          label: 'Lembaga Penerbit',
                          value: _detailDisplayValue(lic.issuer),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.info_outline,
                          label: 'Status Approval',
                          value: approvalStyle.label,
                          valueColor: approvalStyle.fg,
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.flag_outlined,
                          label: 'Status Dokumen',
                          value: lic.isActive ? 'Aktif' : 'Expired',
                          valueColor: lic.isActive
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFD32F2F),
                        ),
                        if ((lic.submittedAt ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.access_time,
                            label: 'Tanggal Pengajuan',
                            value: _formatDetailDate(
                              lic.submittedAt,
                              includeTime: true,
                            ),
                          ),
                        ],
                        if ((lic.reviewedAt ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.history,
                            label: 'Tanggal Review',
                            value: _formatDetailDate(
                              lic.reviewedAt,
                              includeTime: true,
                            ),
                          ),
                        ],
                        if ((lic.reviewedByName ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.verified_user_outlined,
                            label: 'Direview oleh',
                            value: lic.reviewedByName!,
                          ),
                        ],
                        if ((lic.rejectionReason ?? '').trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFC62828),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Alasan Penolakan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        lic.rejectionReason!.trim(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ReportStyleDetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ReportStyleSectionHeader(
                          icon: Icons.shield_outlined,
                          title: 'Detail Izin',
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_outlined,
                          label: 'Tanggal Diperoleh',
                          value: _formatDetailDate(lic.obtainedAt),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_busy_outlined,
                          label: 'Berlaku Sampai',
                          value: _formatDetailDate(lic.expiredAt),
                          valueColor:
                              isExpired ? const Color(0xFFF44336) : null,
                        ),
                        if (renewalHint != null) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.timer_outlined,
                            label: 'Perpanjangan',
                            value: renewalHint,
                            valueColor: state.key ==
                                    _MinePermitStateKey.approvedRenewable
                                ? const Color(0xFFE65100)
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ApplicantDetailCard(
                    profileData: profileData,
                    cachedUser: cachedUser,
                  ),
                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(
                      context,
                      gap: 24,
                    ),
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

class _CertificationDetailPage extends StatelessWidget {
  final UserCertification certification;
  final ProfileData? profileData;
  final Map<String, dynamic>? cachedUser;
  final Function(UserCertification) onEdit;
  final Function(UserCertification) onDelete;

  const _CertificationDetailPage({
    required this.certification,
    this.profileData,
    this.cachedUser,
    required this.onEdit,
    required this.onDelete,
  });

  List<_ProfileDetailAction> _buildActions(BuildContext context) {
    if (certification.approvalStatus.toLowerCase() == 'rejected') {
      return [
        _ProfileDetailAction(
          icon: Icons.edit_note,
          iconBgColor: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1A56C4),
          title: 'Edit & Pengajuan Ulang',
          subtitle: 'Perbaiki data sertifikat lalu ajukan ulang',
          onTap: () => onEdit(certification),
        ),
      ];
    }

    if (certification.approvalStatus.toLowerCase() == 'pending_changes') {
      return [
        _ProfileDetailAction(
          icon: Icons.edit,
          iconBgColor: const Color(0xFFFFF8E1),
          iconColor: const Color(0xFFE65100),
          title: 'Edit Sertifikat',
          subtitle: 'Pengajuan perubahan sedang ditinjau admin',
          onTap: () => onEdit(certification),
        ),
        _ProfileDetailAction(
          icon: Icons.delete_outline,
          iconBgColor: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
          title: 'Hapus Sertifikat',
          subtitle: 'Batalkan pengajuan dan hapus sertifikat',
          onTap: () => onDelete(certification),
        ),
      ];
    }

    if (!certification.isActive) {
      return [
        _ProfileDetailAction(
          icon: Icons.history,
          iconBgColor: const Color(0xFFE3F2FD),
          iconColor: const Color(0xFF1E88E5),
          title: 'Perpanjang Sertifikat',
          subtitle: 'Perbarui masa berlaku sertifikat',
          onTap: () => onEdit(certification),
        ),
        _ProfileDetailAction(
          icon: Icons.delete_outline,
          iconBgColor: const Color(0xFFFFEBEE),
          iconColor: const Color(0xFFD32F2F),
          title: 'Hapus Sertifikat',
          subtitle: 'Hapus data sertifikat ini',
          onTap: () => onDelete(certification),
        ),
      ];
    }

    return [
      _ProfileDetailAction(
        icon: Icons.edit,
        iconBgColor: const Color(0xFFE3F2FD),
        iconColor: const Color(0xFF1A56C4),
        title: 'Edit Sertifikat',
        subtitle: 'Perbarui detail dan lampiran sertifikat',
        onTap: () => onEdit(certification),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final approvalStyle = approvalStatusStyle(certification.approvalStatus);
    const typeColor = Color(0xFF6A1B9A);
    final expiry = DateTime.tryParse(
            (certification.expiredAt ?? '').replaceFirst(' ', 'T'))
        ?.toLocal();
    final isExpired = expiry != null && expiry.isBefore(DateTime.now());
    final imageUrl = normalizeStorageUrl(certification.fileUrl)?.trim() ?? '';

    return _ProfileDetailRouteScaffold(
      title: 'Detail Sertifikat',
      fabHeroTag: 'certification_detail_fab_${certification.id}',
      actionSheetTitle: 'Pilih Aksi Sertifikat',
      actions: _buildActions(context),
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportStyleDetailHero(
              imageUrl: imageUrl,
              accentColor: typeColor,
              fallbackIcon: Icons.workspace_premium_outlined,
              badges: [
                ReportStyleDetailBadge(
                  label: approvalStyle.label,
                  color: approvalStyle.fg,
                ),
                const ReportStyleDetailBadge(
                  label: 'Sertifikat',
                  color: typeColor,
                ),
                if (!certification.isActive)
                  const ReportStyleDetailBadge(
                    label: 'Renew',
                    color: Color(0xFFEF6C00),
                    backgroundColor: Color(0xFFFFF3E0),
                  ),
              ],
            ),
            Padding(
              padding: AppSafeInsets.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReportStyleDetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          certification.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sertifikat',
                          style: TextStyle(
                            fontSize: 13,
                            color: typeColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Divider(height: 24),
                        if ((certification.certificationNumber ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          ReportStyleDetailRow(
                            icon: Icons.numbers,
                            label: 'Nomor Sertifikat',
                            value: _detailDisplayValue(
                                certification.certificationNumber),
                          ),
                          const SizedBox(height: 12),
                        ],
                        ReportStyleDetailRow(
                          icon: Icons.business_outlined,
                          label: 'Lembaga Penerbit',
                          value: _detailDisplayValue(certification.issuer),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.info_outline,
                          label: 'Status Approval',
                          value: approvalStyle.label,
                          valueColor: approvalStyle.fg,
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.flag_outlined,
                          label: 'Status Dokumen',
                          value: certification.isActive ? 'Aktif' : 'Expired',
                          valueColor: certification.isActive
                              ? const Color(0xFF2E7D32)
                              : const Color(0xFFEF6C00),
                        ),
                        if ((certification.submittedAt ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.access_time,
                            label: 'Tanggal Pengajuan',
                            value: _formatDetailDate(
                              certification.submittedAt,
                              includeTime: true,
                            ),
                          ),
                        ],
                        if ((certification.reviewedAt ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.history,
                            label: 'Tanggal Review',
                            value: _formatDetailDate(
                              certification.reviewedAt,
                              includeTime: true,
                            ),
                          ),
                        ],
                        if ((certification.reviewedByName ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ReportStyleDetailRow(
                            icon: Icons.verified_user_outlined,
                            label: 'Direview oleh',
                            value: certification.reviewedByName!,
                          ),
                        ],
                        if ((certification.rejectionReason ?? '')
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Color(0xFFC62828),
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Alasan Penolakan',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        certification.rejectionReason!.trim(),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFFC62828),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ReportStyleDetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const ReportStyleSectionHeader(
                          icon: Icons.workspace_premium_outlined,
                          title: 'Detail Sertifikat',
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.label_outline,
                          label: 'Nama',
                          value: _detailDisplayValue(certification.name),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.numbers,
                          label: 'Nomor Sertifikat',
                          value: _detailDisplayValue(
                              certification.certificationNumber),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.business_outlined,
                          label: 'Lembaga Penerbit',
                          value: _detailDisplayValue(certification.issuer),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_outlined,
                          label: 'Tanggal Diperoleh',
                          value: _formatDetailDate(certification.obtainedAt),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_busy_outlined,
                          label: 'Berlaku Sampai',
                          value: _formatDetailDate(certification.expiredAt),
                          valueColor:
                              isExpired ? const Color(0xFFF44336) : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ApplicantDetailCard(
                    profileData: profileData,
                    cachedUser: cachedUser,
                  ),
                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(
                      context,
                      gap: 24,
                    ),
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

class _ViolationDetailPage extends StatelessWidget {
  final UserViolation violation;
  const _ViolationDetailPage({required this.violation});

  @override
  Widget build(BuildContext context) {
    final isAktif = violation.status.toLowerCase() == 'aktif';
    final color = isAktif ? Colors.red.shade700 : Colors.grey.shade700;
    final bgColor = isAktif ? Colors.red.shade50 : Colors.grey.shade100;
    final expiry =
        DateTime.tryParse((violation.expiredAt ?? '').replaceFirst(' ', 'T'))
            ?.toLocal();
    final isExpired =
        !violation.isPermanent && expiry != null && expiry.isBefore(DateTime.now());
    final imageUrl = normalizeStorageUrl(violation.fileUrl)?.trim() ?? '';

    return _ProfileDetailRouteScaffold(
      title: 'Detail Pelanggaran',
      fabHeroTag: 'violation_detail_fab_${violation.id}',
      actionSheetTitle: 'Aksi Pelanggaran',
      actions: const [],
      body: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReportStyleDetailHero(
              imageUrl: imageUrl,
              accentColor: color,
              fallbackIcon: Icons.warning_amber_rounded,
              badges: [
                ReportStyleDetailBadge(
                  label: violation.status,
                  color: color,
                  backgroundColor: bgColor,
                ),
                ReportStyleDetailBadge(label: 'PELANGGARAN', color: color),
              ],
            ),
            Padding(
              padding: AppSafeInsets.pagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ReportStyleDetailCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          violation.title,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'PELANGGARAN',
                          style: TextStyle(
                            fontSize: 13,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Divider(height: 24),
                        ReportStyleDetailRow(
                          icon: Icons.description_outlined,
                          label: 'Deskripsi',
                          value: _detailDisplayValue(violation.description),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.location_on_outlined,
                          label: 'Lokasi',
                          value: _detailDisplayValue(violation.location),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_outlined,
                          label: 'Tanggal Pelanggaran',
                          value: _formatDetailDate(violation.dateOfViolation),
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.event_busy_outlined,
                          label: 'Berlaku Sampai',
                          value: violation.isPermanent
                              ? 'Permanen'
                              : _formatDetailDate(violation.expiredAt),
                          valueColor: isExpired ? color : null,
                        ),
                        const SizedBox(height: 12),
                        ReportStyleDetailRow(
                          icon: Icons.info_outline,
                          label: 'Status',
                          value: _detailDisplayValue(violation.status),
                          valueColor: color,
                        ),
                      ],
                    ),
                  ),
                  if ((violation.sanction ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    ReportStyleDetailCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ReportStyleSectionHeader(
                            icon: Icons.gavel_rounded,
                            title: 'Sanksi',
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(10),
                              border:
                                  Border.all(color: const Color(0xFFFFCDD2)),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: color,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    violation.sanction!.trim(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFFB71C1C),
                                      height: 1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  SizedBox(
                    height: AppSafeInsets.bottomNavScrollPadding(
                      context,
                      gap: 24,
                    ),
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

// ignore: unused_element
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
