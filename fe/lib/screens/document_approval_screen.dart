import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/approval_service.dart';
import '../models/profile_model.dart';
import '../widgets/app_safe_insets.dart';
import '../widgets/reject_reason_dialog.dart';
import 'license_detail_screen.dart';
import 'certification_detail_screen.dart';

class DocumentApprovalScreen extends StatefulWidget {
  const DocumentApprovalScreen({super.key});

  @override
  State<DocumentApprovalScreen> createState() => _DocumentApprovalScreenState();
}

class _DocumentApprovalScreenState extends State<DocumentApprovalScreen> {
  static const _blue = Color(0xFF1A56C4);
  bool _isLoading = true;
  List<dynamic> _pendingLicenses = [];
  List<dynamic> _pendingCertifications = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingDocuments();
  }

  Future<void> _fetchPendingDocuments() async {
    setState(() => _isLoading = true);
    try {
      final list = await ApprovalService.getPendingApprovals();
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _pendingLicenses = list
            .where((item) => item['item_type'] == 'approval_license')
            .toList();
        _pendingCertifications = list
            .where((item) => item['item_type'] == 'approval_certification')
            .toList();
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveDocument(String type, String id) async {
    setState(() => _isLoading = true);
    final response = type == 'license' 
      ? await ApprovalService.approveLicense(id)
      : await ApprovalService.approveCertification(id);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Dokumen berhasil disetujui!')),
        );
        _fetchPendingDocuments();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyetujui dokumen.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9FA),
        appBar: AppBar(
          title: const Text('Approval Dokumen', 
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          bottom: TabBar(
            labelColor: _blue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: _blue,
            indicatorWeight: 3,
            tabs: [
              Tab(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Lisensi'),
                  if (_pendingLicenses.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildBadge(_pendingLicenses.length),
                  ]
                ],
              )),
              Tab(child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Sertifikasi'),
                  if (_pendingCertifications.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _buildBadge(_pendingCertifications.length),
                  ]
                ],
              )),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildDocumentList('license', _pendingLicenses),
                _buildDocumentList('certification', _pendingCertifications),
              ],
            ),
      ),
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(count.toString(), 
        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDocumentList(String type, List<dynamic> documents) {
    if (documents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            Text('Tidak ada dokumen menunggu approval', 
              style: TextStyle(color: Colors.grey.shade600, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchPendingDocuments,
      child: ListView.builder(
        padding: AppSafeInsets.pagePadding(context),
        itemCount: documents.length,
        itemBuilder: (context, index) {
          final doc = documents[index];
          final user = doc['user'];
          final name = user['full_name'] ?? 'Unknown';
          
          return InkWell(
            onTap: () async {
              if (type == 'license') {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LicenseDetailScreen(
                      license: UserLicense.fromJson(doc),
                      onRefresh: _fetchPendingDocuments,
                      isApprovalMode: true,
                      onApprove: _approveDocument,
                      onReject: _rejectDocument,
                      submitterName: user['full_name']?.toString(),
                      submitterEmployeeId: user['employee_id']?.toString(),
                      submitterDept: user['department']?.toString(),
                      submitterPosition: user['position']?.toString(),
                      submitterCompany: user['company']?.toString(),
                      submitterEmail: user['personal_email']?.toString(),
                      submitterPhone: user['phone_number']?.toString(),
                      submitterPhotoUrl: user['profile_photo']?.toString(),
                    ),
                  ),
                );
              } else {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => CertificationDetailScreen(
                      certification: UserCertification.fromJson(doc),
                      onRefresh: _fetchPendingDocuments,
                      isApprovalMode: true,
                      onApprove: _approveDocument,
                      onReject: _rejectDocument,
                      submitterName: user['full_name']?.toString(),
                      submitterEmployeeId: user['employee_id']?.toString(),
                      submitterDept: user['department']?.toString(),
                      submitterPosition: user['position']?.toString(),
                      submitterCompany: user['company']?.toString(),
                      submitterEmail: user['personal_email']?.toString(),
                      submitterPhone: user['phone_number']?.toString(),
                      submitterPhotoUrl: user['profile_photo']?.toString(),
                    ),
                  ),
                );
              }
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: _blue.withValues(alpha: 0.1),
                        backgroundImage: user['profile_photo'] != null 
                          ? NetworkImage(user['profile_photo']) 
                          : null,
                        child: user['profile_photo'] == null 
                          ? Text(name.substring(0, 1).toUpperCase(), 
                              style: const TextStyle(color: _blue, fontWeight: FontWeight.bold))
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('${user['employee_id']} • ${user['department']}', 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          doc['created_at'] != null
                              ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(doc['created_at'].toString()))
                              : '-',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 10)),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Document Info
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Document Icon/Thumbnail
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: doc['file_url'] != null 
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(doc['file_url'], fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => 
                                  const Icon(Icons.description_outlined, color: Colors.grey),
                              ),
                            )
                          : const Icon(Icons.description_outlined, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(doc['name'] ?? '-', 
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: _blue)),
                                ),
                                const SizedBox(width: 8),
                                _buildApprovalStatusChip(doc['approval_status']?.toString() ?? ''),
                              ],
                            ),
                            const SizedBox(height: 4),
                            _buildInfoRow(Icons.numbers, doc['license_number'] ?? doc['certification_number'] ?? '-'),
                            _buildInfoRow(Icons.business, doc['issuer'] ?? '-'),
                            _buildInfoRow(Icons.calendar_today, 'Berlaku s/d: ${doc['expired_at'] ?? "-"}'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Actions
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _rejectDocument(type, doc['id'].toString()),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Tolak'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => _approveDocument(type, doc['id'].toString()),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
      ),
    );
  }

  Widget _buildApprovalStatusChip(String status) {
    final isPendingChanges = status.toLowerCase() == 'pending_changes';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPendingChanges
            ? const Color(0xFFFFF8E1)
            : const Color(0xFFE3F2FD),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isPendingChanges
              ? const Color(0xFFFFE082)
              : const Color(0xFFBBDEFB),
        ),
      ),
      child: Text(
        isPendingChanges ? 'Perubahan' : 'Baru',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: isPendingChanges
              ? const Color(0xFFE65100)
              : const Color(0xFF2196F3),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade500),
          const SizedBox(width: 6),
          Expanded(
            child: Text(text, 
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectDocument(String type, String id) async {
    final reason = await showRejectReasonDialog(
      context,
      title: 'Tolak Pengajuan',
      confirmLabel: 'Tolak',
    );
    if (reason == null) return;

    setState(() => _isLoading = true);
    final response = type == 'license'
        ? await ApprovalService.rejectLicense(id, reason)
        : await ApprovalService.rejectCertification(id, reason);

    if (mounted) {
      setState(() => _isLoading = false);
      if (response.success) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Dokumen berhasil ditolak')));
        _fetchPendingDocuments();
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Gagal menolak dokumen')));
      }
    }
  }
}
