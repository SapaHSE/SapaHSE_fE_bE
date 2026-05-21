import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../models/profile_model.dart';
import 'helper/save_helper.dart'
    if (dart.library.html) 'helper/web_save_helper.dart'
    if (dart.library.io) 'helper/mobile_save_helper.dart';

class IdCardPdfService {
  static const String _idCardLogoPath = 'assets/logo_bbe.jpg';
  static const double _mm = PdfPageFormat.mm;
  static const double _cardWidthMm = 55;
  static const double _cardHeightMm = 86;
  static const double _cardInsetMm = 1.15;
  static final PdfPageFormat _cardFormat =
      PdfPageFormat(_cardWidthMm * _mm, _cardHeightMm * _mm);

  static const PdfColor _blue = PdfColor.fromInt(0xFF2F73C8);
  static const PdfColor _deepBlue = PdfColor.fromInt(0xFF245A9C);
  static const PdfColor _green = PdfColor.fromInt(0xFF28B463);
  static const PdfColor _red = PdfColor.fromInt(0xFFE5506A);
  static const PdfColor _ink = PdfColor.fromInt(0xFF303744);
  static const PdfColor _line = PdfColor.fromInt(0xFF9BA7B8);

  static Future<void> exportMinePermit({
    required ProfileData profile,
    required String qrCode,
  }) async {
    final document = pw.Document();
    final avatar = await _loadNetworkImage(profile.profilePhoto);
    final bbeLogo = await _loadAssetImage(_idCardLogoPath);

    document.addPage(
      pw.Page(
        pageFormat: _cardFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => _frontCard(profile, qrCode, avatar, bbeLogo),
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: _cardFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => _backCard(profile),
      ),
    );

    final bytes = await document.save();
    final safeName = profile.fullName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final fileName =
        'ID_Card_${safeName.isEmpty ? profile.employeeId : safeName}.pdf';

    await saveAndLaunchFile(
      bytes,
      fileName,
      mimeType: 'application/pdf',
    );
  }

