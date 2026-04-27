import 'package:syncfusion_flutter_xlsio/xlsio.dart';
import '../models/report.dart';
import 'package:intl/intl.dart';
import 'helper/save_helper.dart'
    if (dart.library.html) 'helper/web_save_helper.dart'
    if (dart.library.io) 'helper/mobile_save_helper.dart';


class ExcelService {
  static Future<void> exportReports({
    required List<Report> reports,
    required String title,
    String? dateRange,
  }) async {
    final Workbook workbook = Workbook();
    final Worksheet sheet = workbook.worksheets[0];
    sheet.showGridlines = false;

    // 1. KOP SURAT (Letterhead)
    // Merge cells for header
    final Range headerRange = sheet.getRangeByName('A1:J1');
    headerRange.merge();
    headerRange.setText('PT. BUKIT BAIDURI ENERGI');
    headerRange.cellStyle.fontSize = 16;
    headerRange.cellStyle.bold = true;
    headerRange.cellStyle.hAlign = HAlignType.center;

    final Range addressRange = sheet.getRangeByName('A2:J2');
    addressRange.merge();
    addressRange.setText('Health, Safety, and Environment Department');
    addressRange.cellStyle.fontSize = 11;
    addressRange.cellStyle.hAlign = HAlignType.center;

    final Range titleRange = sheet.getRangeByName('A4:J4');
    titleRange.merge();
    titleRange.setText(title.toUpperCase());
    titleRange.cellStyle.fontSize = 14;
    titleRange.cellStyle.bold = true;
    titleRange.cellStyle.hAlign = HAlignType.center;

    if (dateRange != null) {
      final Range dateRangeCell = sheet.getRangeByName('A5:J5');
      dateRangeCell.merge();
      dateRangeCell.setText('Periode: $dateRange');
      dateRangeCell.cellStyle.hAlign = HAlignType.center;
    }

    // Border line below header
    final Range lineRange = sheet.getRangeByName('A6:J6');
    lineRange.cellStyle.borders.bottom.lineStyle = LineStyle.thin;

    // 2. DATA TABLE HEADER
    int currentRow = 8;
    final List<String> headers = [
      'No',
      'Ticket #',
      'Tgl Laporan',
      'Judul',
      'Lokasi',
      'Tipe',
      'Kategori/Area',
      'Severity/Hasil',
      'Pelapor',
      'Status'
    ];

    for (int i = 0; i < headers.length; i++) {
      final Range cell = sheet.getRangeByIndex(currentRow, i + 1);
      cell.setText(headers[i]);
      cell.cellStyle.bold = true;
      cell.cellStyle.backColor = '#EEEEEE';
      cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
    }

    currentRow++;

    // 3. DATA ROWS
    for (int i = 0; i < reports.length; i++) {
      final report = reports[i];
      final List<dynamic> values = [
        i + 1,
        report.id,
        DateFormat('dd/MM/yyyy').format(report.createdAt),
        report.title,
        report.location,
        report.type.label,
        report.category?.label ?? '-',
        report.type == ReportType.hazard ? report.severity.label : '-',
        report.reportedBy,
        report.status.label,
      ];

      for (int j = 0; j < values.length; j++) {
        final Range cell = sheet.getRangeByIndex(currentRow, j + 1);
        cell.setValue(values[j]);
        cell.cellStyle.borders.all.lineStyle = LineStyle.thin;
      }
      currentRow++;
    }

    // Auto fit columns
    for (int i = 1; i <= headers.length; i++) {
      sheet.autoFitColumn(i);
    }

    // 4. SAVE AND OPEN
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    final String fileName =
        '${title.replaceAll(' ', '_')}_${DateTime.now().millisecondsSinceEpoch}.xlsx';

    await saveAndLaunchFile(bytes, fileName);
  }
}

