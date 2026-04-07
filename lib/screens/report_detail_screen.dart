import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/report.dart';
import '../data/dummy_data.dart';

class ReportDetailScreen extends StatefulWidget {
  final Report report;
  const ReportDetailScreen({super.key, required this.report});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Report _report;

  @override
  void initState() {
    super.initState();
    _report = widget.report;
  }

  Color get _severityColor {
    switch (_report.severity) {
      case ReportSeverity.low:
        return const Color(0xFF4CAF50);
      case ReportSeverity.medium:
        return const Color(0xFFFF9800);
      case ReportSeverity.high:
        return const Color(0xFFF44336);
    }
  }

  Color get _statusColor {
    switch (_report.status) {
      case ReportStatus.open:
        return const Color(0xFF4CAF50);   // sama dengan inbox
      case ReportStatus.inProgress:
        return const Color(0xFFFF9800);
      case ReportStatus.closed:
        return const Color(0xFFF44336);   // sama dengan inbox
    }
  }

  String _formatDate(DateTime dt) {
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
      'Des'
    ];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _updateStatus(ReportStatus newStatus) {
    updateReportStatus(_report.id, newStatus);
    setState(() {
      _report = dummyReports.firstWhere((r) => r.id == _report.id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Status laporan diperbarui')),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Detail Laporan',
            style: TextStyle(
                color: Colors.black87,
                fontWeight: FontWeight.bold,
                fontSize: 16)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            SizedBox(
              width: double.infinity,
              height: 220,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _report.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      color: const Color(0xFF37474F),
                      child: const Center(
                        child: CircularProgressIndicator(
                            color: Colors.white38, strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      color: const Color(0xFF37474F),
                      child: const Icon(Icons.image,
                          color: Colors.white24, size: 80),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black54, Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 16,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _severityColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_report.severity.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _statusColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_report.status.label,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Content Card
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_report.title,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(_report.type.label,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A56C4),
                          fontWeight: FontWeight.w500)),
                  const Divider(height: 24),
                  _DetailRow(
                      icon: Icons.description_outlined,
                      label: 'Deskripsi',
                      value: _report.description),
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Lokasi',
                      value: _report.location),
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.person_outline,
                      label: 'Dilaporkan oleh',
                      value: _report.reportedBy),
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.access_time,
                      label: 'Waktu Laporan',
                      value: _formatDate(_report.createdAt)),
                  const SizedBox(height: 12),
                  _DetailRow(
                      icon: Icons.report_problem_outlined,
                      label: 'Tipe',
                      value: _report.type.label),
                ],
              ),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('Laporan telah dibagikan')),
                        );
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: const Text('Bagikan'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1A56C4),
                        side: const BorderSide(color: Color(0xFF1A56C4)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(ReportStatus.closed),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Update Status'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A56C4),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
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

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(fontSize: 11, color: Colors.grey)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
