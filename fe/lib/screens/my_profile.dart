import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:sapahse/models/profile_model.dart';
import 'package:sapahse/services/profile_service.dart';
import 'package:sapahse/main.dart';

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
        _showEditBiodataForm();
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
    final result = await ProfileService.getProfile();
    if (mounted && result.success) {
      setState(() {
        _profileData = result.data;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _avatarFile = picked);
  }

  final List<Map<String, dynamic>> _subTabs = [
    {'label': 'Biodata', 'icon': Icons.person, 'color': const Color(0xFF1A56C4)},
    {'label': 'Lisensi', 'icon': Icons.badge, 'color': const Color(0xFF1E88E5)},
    {'label': 'Pelanggaran', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFFBC02D)},
    {'label': 'Sertifikat', 'icon': Icons.workspace_premium, 'color': const Color(0xFFF57C00)},
    {'label': 'Medis', 'icon': Icons.medical_services, 'color': const Color(0xFFE91E63)},
  ];

  void _onTabTapped(int index) {
    if (index == 4) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainScreen(initialIndex: index)),
      (route) => false,
    );
  }

  void _openFabMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _ProfileFabMenuSheet(
        onEditBiodata: () { Navigator.pop(context); _showEditBiodataForm(); },
        onAddLicense: () { Navigator.pop(context); _showAddLicenseForm(); },
        onAddCertification: () { Navigator.pop(context); _showAddCertificationForm(); },
        onEditMedical: () { Navigator.pop(context); _showEditMedicalForm(); },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
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
              _ProfileNavItem(icon: Icons.home, label: 'Home', index: 0, currentIndex: 4, onTap: _onTabTapped),
              _ProfileNavItem(icon: Icons.article_outlined, label: 'News', index: 1, currentIndex: 4, onTap: _onTabTapped),
              const SizedBox(width: 48),
              _ProfileNavItem(icon: Icons.inbox_outlined, label: 'Inbox', index: 3, currentIndex: 4, onTap: _onTabTapped),
              _ProfileNavItem(icon: Icons.menu, label: 'Menu', index: 4, currentIndex: 4, onTap: _onTabTapped),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _profileData?.fullName ?? '-';
    final initials = name.split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF1A56C4),
                backgroundImage: _getAvatarImage(),
                child: _avatarFile == null && (_profileData?.profilePhoto == null || _profileData!.profilePhoto!.isEmpty)
                    ? Text(initials, style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold))
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFF1A56C4), shape: BoxShape.circle),
                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('${_profileData?.position ?? "-"} — Dept. ${_profileData?.department ?? "-"}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(_profileData?.company ?? '-', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  ImageProvider? _getAvatarImage() {
    if (_avatarFile != null) {
      return FileImage(File(_avatarFile!.path));
    }
    if (_profileData?.profilePhoto != null && _profileData!.profilePhoto!.isNotEmpty) {
      return NetworkImage(_profileData!.profilePhoto!);
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
                color: isSelected ? tab['color'].withOpacity(0.1) : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isSelected ? tab['color'] : Colors.grey.shade200),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(tab['icon'], color: isSelected ? tab['color'] : Colors.grey.shade400, size: 24),
                  const SizedBox(height: 8),
                  Text(tab['label'],
                      style: TextStyle(
                          color: isSelected ? tab['color'] : Colors.grey.shade600,
                          fontSize: 11,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
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
      case 0: return _BiodataContent(data: _profileData);
      case 1: return _LicenseContent(
        licenses: _profileData?.licenses ?? [],
        onAdd: _showAddLicenseForm,
      );
      case 2: return _ViolationContent(violations: _profileData?.violations ?? []);
      case 3: return _CertificationContent(
        certifications: _profileData?.certifications ?? [],
        onAdd: _showAddCertificationForm,
      );
      case 4: return _MedicalContent(medicals: _profileData?.medicals ?? []);
      default: return const SizedBox();
    }
  }

  void _showEditForm() {
    switch (_selectedSubTab) {
      case 0:
        _showEditBiodataForm();
        break;
      case 1:
        _showAddLicenseForm();
        break;
      case 2:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Data pelanggaran tidak dapat diedit.')));
        break;
      case 3:
        _showAddCertificationForm();
        break;
      case 4:
        _showEditMedicalForm();
        break;
    }
  }

  void _showEditBiodataForm() {
    final phoneCtrl = TextEditingController(text: _profileData?.phoneNumber);
    final emailCtrl = TextEditingController(text: _profileData?.personalEmail);

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
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Edit Biodata', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Nomor Telepon'),
              TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: _buildInputDecoration('Contoh: 08123456789'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Email Pribadi'),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration('Contoh: user@email.com'),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    setState(() => _isLoading = true);
                    
                    final result = await ProfileService.updateProfile(
                      phoneNumber: phoneCtrl.text.isNotEmpty ? phoneCtrl.text : null,
                      personalEmail: emailCtrl.text.isNotEmpty ? emailCtrl.text : null,
                    );
                    
                    if (result.success) {
                      if (mounted) _loadProfile();
                    } else {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.errorMessage ?? 'Gagal menyimpan')));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5C38FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showEditMedicalForm() {
    final medicals = _profileData?.medicals ?? [];
    final latest = medicals.isNotEmpty ? medicals.first : null;
    
    final bloodTypeCtrl = TextEditingController(text: latest?.bloodType);
    final heightCtrl = TextEditingController(text: latest?.height);
    final weightCtrl = TextEditingController(text: latest?.weight);
    final bloodPressureCtrl = TextEditingController(text: latest?.bloodPressure);
    final allergiesCtrl = TextEditingController(text: latest?.allergies);

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
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('Edit Data Medis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const Spacer(),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                      );
                      
                      if (result.success) {
                        if (mounted) _loadProfile();
                      } else {
                        if (mounted) {
                          setState(() => _isLoading = false);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                        }
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5C38FF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: const Text('Simpan Data Medis', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final nameController = TextEditingController();
    final numberController = TextEditingController();
    DateTime? selectedDate;

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
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Tambah Lisensi Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Nama Lisensi (SIM/SIO/SIMPER)'),
              TextField(
                controller: nameController,
                decoration: _buildInputDecoration('Contoh: SIM A, SIO Excavator...'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Nomor Lisensi'),
              TextField(
                controller: numberController,
                decoration: _buildInputDecoration('Contoh: SIM-2024-001234'),
              ),
              _buildFieldLabel('Berlaku Sampai'),
              InkWell(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 365)),
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                  );
                  if (picked != null) setModalState(() => selectedDate = picked);
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
                        selectedDate == null ? 'Pilih Tanggal' : '${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}',
                        style: TextStyle(color: selectedDate == null ? Colors.grey.shade500 : Colors.black),
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
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null) setModalState(() => _licenseImage = picked);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || numberController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi semua data')));
                      return;
                    }
                    
                    Navigator.pop(context); // Close modal
                    setState(() => _isLoading = true);
                    
                    final result = await ProfileService.addLicense(
                      name: nameController.text,
                      licenseNumber: numberController.text,
                      expiredAt: selectedDate != null ? '${selectedDate!.year}-${selectedDate!.month}-${selectedDate!.day}' : null,
                      imageFile: _licenseImage,
                    );
                    
                    if (result.success) {
                      if (mounted) _loadProfile(); // Refresh
                    } else {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Lisensi', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddCertificationForm() {
    final nameController = TextEditingController();
    final issuerController = TextEditingController();
    final yearController = TextEditingController();

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
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('Tambah Sertifikat Baru', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 20),
              _buildFieldLabel('Nama Sertifikat'),
              TextField(
                controller: nameController,
                decoration: _buildInputDecoration('Contoh: Ahli K3 Umum, Basic Safety...'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Lembaga Penerbit'),
              TextField(
                controller: issuerController,
                decoration: _buildInputDecoration('Contoh: Kemnaker RI, BNSP...'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Tahun Perolehan'),
              TextField(
                controller: yearController,
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration('Contoh: 2023'),
              ),
              const SizedBox(height: 16),
              _buildFieldLabel('Foto Sertifikat'),
              _buildImagePicker(
                image: _certImage,
                onTap: () async {
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                  if (picked != null) setModalState(() => _certImage = picked);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.isEmpty || issuerController.text.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harap lengkapi nama dan penerbit')));
                      return;
                    }
                    
                    Navigator.pop(context); // Close modal
                    setState(() => _isLoading = true);
                    
                    final result = await ProfileService.addCertification(
                      name: nameController.text,
                      issuer: issuerController.text,
                      year: int.tryParse(yearController.text),
                      imageFile: _certImage,
                    );
                    
                    if (result.success) {
                      if (mounted) _loadProfile(); // Refresh
                    } else {
                      if (mounted) {
                        setState(() => _isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result.message)));
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A56C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: const Text('Simpan Sertifikat', style: TextStyle(fontWeight: FontWeight.bold)),
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
    child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
  );

  InputDecoration _buildInputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
    filled: true,
    fillColor: Colors.grey.shade50,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF1A56C4))),
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
          border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: image != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(File(image.path), fit: BoxFit.cover),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, color: Colors.grey.shade400, size: 32),
                  const SizedBox(height: 8),
                  Text('Ambil atau Pilih Foto', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  XFile? _licenseImage;
  XFile? _certImage;
}

// ── SUB-TAB WIDGETS (INTERNAL) ──────────────────────────────────────────────

class _BiodataContent extends StatelessWidget {
  final ProfileData? data;
  const _BiodataContent({this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildTitle('CORE DATA'),
          _buildCard([
            _buildRow('NIK', data?.employeeId ?? '-', locked: true),
            _buildRow('Nama Lengkap', data?.fullName ?? '-', locked: true),
            _buildRow('Email', data?.personalEmail ?? '-'),
            _buildRow('Phone', data?.phoneNumber ?? '-'),
            _buildRow('Alamat', 'Jl. Kelapa No. 12, BPN'),
          ]),
          const SizedBox(height: 24),
          _buildTitle('EMPLOYEE DATA'),
          _buildCard([
            _buildRow('Tipe Afiliasi', data?.tipeAfiliasi ?? '-', locked: true),
            _buildRow('Perusahaan Owner', data?.company ?? '-', locked: true),
            if (data?.tipeAfiliasi == 'Kontraktor' || data?.tipeAfiliasi == 'Sub-Kontraktor' || data?.tipeAfiliasi == 'Sub-Kont.')
              _buildRow('Perusahaan Kontraktor', data?.perusahaanKontraktor ?? '-', locked: true),
            if (data?.tipeAfiliasi == 'Sub-Kontraktor' || data?.tipeAfiliasi == 'Sub-Kont.')
              _buildRow('Sub-Kontraktor', data?.subKontraktor ?? '-', locked: true),
            _buildRow('Departemen', data?.department ?? '-', locked: true),
            _buildRow('Jabatan', data?.position ?? '-', locked: true),
          ]),
        ],
      ),
    );
  }

  Widget _buildTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 8),
    child: Text(title, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
  );

  Widget _buildCard(List<Widget> children) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
    child: Column(children: children.asMap().entries.map((e) => Column(children: [
      e.value, if (e.key < children.length - 1) Divider(height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16)
    ])).toList()),
  );

  Widget _buildRow(String label, String value, {bool locked = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 13))
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: Text(
                  value, 
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, height: 1.3)
                )
              ),
              if (locked) ...[
                const SizedBox(width: 6), 
                const Icon(Icons.lock, color: Colors.orange, size: 14)
              ],
            ],
          )
        ),
      ],
    ),
  );
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
            final isAktif = l.status.toLowerCase() == 'active';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isAktif ? Colors.grey.shade200 : Colors.red.shade100),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.badge_outlined, color: Color(0xFF1E88E5), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text('No. ${l.licenseNumber}', style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        if (l.expiredAt != null)
                          Text('Berlaku s/d ${l.expiredAt}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        if (l.fileUrl != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              l.fileUrl!,
                              height: 60,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAktif ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAktif ? 'Aktif' : 'Expired',
                      style: TextStyle(
                        color: isAktif ? const Color(0xFF2E7D32) : const Color(0xFFD32F2F),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Lisensi'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A56C4),
              side: const BorderSide(color: Color(0xFF1A56C4)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}

class _CertificationContent extends StatelessWidget {
  final List<UserCertification> certifications;
  final VoidCallback onAdd;
  const _CertificationContent({required this.certifications, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          ...certifications.map((c) {
            final isAktif = c.status.toLowerCase() == 'active';
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
                ]
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3E5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.workspace_premium_outlined, color: Color(0xFF6A1B9A), size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(c.issuer, style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        if (c.year != null)
                          Text('Tahun: ${c.year}', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        if (c.fileUrl != null) ...[
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              c.fileUrl!,
                              height: 60,
                              width: 100,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const SizedBox(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isAktif ? const Color(0xFFE8F5E9) : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isAktif ? 'Aktif' : 'Renew',
                      style: TextStyle(
                        color: isAktif ? const Color(0xFF2E7D32) : const Color(0xFFEF6C00),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah Sertifikat'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A56C4),
              side: const BorderSide(color: Color(0xFF1A56C4)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
            child: Text('DATA MEDIS', style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold)),
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
                _buildMedicalRow('Alergi', latest?.allergies ?? 'Tidak Ada', isBoldValue: true),
                _buildDivider(),
                _buildMedicalRow('MCU Terakhir', latest?.checkupDate ?? '-'),
                _buildDivider(),
                _buildMedicalRow('Hasil MCU', latest?.result ?? '-'),
                _buildDivider(),
                _buildMedicalRow('MCU Berikutnya', latest?.nextCheckupDate ?? '-'),
                _buildDivider(),
                _buildMedicalRow('Riwayat Penyakit', '-'),
                _buildDivider(),
                _buildMedicalRow('Obat Berjalan', '-'),
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
                const Icon(Icons.lock, color: Colors.orange, size: 16),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Data medis dikelola oleh Klinik & Dokter Perusahaan',
                    style: TextStyle(color: Colors.indigo.shade800, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() => Divider(height: 1, color: Colors.grey.shade100, indent: 16, endIndent: 16);

  Widget _buildMedicalRow(String label, String value, {bool isBoldValue = false}) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: Row(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        const Spacer(),
        Text(
          value, 
          style: TextStyle(
            fontWeight: isBoldValue ? FontWeight.bold : FontWeight.w500, 
            fontSize: 14,
            color: isBoldValue ? Colors.black : Colors.grey.shade700,
          )
        ),
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
              Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text('Tidak ada riwayat pelanggaran', style: TextStyle(color: Colors.grey.shade600)),
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
              style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.bold),
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
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))
                ]
              ),
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
                                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: bgColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            v.status,
                            style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
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
            Icon(icon, color: isActive ? const Color(0xFF1A56C4) : Colors.grey, size: 24),
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
                width: 44, height: 44,
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
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
          BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 8),
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text('Pilih Aksi Profil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87)),
          ),
          const SizedBox(height: 8),

          _ProfileMenuTile(
            icon: Icons.person_outline,
            iconBgColor: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF8E24AA),
            title: 'Edit Biodata',
            subtitle: 'Perbarui nomor telepon & email',
            onTap: onEditBiodata,
          ),
          Divider(height: 1, indent: 72, color: Colors.grey.shade100),
          _ProfileMenuTile(
            icon: Icons.badge_outlined,
            iconBgColor: const Color(0xFFE3F2FD),
            iconColor: const Color(0xFF1E88E5),
            title: 'Tambah Lisensi',
            subtitle: 'Tambahkan SIM/SIO/KIMPER',
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
            title: 'Edit Data Medis',
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.grey.shade200)),
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

