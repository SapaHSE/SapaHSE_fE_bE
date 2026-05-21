import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';

import '../models/profile_model.dart';
import 'helper/save_helper.dart'
    if (dart.library.html) 'helper/web_save_helper.dart'
    if (dart.library.io) 'helper/mobile_save_helper.dart';

class IdCardPdfService {
  static const String _bbeLogoPath = 'assets/logo_bbe.svg';
  static const String _khotaiLogoPath = 'assets/logo_khotai.svg';
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
    List<MinePermitTableRow>? tableRows,
  }) async {
    final bytes = await buildMinePermitPdf(
      profile: profile,
      qrCode: qrCode,
      tableRows: tableRows,
    );
    final fileName = minePermitFileName(profile);

    await saveAndLaunchFile(
      bytes,
      fileName,
      mimeType: 'application/pdf',
    );
  }

  static Future<Uint8List> buildMinePermitPdf({
    required ProfileData profile,
    required String qrCode,
    List<MinePermitTableRow>? tableRows,
  }) async {
    final document = pw.Document();
    final avatar = await _loadNetworkImage(profile.profilePhoto);
    final bbeLogo = await _loadAssetSvg(_bbeLogoPath);
    final khotaiLogo = await _loadAssetSvg(_khotaiLogoPath);
    final selectedLogo = _selectCompanyLogo(
      profile.company,
      bbeLogo: bbeLogo,
      khotaiLogo: khotaiLogo,
    );

    document.addPage(
      pw.Page(
        pageFormat: _cardFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => _frontCard(profile, qrCode, avatar, selectedLogo),
      ),
    );

    document.addPage(
      pw.Page(
        pageFormat: _cardFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => _backCard(
          profile,
          tableRows ?? buildMinePermitTableRows(profile),
        ),
      ),
    );

    return document.save();
  }

  static String minePermitFileName(ProfileData profile) {
    final safeName = profile.fullName
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return 'ID_Card_${safeName.isEmpty ? profile.employeeId : safeName}.pdf';
  }

  static pw.Widget _frontCard(
    ProfileData profile,
    String qrCode,
    pw.MemoryImage? avatar,
    String logo,
  ) {
    final positionDepartment = [
      _display(profile.jabatan ?? profile.position, fallback: ''),
      _display(profile.department, fallback: ''),
    ].where((value) => value.isNotEmpty).join(' - ');

    return _printPage(
      child: pw.Stack(
        children: [
          _bbeHeader(logo),
          _blueTitleBar('MINE PERMIT'),
          pw.Positioned(
            left: 5.2 * _mm,
            top: 21.8 * _mm,
            child: _avatarBox(avatar, profile.fullName),
          ),
          pw.Positioned(
            left: 27.4 * _mm,
            top: 22.0 * _mm,
            child: pw.SizedBox(
              width: 21.0 * _mm,
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
            left: 7.9 * _mm,
            top: 53.2 * _mm,
            child: pw.SizedBox(
              width: 15.4 * _mm,
              child: _counterBox('VIOLATION'),
            ),
          ),
          pw.Positioned(
            left: 7.9 * _mm,
            top: 61.3 * _mm,
            child: pw.SizedBox(
              width: 15.4 * _mm,
              child: _counterBox('INCIDENT'),
            ),
          ),
          pw.Positioned(
            left: 5.6 * _mm,
            top: 71.0 * _mm,
            child: _signatureBlock(logo),
          ),
          pw.Positioned(
            right: 4.8 * _mm,
            bottom: 7.0 * _mm,
            child: _qrBlock(qrCode),
          ),
        ],
      ),
    );
  }

  static pw.Widget _backCard(
    ProfileData profile,
    List<MinePermitTableRow> tableRows,
  ) {
    final simPolice = _simPoliceLicense(profile);

    return _printPage(
      child: pw.Stack(
        children: [
          pw.Positioned(
            left: 0,
            right: 0,
            top: 1.7 * _mm,
            child: pw.Text(
              'SIMPER',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                color: _green,
                fontWeight: pw.FontWeight.bold,
                fontSize: 11.2,
              ),
            ),
          ),
          pw.Positioned(
            left: 1.4 * _mm,
            top: 8.8 * _mm,
            child: pw.SizedBox(
              width: 23.2 * _mm,
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
                  _smallLabelRow('NOMOR', simPolice?.licenseNumber ?? ''),
                  _smallLabelRow('TIPE', _simPoliceType(simPolice)),
                  _smallLabelRow(
                    'EXP. DATE',
                    _formatLicenseDate(simPolice?.expiredAt),
                  ),
                ],
              ),
            ),
          ),
          pw.Positioned(
            left: 28.4 * _mm,
            top: 8.8 * _mm,
            child: pw.Container(width: 0.45, height: 10.0 * _mm, color: _line),
          ),
          pw.Positioned(
            left: 31.8 * _mm,
            top: 8.9 * _mm,
            child: pw.SizedBox(
              width: 18.0 * _mm,
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
            left: 1.0 * _mm,
            top: 20.8 * _mm,
            child: pw.SizedBox(
              width: 50.6 * _mm,
              child: _simperTable(tableRows),
            ),
          ),
          pw.Positioned(
            left: 0.8 * _mm,
            right: 0.8 * _mm,
            top: 50.1 * _mm,
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
            left: 0.8 * _mm,
            right: 0.8 * _mm,
            top: 54.2 * _mm,
            child: pw.Container(height: 0.45, color: _line),
          ),
          pw.Positioned(
            left: 0.8 * _mm,
            right: 0.8 * _mm,
            top: 54.8 * _mm,
            child: _rulesBlock(profile.company),
          ),
          pw.Positioned(
            left: 0,
            right: 0,
            top: 69.4 * _mm,
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
            left: 0,
            right: 0,
            bottom: 0,
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

  static pw.Widget _bbeHeader(String logo) {
    if (logo.isEmpty) {
      return pw.Positioned(
        left: 0,
        right: 0,
        top: 2.4 * _mm,
        child: pw.Center(
          child: pw.Row(
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
          ),
        ),
      );
    }

    return pw.Positioned(
      left: 0,
      right: 0,
      top: 2.4 * _mm,
      child: pw.Center(
        child: pw.SizedBox(
          width: 28.5 * _mm,
          height: 8.2 * _mm,
          child: pw.SvgImage(svg: logo, fit: pw.BoxFit.contain),
        ),
      ),
    );
  }

  static pw.Widget _blueTitleBar(String title) {
    return pw.Positioned(
      left: 0,
      right: 0,
      top: 12.2 * _mm,
      child: pw.Container(
        height: 6.6 * _mm,
        color: _blue,
        alignment: pw.Alignment.center,
        child: pw.Text(
          title,
          style: pw.TextStyle(
            color: PdfColors.white,
            fontWeight: pw.FontWeight.bold,
            fontSize: 11.2,
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
                  fontSize: 10.8,
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
      padding: const pw.EdgeInsets.only(bottom: 1.45),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label,
            maxLines: 1,
            style: pw.TextStyle(
              fontSize: 4.5,
              fontStyle: pw.FontStyle.italic,
              fontWeight: pw.FontWeight.bold,
              color: _blue,
            ),
          ),
          pw.Text(
            value,
            maxLines: 2,
            style: pw.TextStyle(
              fontSize: _fitText(value, base: 5.7, small: 5.1, tiny: 4.6),
              lineSpacing: -0.15,
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
            fontSize: 5.0,
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
                      height: 3.7 * _mm,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        '$n',
                        style: pw.TextStyle(
                          fontSize: 5.6,
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

  static pw.Widget _signatureBlock(String logo) {
    if (logo.isEmpty) {
      return pw.SizedBox(
        width: 19.6 * _mm,
        child: pw.Column(
          children: [
            pw.Text(
              'Disahkan oleh,',
              style: pw.TextStyle(
                fontSize: 4.2,
                fontWeight: pw.FontWeight.bold,
                color: _deepBlue,
              ),
            ),
            pw.SizedBox(height: 0.35 * _mm),
            pw.Container(
              width: 13.0 * _mm,
              height: 2.0 * _mm,
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: _deepBlue, width: 0.5),
                ),
              ),
            ),
            pw.SizedBox(height: 0.1 * _mm),
            pw.Row(
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Container(
                  width: 3.4 * _mm,
                  height: 4.1 * _mm,
                  decoration: pw.BoxDecoration(
                    color: PdfColor.fromInt(0xFF2AB673),
                    borderRadius: pw.BorderRadius.circular(4),
                  ),
                ),
                pw.SizedBox(width: 0.8 * _mm),
                pw.Text(
                  'BBE',
                  style: pw.TextStyle(
                    fontSize: 7.0,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink,
                  ),
                ),
              ],
            ),
            pw.Text(
              'Reno Barus, S.T',
              style: pw.TextStyle(
                fontSize: 3.9,
                fontWeight: pw.FontWeight.bold,
                color: _ink,
              ),
            ),
            pw.Text(
              'Kepala Teknik Tambang',
              style: pw.TextStyle(
                fontSize: 3.6,
                fontStyle: pw.FontStyle.italic,
                color: _ink,
              ),
            ),
          ],
        ),
      );
    }

    return pw.SizedBox(
      width: 19.6 * _mm,
      child: pw.Column(
        children: [
          pw.Text(
            'Disahkan oleh,',
            style: pw.TextStyle(
              fontSize: 4.2,
              fontWeight: pw.FontWeight.bold,
              color: _deepBlue,
            ),
          ),
          pw.SizedBox(height: 0.35 * _mm),
          pw.Container(
            width: 13.0 * _mm,
            height: 2.0 * _mm,
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(color: _deepBlue, width: 0.5),
              ),
            ),
          ),
          pw.SizedBox(height: 0.1 * _mm),
          pw.SizedBox(
            width: 14.0 * _mm,
            height: 4.4 * _mm,
            child: pw.SvgImage(svg: logo, fit: pw.BoxFit.contain),
          ),
          pw.Text(
            'Reno Barus, S.T',
            style: pw.TextStyle(
              fontSize: 3.9,
              fontWeight: pw.FontWeight.bold,
              color: _ink,
            ),
          ),
          pw.Text(
            'Kepala Teknik Tambang',
            style: pw.TextStyle(
              fontSize: 3.6,
              fontStyle: pw.FontStyle.italic,
              color: _ink,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _qrBlock(String qrCode) {
    return pw.SizedBox(
      width: 21.0 * _mm,
      child: pw.Column(
        children: [
          pw.BarcodeWidget(
            barcode: pw.Barcode.qrCode(),
            data: qrCode,
            width: 18.8 * _mm,
            height: 18.8 * _mm,
          ),
          pw.SizedBox(height: 1.0 * _mm),
          pw.Text(
            'SCAN QR PROFIL',
            style: pw.TextStyle(
              fontSize: 3.45,
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

  static pw.Widget _simperTable(List<MinePermitTableRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(6.4),
        1: pw.FixedColumnWidth(22.4),
        2: pw.FixedColumnWidth(9.8),
        3: pw.FixedColumnWidth(12.0),
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
        ...rows.map((row) {
          return pw.TableRow(
            children: [
              _tableCell(row.code, bold: true),
              _tableCell(row.vehicleEquipment),
              _tableCell(row.licenseNumber),
              _tableCell(row.issuedDate),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeader(String value) {
    final isIssuedDate = value == 'ISSUED DATE';
    return pw.Container(
      height: 3.25 * _mm,
      alignment: pw.Alignment.center,
      padding: pw.EdgeInsets.symmetric(horizontal: isIssuedDate ? 0.35 : 0.8),
      child: pw.Text(
        value,
        maxLines: 1,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          color: PdfColors.white,
          fontSize: _tableHeaderFontSize(value),
          fontWeight: pw.FontWeight.bold,
        ),
      ),
    );
  }

  static double _tableHeaderFontSize(String value) {
    if (value == 'ISSUED DATE') return 3.2;
    if (value == 'VEHICLE / EQUIPMENT') return 3.3;
    return 3.8;
  }

  static pw.Widget _tableCell(String value, {bool bold = false}) {
    return pw.Container(
      height: 3.25 * _mm,
      alignment: pw.Alignment.center,
      padding: const pw.EdgeInsets.symmetric(horizontal: 0.45),
      child: pw.Text(
        value,
        maxLines: 1,
        style: pw.TextStyle(
          fontSize: _tableCellFontSize(value),
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: _ink,
        ),
      ),
    );
  }

  static List<MinePermitTableRow> buildMinePermitTableRows(
    ProfileData profile,
  ) {
    return _simperRows(profile);
  }

  static double _tableCellFontSize(String value) {
    final length = value.trim().length;
    if (length > 18) return 3.25;
    if (length > 12) return 3.7;
    return 4.5;
  }

  static pw.Widget _checkboxLabel(String label) {
    return pw.Row(
      children: [
        pw.Container(
          width: 2.8 * _mm,
          height: 2.8 * _mm,
          decoration: pw.BoxDecoration(border: pw.Border.all(color: _line)),
        ),
        pw.SizedBox(width: 0.7 * _mm),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 4.4,
            fontWeight: pw.FontWeight.bold,
            color: _deepBlue,
          ),
        ),
      ],
    );
  }

  static pw.Widget _rulesBlock(String? companyName) {
    final companyText = _display(
      companyName,
      fallback: 'PT Bukit Baiduri Energi',
    );

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Keterangan:',
          style: pw.TextStyle(
            fontSize: 5.0,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.Text(
          'F = Full, P = Probation, R = Restricted, T = Training, I = Instructor',
          style: pw.TextStyle(
            fontSize: 4.15,
            fontStyle: pw.FontStyle.italic,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 0.3 * _mm),
        _ruleText(
          '1. Kartu ini harus dipakai selama berada di area kerja dan digunakan sebatas izin akses ke area pertambangan.',
        ),
        _ruleText(
          '2. Kartu ini milik $companyText, pemegang kartu wajib mengembalikan kartu ini jika habis masa berlaku atau tidak lagi terikat kerja.',
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
      padding: const pw.EdgeInsets.only(bottom: 0.25),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 3.5,
          height: 0.88,
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

  static Future<String?> _loadAssetSvg(String assetPath) async {
    try {
      return await rootBundle.loadString(assetPath);
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

  static String _formatLicenseDate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';

    final parsed = DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    if (parsed == null) return trimmed;

    final day = parsed.day.toString().padLeft(2, '0');
    final month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
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

  static String _selectCompanyLogo(
    String? company, {
    required String? bbeLogo,
    required String? khotaiLogo,
  }) {
    final normalized = (company ?? '').trim().toLowerCase();
    if (normalized.contains('khotai')) return khotaiLogo ?? bbeLogo ?? '';
    if (normalized.contains('bbe') ||
        normalized.contains('bukit baiduri energi')) {
      return bbeLogo ?? khotaiLogo ?? '';
    }
    return bbeLogo ?? khotaiLogo ?? '';
  }

  static List<UserLicense> _usableLicenses(ProfileData profile) {
    return profile.licenses.where((license) {
      final status = license.status.trim().toLowerCase();
      final approval = license.approvalStatus.trim().toLowerCase();
      return status != 'expired' &&
          status != 'suspended' &&
          approval != 'rejected';
    }).toList();
  }

  static UserLicense? _simPoliceLicense(ProfileData profile) {
    final licenses = _usableLicenses(profile)
        .where((license) => _isSimPoliceName(license.name))
        .toList()
      ..sort((a, b) => _simPriority(b.name).compareTo(_simPriority(a.name)));

    return licenses.isEmpty ? null : licenses.first;
  }

  static String _simPoliceType(UserLicense? license) {
    if (license == null) return '';
    final type = _simTypeLabel(license.name);
    return type.isEmpty ? license.name : type;
  }

  static List<MinePermitTableRow> _simperRows(ProfileData profile) {
    final licenses = _usableLicenses(profile);
    const specs = [
      _SimperRowSpec('LV', ['SIM A', 'SIM A UMUM']),
      _SimperRowSpec('DT', ['SIM B1', 'SIM B2', 'DUMP TRUCK']),
      _SimperRowSpec('BD', ['BULLDOZER', 'DOZER', 'BD']),
      _SimperRowSpec('BHL', ['BACKHOE', 'BHL']),
      _SimperRowSpec('EX', ['EXCAVATOR', 'EX']),
      _SimperRowSpec('WT', ['SIM B1', 'SIM B2', 'WATER TRUCK']),
      _SimperRowSpec('WL', ['WHEEL LOADER', 'LOADER', 'WL']),
    ];

    return specs
        .map((spec) {
          final license = _findLicenseForSpec(licenses, spec);
          return MinePermitTableRow(
              code: spec.code,
              vehicleEquipment: '',
              licenseNumber: license?.licenseNumber ?? '',
              issuedDate: _formatLicenseDate(license?.obtainedAt),
            );
        })
        .toList();
  }

  static UserLicense? _findLicenseForSpec(
    List<UserLicense> licenses,
    _SimperRowSpec spec,
  ) {
    final matched = licenses.where((license) {
      final haystack = _licenseSearchText(license);
      return spec.keywords.any((keyword) => haystack.contains(keyword));
    }).toList()
      ..sort((a, b) => _licenseSpecificity(b, spec)
          .compareTo(_licenseSpecificity(a, spec)));

    return matched.isEmpty ? null : matched.first;
  }

  static int _licenseSpecificity(UserLicense license, _SimperRowSpec spec) {
    final haystack = _licenseSearchText(license);
    var score = 0;
    if (haystack.contains(spec.code)) score += 4;
    if (haystack.contains('UMUM')) score += 1;
    if (license.isVerified) score += 1;
    return score;
  }

  static String _licenseSearchText(UserLicense license) {
    return [
      license.name,
      license.licenseNumber,
      license.issuer ?? '',
    ].join(' ').toUpperCase();
  }

  static bool _isSimPoliceName(String value) {
    final normalized = value.toUpperCase();
    return normalized.contains('SIM A') ||
        normalized.contains('SIM B1') ||
        normalized.contains('SIM B2');
  }

  static int _simPriority(String value) {
    final normalized = value.toUpperCase();
    if (normalized.contains('SIM B2') && normalized.contains('UMUM')) return 6;
    if (normalized.contains('SIM B2')) return 5;
    if (normalized.contains('SIM B1') && normalized.contains('UMUM')) return 4;
    if (normalized.contains('SIM B1')) return 3;
    if (normalized.contains('SIM A') && normalized.contains('UMUM')) return 2;
    if (normalized.contains('SIM A')) return 1;
    return 0;
  }

  static String _simTypeLabel(String value) {
    final normalized = value.toUpperCase();
    if (normalized.contains('SIM B2') && normalized.contains('UMUM')) {
      return 'SIM B2 UMUM';
    }
    if (normalized.contains('SIM B2')) return 'SIM B2';
    if (normalized.contains('SIM B1') && normalized.contains('UMUM')) {
      return 'SIM B1 UMUM';
    }
    if (normalized.contains('SIM B1')) return 'SIM B1';
    if (normalized.contains('SIM A') && normalized.contains('UMUM')) {
      return 'SIM A UMUM';
    }
    if (normalized.contains('SIM A')) return 'SIM A';
    return '';
  }
}

class _SimperRowSpec {
  final String code;
  final List<String> keywords;

  const _SimperRowSpec(this.code, this.keywords);
}

class MinePermitTableRow {
  final String code;
  final String vehicleEquipment;
  final String licenseNumber;
  final String issuedDate;

  const MinePermitTableRow({
    required this.code,
    required this.vehicleEquipment,
    required this.licenseNumber,
    required this.issuedDate,
  });
}
