import 'package:flutter/material.dart';

import '../services/cloud_save_service.dart';
import '../widgets/draft_action_fab.dart';
import '../widgets/report_style_detail_widgets.dart';

class DraftReportDetailScreen extends StatefulWidget {
  final ReportDraft draft;
  final Future<bool> Function() onSendDraft;
  final Future<bool> Function() onDeleteDraft;

  const DraftReportDetailScreen({
    super.key,
    required this.draft,
    required this.onSendDraft,
    required this.onDeleteDraft,
  });

  @override
  State<DraftReportDetailScreen> createState() => _DraftReportDetailScreenState();
}

class _DraftReportDetailScreenState extends State<DraftReportDetailScreen> {
  bool _isProcessing = false;

  bool get _isHazard => widget.draft.type == DraftType.hazard;

  Color get _accent =>
      _isHazard ? const Color(0xFFF44336) : const Color(0xFF1565C0);

  String get _typeLabel => _isHazard ? 'HAZARD' : 'INSPECTION';

  String get _statusLabel => 'Draft';

  String _v(dynamic raw, {String fallback = '-'}) {
    final value = raw?.toString().trim();
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  bool _hasValue(dynamic raw) {
    final value = raw?.toString().trim();
    return value != null && value.isNotEmpty;
  }

  String _firstImagePath() {
    final photoPaths = widget.draft.data['photoPaths'];
    if (photoPaths is List) {
      for (final path in photoPaths) {
        final raw = path?.toString().trim();
        if (raw != null && raw.isNotEmpty) return raw;
      }
    }
    return _v(widget.draft.data['imagePath'], fallback: '');
  }

  String _severityLabel() {
    final raw = _v(widget.draft.data['severity']);
    switch (raw.toLowerCase()) {
      case 'low':
        return 'Low';
      case 'high':
        return 'High';
      case 'critical':
        return 'Critical';
      default:
        return 'Medium';
    }
  }

  String _resultLabel() {
    final raw = _v(widget.draft.data['result']);
    switch (raw.toLowerCase()) {
      case 'non_compliant':
        return 'Tidak Sesuai';
      case 'needs_follow_up':
        return 'Perlu Tindak Lanjut';
      case 'compliant':
        return 'Sesuai';
      default:
        return raw;
    }
  }

  Future<void> _handleSend() async {
    if (_isProcessing) return;
    setState(() => _isProcessing = true);
    final ok = await widget.onSendDraft();
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft berhasil dikirim.')),
      );
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gagal mengirim draft. Silakan coba lagi.')),
    );
  }

  Future<void> _handleDelete() async {
    if (_isProcessing) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Hapus Draft?'),
        content: const Text(
            'Draft akan dihapus dari penyimpanan lokal dan tidak bisa dikembalikan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    final ok = await widget.onDeleteDraft();
    if (!mounted) return;
    setState(() => _isProcessing = false);
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft berhasil dihapus.')),
      );
      Navigator.pop(context, true);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gagal menghapus draft.')),
    );
  }

  Widget _buildChecklist() {
    final raw = widget.draft.data['checklist'];
    final items = raw is List
        ? raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : const <Map<String, dynamic>>[];
    if (items.isEmpty) return const SizedBox.shrink();

    return ReportStyleDetailCard(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ReportStyleSectionHeader(
            icon: Icons.checklist_rtl,
            title: 'Checklist Inspeksi',
          ),
          const SizedBox(height: 12),
          ...items.map((item) {
            final checked = item['checked'] == true;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    checked ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 18,
                    color: checked ? const Color(0xFF2E7D32) : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _v(item['label']),
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
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

  @override
  Widget build(BuildContext context) {
    final data = widget.draft.data;
    final notes = _isHazard ? _v(data['kronologi']) : _v(data['notes']);
    final imagePath = _firstImagePath();

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
          'Detail Draft',
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
            ReportStyleDetailHero(
              imageUrl: imagePath,
              accentColor: _accent,
              fallbackIcon:
                  _isHazard ? Icons.warning_amber_rounded : Icons.search,
              badges: [
                ReportStyleDetailBadge(
                  label: _statusLabel.toUpperCase(),
                  color: _accent,
                  backgroundColor: _accent.withValues(alpha: 0.1),
                ),
                ReportStyleDetailBadge(
                  label: _typeLabel,
                  color: _accent,
                ),
              ],
            ),
            ReportStyleDetailCard(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _v(widget.draft.title),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _typeLabel,
                    style: TextStyle(
                      fontSize: 13,
                      color: _accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Divider(height: 24),
                  ReportStyleDetailRow(
                    icon: Icons.location_on_outlined,
                    label: 'Lokasi',
                    value: _v(data['location']),
                  ),
                  if (_isHazard) ...[
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.business_outlined,
                      label: 'Perusahaan',
                      value: _v(data['perusahaan']),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.map_outlined,
                      label: 'Area',
                      value: _v(data['area']),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.warning_amber_rounded,
                      label: 'Severity',
                      value: _severityLabel(),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.category_outlined,
                      label: 'Kategori',
                      value: _v(data['kategori']),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.subdirectory_arrow_right,
                      label: 'Subkategori',
                      value: _v(data['subkategori']),
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.map_outlined,
                      label: 'Area',
                      value: _v(data['area']),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.task_alt,
                      label: 'Hasil',
                      value: _resultLabel(),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.person_outline,
                      label: 'Inspector',
                      value: _v(data['inspector']),
                    ),
                  ],
                ],
              ),
            ),
            ReportStyleDetailCard(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ReportStyleSectionHeader(
                    icon: Icons.description_outlined,
                    title: 'Keterangan',
                  ),
                  const SizedBox(height: 10),
                  Text(
                    notes,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.black87,
                      height: 1.45,
                    ),
                  ),
                  if (_isHazard && _hasValue(data['saran'])) ...[
                    const SizedBox(height: 14),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    const Text(
                      'Saran',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _v(data['saran']),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            if (_isHazard)
              ReportStyleDetailCard(
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ReportStyleSectionHeader(
                      icon: Icons.group_outlined,
                      title: 'Penugasan',
                    ),
                    const SizedBox(height: 10),
                    ReportStyleDetailRow(
                      icon: Icons.apartment_outlined,
                      label: 'Departemen',
                      value: _v(data['department']),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.person_add_alt_1_outlined,
                      label: 'PIC',
                      value: _v(data['pic']),
                    ),
                    const SizedBox(height: 8),
                    ReportStyleDetailRow(
                      icon: Icons.report_gmailerrorred_outlined,
                      label: 'Pelaku Pelanggaran',
                      value: _v(data['pelakuPelanggaran']),
                    ),
                  ],
                ),
              ),
            if (!_isHazard) _buildChecklist(),
            const SizedBox(height: 90),
          ],
        ),
      ),
      floatingActionButton: DraftActionFab(
        heroTag: 'draft_report_detail_fab_${widget.draft.id}',
        isProcessing: _isProcessing,
        onSend: _handleSend,
        onDelete: _handleDelete,
      ),
    );
  }
}
