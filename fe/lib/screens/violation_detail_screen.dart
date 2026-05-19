import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../widgets/report_style_detail_widgets.dart';

class ViolationDetailScreen extends StatelessWidget {
  final UserViolation violation;

  const ViolationDetailScreen({
    super.key,
    required this.violation,
  });

  static const _danger = Color(0xFFD32F2F);

  bool get _isActive => violation.status.toLowerCase() == 'aktif';

  String _displayValue(String? value) {
    final v = value?.trim();
    return (v != null && v.isNotEmpty) ? v : '-';
  }

  DateTime? _parseDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.replaceFirst(' ', 'T'))?.toLocal();
  }

  String _formatDate(DateTime dt, {bool withTime = true}) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun',
      'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'
    ];
    if (!withTime) {
      return '${dt.day} ${months[dt.month - 1]} ${dt.year}';
    }
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatDateText(String? raw, {bool withTime = false}) {
    final dt = _parseDate(raw);
    if (dt == null) return _displayValue(raw);
    return _formatDate(dt, withTime: withTime);
  }

  Widget _buildHeroArea() {
    return ReportStyleDetailHero(
      imageUrl: (violation.fileUrl ?? '').trim(),
      accentColor: _danger,
      fallbackIcon: Icons.warning_amber_rounded,
      badges: [
        ReportStyleDetailBadge(
          label: violation.status,
          color: _isActive ? _danger : const Color(0xFF616161),
          backgroundColor:
              _isActive ? const Color(0xFFFFEBEE) : const Color(0xFFF5F5F5),
        ),
        const ReportStyleDetailBadge(
          label: 'PELANGGARAN',
          color: _danger,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final expiry = _parseDate(violation.expiredAt);
    final expired = expiry != null && expiry.isBefore(DateTime.now());

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detail Pelanggaran',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeroArea(),
            ReportStyleDetailCard(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
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
                  const Text(
                    'PELANGGARAN',
                    style: TextStyle(
                      fontSize: 13,
                      color: _danger,
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
                    value: _formatDateText(violation.dateOfViolation),
                  ),
                  const SizedBox(height: 12),
                  ReportStyleDetailRow(
                    icon: Icons.event_busy_outlined,
                    label: 'Berlaku Sampai',
                    value: _formatDateText(violation.expiredAt),
                    valueColor: expired ? _danger : null,
                  ),
                  const SizedBox(height: 12),
                  ReportStyleDetailRow(
                    icon: Icons.info_outline,
                    label: 'Status',
                    value: violation.status,
                    valueColor: _isActive ? _danger : const Color(0xFF616161),
                  ),
                ],
              ),
            ),
            if ((violation.sanction ?? '').trim().isNotEmpty)
              ReportStyleDetailCard(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
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
                        border: Border.all(color: const Color(0xFFFFCDD2)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: _danger,
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
            SizedBox(height: 20 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