  static pw.Widget _frontCard(
    ProfileData profile,
    String qrCode,
    pw.MemoryImage? avatar,
    pw.MemoryImage? bbeLogo,
  ) {
    final positionDepartment = [
      _display(profile.jabatan ?? profile.position, fallback: ''),
      _display(profile.department, fallback: ''),
    ].where((value) => value.isNotEmpty).join(' - ');

    return _printPage(
      child: pw.Stack(
        children: [
          _bbeHeader(bbeLogo),
          _blueTitleBar('MINE PERMIT'),
          pw.Positioned(
            left: 5.2 * _mm,
            top: 27.4 * _mm,
            child: _avatarBox(avatar, profile.fullName),
          ),
          pw.Positioned(
            left: 29.0 * _mm,
            top: 27.3 * _mm,
            child: pw.SizedBox(
              width: 19.6 * _mm,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  _profileLine('Name', _display(profile.fullName)),
                  _profileLine(
                    'Registration Number',
                    _display(profile.simper, fallback: profile.employeeId),
                  ),
                  _profileLine(
                    'Position & Department',
                    positionDepartment.isEmpty ? '-' : positionDepartment,
                  ),
                  _profileLine(
                    'Company',
                    _display(
                      profile.company,
                      fallback: 'PT Bukit Baiduri Energi',
                    ),
                  ),
                  _profileLine('Valid Until', _formatDate(_validUntil())),
                ],
              ),
            ),
          ),
          pw.Positioned(
            left: 5.2 * _mm,
            top: 54.8 * _mm,
            child: pw.SizedBox(
              width: 20.5 * _mm,
              child: _counterBox('VIOLATION'),
            ),
          ),
          pw.Positioned(
            left: 5.2 * _mm,
            top: 63.2 * _mm,
            child: pw.SizedBox(
              width: 20.5 * _mm,
              child: _counterBox('INCIDENT'),
            ),
          ),
          pw.Positioned(
            left: 6.8 * _mm,
            top: 70.7 * _mm,
            child: _signatureBlock(bbeLogo),
          ),
          pw.Positioned(
            right: 5.2 * _mm,
            bottom: 5.1 * _mm,
            child: _qrBlock(qrCode),
          ),
        ],
      ),
    );
  }

  static pw.Widget _backCard(ProfileData profile) {
    return _printPage(
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            right: 0,
            top: 2.1 * _mm,
            child: pw.Text(
              'SIMPER',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _green,
                fontWeight: pw.FontWeight.bold,
                fontSize: 12.0,
              ),
            ),
          ),
          pw.Positioned(
            left: 5 * _mm,
            top: 10.8 * _mm,
            child: pw.SizedBox(
              width: 20.8 * _mm,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'SIM POLISI',
                    style: pw.TextStyle(
                      fontSize: 6.7,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                    ),
                  ),
                  _smallLabelRow('NOMOR', ''),
                  _smallLabelRow('TIPE', ''),
                  _smallLabelRow('EXP. DATE', ''),
                ],
              ),
            ),
          ),
          pw.Positioned(
            left: 29.0 * _mm,
            top: 10.1 * _mm,
            child: pw.Container(width: 0.45, height: 14.2 * _mm, color: _line),
          ),
          pw.Positioned(
            left: 33.0 * _mm,
            top: 10.5 * _mm,
            child: pw.SizedBox(
              width: 15.0 * _mm,
              child: pw.Text(
                'SIMPER\n${_display(profile.simper, fallback: '')}',
                style: pw.TextStyle(
                  fontSize: 6.7,
                  fontWeight: pw.FontWeight.bold,
                  color: _ink,
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: 3.0 * _mm,
            top: 26.2 * _mm,
            child: pw.SizedBox(width: 46.7 * _mm, child: _simperTable(profile)),
          ),
          pw.Positioned(
            left: 4.8 * _mm,
            right: 4.8 * _mm,
            top: 53.8 * _mm,
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _checkboxLabel('PIT AREA'),
                _checkboxLabel('PORT AREA'),
                _checkboxLabel('HANDAK'),
              ],
            ),
          ),
          pw.Positioned(
            left: 4.8 * _mm,
            right: 4.8 * _mm,
            top: 58.4 * _mm,
            child: pw.Container(height: 0.45, color: _line),
          ),
          pw.Positioned(
            left: 4.8 * _mm,
            right: 4.8 * _mm,
            top: 59.0 * _mm,
            child: _rulesBlock(),
          ),
          pw.Positioned(
            left: 4.8 * _mm,
            right: 4.8 * _mm,
            top: 72.4 * _mm,
            child: pw.Container(
              height: 3.2 * _mm,
              alignment: pw.Alignment.center,
              color: _red,
              child: pw.Text(
                'EMERGENCY CONTACT',
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 5.3,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: 4.8 * _mm,
            right: 4.8 * _mm,
            top: 76.6 * _mm,
            child: pw.Container(
              height: 4.9 * _mm,
              alignment: pw.Alignment.center,
              color: _green,
              child: pw.Text(
                'WAJIB MEMATUHI PERATURAN K3LH\nSELAMA BERADA DI JOB SITE',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 5.1,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _printPage({required pw.Widget child}) {
    return pw.Container(
      width: _cardWidthMm * _mm,
      height: _cardHeightMm * _mm,
      color: PdfColors.white,
      padding: pw.EdgeInsets.all(_cardInsetMm * _mm),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          border:
              pw.Border.all(color: PdfColor.fromInt(0xFF4F5E70), width: 0.8),
          borderRadius: pw.BorderRadius.circular(7),
        ),
        child: pw.ClipRRect(
          horizontalRadius: 6.5,
          verticalRadius: 6.5,
          child: child,
        ),
      ),
    );
  }

  static pw.Widget _bbeHeader(pw.MemoryImage? logo) {
    return pw.Positioned(
      left: 0,
      right: 0,
      top: 2.4 * _mm,
      child: pw.Center(
        child: logo == null
            ? pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Container(
                    width: 5.2 * _mm,
                    height: 7.0 * _mm,
                    decoration: pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFF2AB673),
                      borderRadius: pw.BorderRadius.circular(7),
                    ),
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'B',
                      style: pw.TextStyle(
                        color: PdfColors.white,
                        fontWeight: pw.FontWeight.bold,
                        fontSize: 7,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 1.4 * _mm),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'BBE',
                        style: pw.TextStyle(
                          fontSize: 16.2,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                      pw.Text(
                        'PT BUKIT BAIDURI ENERGI',
                        style: pw.TextStyle(
                          fontSize: 2.8,
                          color: _ink,
                        ),
                      ),
                    ],
                  ),
                ],
              )
            : pw.SizedBox(
                width: 30.0 * _mm,
                height: 9.4 * _mm,
                child: pw.Image(logo, fit: pw.BoxFit.cover),
              ),
      ),
    );
  }

  static pw.Widget _blueTitleBar(String title) {
    return pw.Positioned(
      left: 0,
      right: 0,
      top: 15.1 * _mm,
      child: pw.Container(
        height: 8.8 * _mm,
        color: _blue,
        alignment: pw.Alignment.center,
        child: pw.Text(
          title,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 15.2,
          ),
        ),
      ),
    );
  }

  static pw.Widget _avatarBox(pw.MemoryImage? image, String name) {
    return pw.Container(
      width: 20.8 * _mm,
      height: 27.2 * _mm,
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _line, width: 0.6),
        color: PdfColor.fromInt(0xFFEAF0F7),
      ),
      child: image == null
          ? pw.Center(
              child: pw.Text(
                _initials(name),
                style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold,
                  color: _deepBlue,
                ),
              ),
            )
          : pw.Image(image, fit: pw.BoxFit.cover),
    );
  }

  static pw.Widget _profileLine(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 2.1),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 5.0,
              fontStyle: pw.FontStyle.italic,
              fontWeight: pw.FontWeight.bold,
              color: _blue,
            ),
          ),
          pw.Text(
            value,
            maxLines: 2,
            style: pw.TextStyle(
              fontSize: _fitText(value, base: 6.2, small: 5.5, tiny: 4.9),
              lineSpacing: -0.2,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _counterBox(String title) {
    return pw.Column(
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 5.5,
            fontWeight: pw.FontWeight.bold,
            color: _deepBlue,
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.55),
          columnWidths: const {
            0: pw.FlexColumnWidth(),
            1: pw.FlexColumnWidth(),
            2: pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: [1, 2, 3]
                  .map(
                    (n) => pw.Container(
                      height: 4.2 * _mm,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '$n',
                        style: pw.TextStyle(
                          fontSize: 6.1,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ],
    );
  }

  static pw.Widget _signatureBlock(pw.MemoryImage? logo) {
    return pw.SizedBox(
      width: 18.8 * _mm,
      child: pw.Column(
        children: [
          pw.Text(
            'Disahkan oleh,',
            style: pw.TextStyle(
              fontSize: 4.5,
              fontWeight: pw.FontWeight.bold,
              color: _deepBlue,
            ),
          ),
          pw.SizedBox(height: 0.35 * _mm),
          pw.Container(
            width: 12 * _mm,
            height: 2.0 * _mm,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _deepBlue, width: 0.5),
              ),
            ),
          ),
          pw.SizedBox(height: 0.1 * _mm),
          logo == null
              ? pw.Row(
                  mainAxisSize: pw.MainAxisSize.min,
                  children: [
                    pw.Container(
                      width: 3.5 * _mm,
                      height: 4.3 * _mm,
                      decoration: pw.BoxDecoration(
                        color: PdfColor.fromInt(0xFF2AB673),
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                    ),
                    pw.SizedBox(width: 0.8 * _mm),
                    pw.Text(
                      'BBE',
                      style: pw.TextStyle(
                        fontSize: 7.6,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink,
                      ),
                    ),
                  ],
                )
              : pw.SizedBox(
                  width: 13.0 * _mm,
                  height: 4.2 * _mm,
                  child: pw.Image(logo, fit: pw.BoxFit.cover),
                ),
          pw.Text(
            'Reno Barus, S.T',
            style: pw.TextStyle(
              fontSize: 4.1,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.Text(
            'Kepala Teknik Tambang',
            style: pw.TextStyle(
              fontSize: 3.8,
              fontStyle: pw.FontStyle.italic,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _qrBlock(String qrCode) {
    return pw.Container(
      width: 16.8 * _mm,
      padding: const pw.EdgeInsets.all(2.2),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        border: pw.Border.all(color: PdfColor.fromInt(0xFFD5DCE6), width: 0.5),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrCode,
            width: 14.0 * _mm,
            height: 14.0 * _mm,
          ),
          pw.SizedBox(height: 0.6 * _mm),
          pw.Text(
            'SCAN PROFIL',
            style: pw.TextStyle(
              fontSize: 3.8,
              fontWeight: pw.FontWeight.bold,
              color: _deepBlue,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _smallLabelRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(top: 1.25),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 10.2 * _mm,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 4.6,
                fontWeight: pw.FontWeight.bold,
                color: _blue,
              ),
            ),
          ),
          pw.SizedBox(
            width: 2.2 * _mm,
            child: pw.Text(
              ':',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(fontSize: 4.6, color: _ink),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(fontSize: 4.6, color: _ink),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _simperTable(ProfileData profile) {
    const vehicleCodes = ['LV', 'DT', 'BD', 'BHL', 'EX', 'WT', 'WL'];
    final licenseByCode = {
      for (final license in profile.licenses)
        license.name.trim().toUpperCase(): license,
    };

    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(10.0),
        1: pw.FlexColumnWidth(),
        2: pw.FixedColumnWidth(12.8),
        3: pw.FixedColumnWidth(24.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _blue),
          children: [
            _tableHeader(''),
            _tableHeader('VEHICLE / EQUIPMENT'),
            _tableHeader('LIC'),
            _tableHeader('ISSUED DATE'),
          ],
        ),
        ...vehicleCodes.map((code) {
          final license = licenseByCode[code];
          return pw.TableRow(
            children: [
              _tableCell(code, bold: true),
              _tableCell(license?.name ?? ''),
              _tableCell(license == null ? '' : 'F'),
              _tableCell(license?.obtainedAt ?? ''),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeader(String value) {
    return pw.Container(
      height: 3.45 * _mm,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 0.8),
      child: pw.Text(
        value,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: 4.0,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static pw.Widget _tableCell(String value, {bool bold = false}) {
    return pw.Container(
      height: 3.25 * _mm,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 0.5),
      child: pw.Text(
        value,
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: 4.8,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _ink,
        ),
      ),
    );
  }

  static pw.Widget _checkboxLabel(String label) {
    return pw.Row(
      children: [
        pw.Container(
          width: 3.0 * _mm,
          height: 3.0 * _mm,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
        ),
        pw.SizedBox(width: 0.7 * _mm),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 4.6,
            fontWeight: pw.FontWeight.bold,
            color: _deepBlue,
          ),
        ),
      ],
    );
  }

  static pw.Widget _rulesBlock() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Keterangan:',
          style: pw.TextStyle(
            fontSize: 4.0,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.Text(
          'F = Full, P = Probation, R = Restricted, T = Training, I = Instructor',
          style: pw.TextStyle(
            fontSize: 3.45,
            fontStyle: pw.FontStyle.italic,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 0.45 * _mm),
        _ruleText(
          '1. Kartu ini harus dipakai selama berada di area kerja dan digunakan sebatas izin akses ke area pertambangan.',
        ),
        _ruleText(
          '2. Kartu ini milik PT BBE, pemegang kartu wajib mengembalikan kartu ini jika habis masa berlaku atau tidak lagi terikat kerja.',
        ),
        _ruleText('3. Segera laporkan ke QHSE jika kehilangan kartu ini.'),
        _ruleText(
          '4. Apabila menemukan kartu ini mohon untuk melaporkan ke perusahaan melalui kontak yang tersedia.',
        ),
      ],
    );
  }

  static pw.Widget _ruleText(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0.35),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 3.1,
          height: 0.94,
          color: _ink,
        ),
      ),
    );
  }

  static Future<pw.MemoryImage?> _loadNetworkImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final response = await http.get(Uri.parse(url)).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return pw.MemoryImage(response.bodyBytes);
    } catch (_) {
      return null;
    }
  }

  static Future<pw.MemoryImage?> _loadAssetImage(String assetPath) async {
    try {
      final data = await rootBundle.load(assetPath);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static String _display(String? value, {String fallback = '-'}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
  }

  static DateTime _validUntil() {
    final now = DateTime.now();
    return DateTime(now.year + 1, now.month, now.day);
  }

  static String _formatDate(DateTime value) {
    const months = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${value.day} ${months[value.month - 1]} ${value.year}';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    final chars = parts
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0])
        .join()
        .toUpperCase();
    return chars.isEmpty ? '?' : chars;
  }

  static double _fitText(
    String value, {
    required double base,
    required double small,
    required double tiny,
  }) {
    final length = value.trim().length;
    if (length > 30) return tiny;
    if (length > 20) return small;
    return base;
  }
}
