import '../models/report.dart';

final List<Report> dummyReports = [
  Report(
    id: '1',
    title: 'Rambu Kotor',
    description: 'Rambu keselamatan di area tambang kotor dan tidak terbaca dengan jelas, perlu segera dibersihkan.',
    type: ReportType.hazard,
    severity: ReportSeverity.medium,
    status: ReportStatus.inProgress,
    location: 'Jalan Hauling',
    createdAt: DateTime.now().subtract(const Duration(days: 4)),
    reportedBy: 'Muhammad Faiz',
    imageUrl: 'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=400&q=80',
  ),
  Report(
    id: '2',
    title: 'Barang Workshop Berserakan',
    description: 'Barang-barang workshop berserakan di depan area workshop dan menghambat jalur evakuasi.',
    type: ReportType.hazard,
    severity: ReportSeverity.low,
    status: ReportStatus.open,
    location: 'Depan Workshop',
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
    reportedBy: 'Noor Lintang Bhaskara',
    imageUrl: 'https://images.unsplash.com/photo-1581092921461-eab62e97a780?w=400&q=80',
  ),
  Report(
    id: '3',
    title: 'Barang Workshop Berserakan',
    description: 'Barang-barang workshop berserakan di depan area workshop dan menghambat jalur evakuasi.',
    type: ReportType.inspection,
    severity: ReportSeverity.low,
    status: ReportStatus.closed,
    location: 'Depan Workshop',
    createdAt: DateTime.now().subtract(const Duration(days: 2)),
    reportedBy: 'Noor Lintang Bhaskara',
    imageUrl: 'https://images.unsplash.com/photo-1567789884554-0b844b597180?w=400&q=80',
  ),
  Report(
    id: '4',
    title: 'Kabel Listrik Terkelupas',
    description: 'Kabel listrik di ruang server terkelupas dan berpotensi bahaya sengatan listrik.',
    type: ReportType.hazard,
    severity: ReportSeverity.high,
    status: ReportStatus.open,
    location: 'Ruang Server - Lantai 3',
    createdAt: DateTime.now().subtract(const Duration(days: 3)),
    reportedBy: 'Dewi Kusuma',
    imageUrl: 'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=400&q=80',
  ),
  Report(
    id: '5',
    title: 'Inspeksi Alat Berat Rutin',
    description: 'Inspeksi rutin alat berat excavator nomor 3 di area tambang sektor B.',
    type: ReportType.inspection,
    severity: ReportSeverity.medium,
    status: ReportStatus.inProgress,
    location: 'Area Tambang Sektor B',
    createdAt: DateTime.now().subtract(const Duration(days: 5)),
    reportedBy: 'Rudi Hartono',
    imageUrl: 'https://images.unsplash.com/photo-1611273426858-450d8e3c9fce?w=400&q=80',
  ),
  Report(
    id: '6',
    title: 'Inspeksi Instalasi Listrik',
    description: 'Inspeksi rutin instalasi listrik di area workshop untuk memastikan tidak ada kabel yang terkelupas atau konsleting.',
    type: ReportType.inspection,
    severity: ReportSeverity.high,
    status: ReportStatus.open,
    location: 'Workshop Listrik',
    createdAt: DateTime.now().subtract(const Duration(days: 6)),
    reportedBy: 'Hendra Wijaya',
    imageUrl: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=400&q=80',
  ),
];

// ── Helper to update report status ────────────────────────────────────────
void updateReportStatus(String id, ReportStatus newStatus) {
  final idx = dummyReports.indexWhere((r) => r.id == id);
  if (idx != -1) {
    final r = dummyReports[idx];
    dummyReports[idx] = Report(
      id: r.id,
      title: r.title,
      description: r.description,
      type: r.type,
      severity: r.severity,
      status: newStatus,
      location: r.location,
      createdAt: r.createdAt,
      reportedBy: r.reportedBy,
      imageUrl: r.imageUrl,
    );
  }
}