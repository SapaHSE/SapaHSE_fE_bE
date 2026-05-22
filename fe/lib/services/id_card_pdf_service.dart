import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:typed_data';
import 'package:image/image.dart' as img;

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
  static const PdfColor _line = PdfColors.black;

  static Future<void> exportMinePermit({
    required ProfileData profile,
    required String qrCode,
    UserLicense? minePermit,
    List<MinePermitTableRow>? tableRows,
  }) async {
    final bytes = await buildMinePermitPdf(
      profile: profile,
      qrCode: qrCode,
      minePermit: minePermit,
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
    UserLicense? minePermit,
    List<MinePermitTableRow>? tableRows,
  }) async {
    final document = pw.Document();
    final avatarOriginal = await _loadNetworkImage(profile.profilePhoto);
    final avatar = await _removeBackground(avatarOriginal, profile.profilePhoto);
    final detailCategory =
        profile.companyDetail?.category.trim().toLowerCase() ?? '';
    final headerLogoUrl =
        detailCategory == 'owner' ? profile.companyDetail?.logoUrl : null;
    final companyLogo = await _loadNetworkImage(headerLogoUrl);
    final companyLogoSvg = await _loadNetworkSvg(headerLogoUrl);
    final kttSignatureImage =
        await _loadNetworkImage(profile.companyDetail?.kttSignatureUrl);
    final kttSignatureSvg =
        await _loadNetworkSvg(profile.companyDetail?.kttSignatureUrl);
    final companyStampImage =
        await _loadNetworkImage(profile.companyDetail?.companyStampUrl);
    final companyStampSvg =
        await _loadNetworkSvg(profile.companyDetail?.companyStampUrl);
    final bbeLogo = await _loadAssetSvg(_bbeLogoPath);
    final khotaiLogo = await _loadAssetSvg(_khotaiLogoPath);
    final selectedLogo = _selectCompanyLogo(
      profile.company,
      bbeLogo: bbeLogo,
      khotaiLogo: khotaiLogo,
    );

    document.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: pw.EdgeInsets.all(20),
        build: (_) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          children: [
            _frontCard(
              profile,
              qrCode,
              avatar,
              selectedLogo,
              companyLogo,
              companyLogoSvg,
              kttSignatureImage,
              kttSignatureSvg,
              companyStampImage,
              companyStampSvg,
              minePermit,
            ),
            pw.SizedBox(width: 20),
            _backCard(
              profile,
              tableRows ?? buildMinePermitTableRows(profile),
            ),
          ],
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
    pw.MemoryImage? companyLogo,
    String? companyLogoSvg,
    pw.MemoryImage? kttSignatureImage,
    String? kttSignatureSvg,
    pw.MemoryImage? companyStampImage,
    String? companyStampSvg,
    UserLicense? minePermit,
  ) {
    final position = _display(profile.jabatan ?? profile.position);
    final department = _display(profile.department);

    return _printPage(
      child: pw.Stack(
        children: [
          _bbeHeader(logo, companyLogo, companyLogoSvg),
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
                    'Employee ID',
                    _display(profile.employeeId),
                  ),
                  _profileLine(
                    'Position',
                    position,
                  ),
                  _profileLine(
                    'Department',
                    department,
                  ),
                  _profileLine(
                    'Company',
                    _affiliationCompanyName(profile),
                  ),
                ],
              ),
            ),
          ),
          pw.Positioned(
            left: 8.1 * _mm,
            top: 51.8 * _mm,
            child: pw.SizedBox(
              width: 14.8 * _mm,
              child: _accessTypeBox(),
            ),
          ),
          pw.Positioned(
            left: 5.6 * _mm,
            top: 61.4 * _mm,
            child: _signatureBlock(
              logo,
              companyLogo,
              companyLogoSvg,
              kttSignatureImage,
              kttSignatureSvg,
              companyStampImage,
              companyStampSvg,
              _kttName(profile),
            ),
          ),
          pw.Positioned(
            left: 0,
            right: 0,
            top: 76.2 * _mm,
            child: pw.Center(
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.SizedBox(
                      width: 15.4 * _mm, child: _counterBox('VIOLATION')),
                  pw.SizedBox(width: 4.4 * _mm),
                  pw.SizedBox(
                      width: 15.4 * _mm, child: _counterBox('INCIDENT')),
                ],
              ),
            ),
          ),
          pw.Positioned(
            right: 4.8 * _mm,
            bottom: 10.3 * _mm,
            child: _qrBlock(
              qrCode,
              IdCardPdfService.formatExpiry(minePermit?.expiredAt),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _backCard(
    ProfileData profile,
    List<MinePermitTableRow> tableRows,
  ) {
    final emergencyNumber = _companyEmergencyNumberText(profile);
    final radioContact = _companyRadioText(profile);

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
            left: 1.0 * _mm,
            top: 12.0 * _mm,
            child: pw.SizedBox(
              width: 50.6 * _mm,
              child: _simperTable(tableRows),
            ),
          ),
          pw.Positioned(
            left: 0.8 * _mm,
            right: 0.8 * _mm,
            top: 49.4 * _mm,
            child: pw.Container(height: 0.45, color: _line),
          ),
          pw.Positioned(
            left: 0.8 * _mm,
            right: 0.8 * _mm,
            top: 50.0 * _mm,
            child: _rulesBlock(profile),
          ),
          pw.Positioned(
            left: 0.8 * _mm,
            right: 0.8 * _mm,
            top: 67.3 * _mm,
            child: pw.Container(
              height: 3.4 * _mm,
              alignment: pw.Alignment.center,
              color: _red,
              child: pw.Text(
                'EMERGENCY CONTACT',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  color: PdfColors.white,
                  fontSize: 4.7,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
          ),
          pw.Positioned(
            left: 0.8 * _mm,
            right: 0.8 * _mm,
            top: 70.9 * _mm,
            child: pw.Container(
              height: 5.1 * _mm,
              alignment: pw.Alignment.center,
              color: PdfColors.white,
              padding: const pw.EdgeInsets.symmetric(horizontal: 2.0),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    emergencyNumber,
                    maxLines: 1,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 5.0,
                      fontWeight: pw.FontWeight.bold,
                      height: 0.9,
                    ),
                  ),
                  pw.SizedBox(height: 0.55 * _mm),
                  pw.Text(
                    radioContact,
                    maxLines: 1,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(
                      color: _ink,
                      fontSize: 4.7,
                      fontWeight: pw.FontWeight.bold,
                      height: 0.9,
                    ),
                  ),
                ],
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
              pw.Border.all(color: PdfColors.black, width: 0.8),
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

  static pw.Widget _bbeHeader(
    String logo,
    pw.MemoryImage? logoImage,
    String? logoSvg,
  ) {
    if (logoSvg != null && logoSvg.trim().isNotEmpty) {
      return pw.Positioned(
        left: 0,
        right: 0,
        top: 2.4 * _mm,
        child: pw.Center(
          child: pw.SizedBox(
            width: 28.5 * _mm,
            height: 8.2 * _mm,
            child: pw.SvgImage(svg: logoSvg, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

    if (logoImage != null) {
      return pw.Positioned(
        left: 0,
        right: 0,
        top: 2.4 * _mm,
        child: pw.Center(
          child: pw.SizedBox(
            width: 28.5 * _mm,
            height: 8.2 * _mm,
            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
          ),
        ),
      );
    }

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
      padding: const pw.EdgeInsets.only(bottom: 1.0),
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
            maxLines: 1,
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

  static pw.Widget _accessTypeBox() {
    return pw.Column(
      children: [
        pw.Text(
          'ACCESS TYPE',
          style: pw.TextStyle(
            fontSize: 4.2,
            fontWeight: pw.FontWeight.bold,
            color: _deepBlue,
          ),
        ),
        pw.Table(
          border: pw.TableBorder.all(color: _line, width: 0.45),
          columnWidths: const {
            0: pw.FlexColumnWidth(),
            1: pw.FlexColumnWidth(),
            2: pw.FlexColumnWidth(),
            3: pw.FlexColumnWidth(),
            4: pw.FlexColumnWidth(),
          },
          children: [
            pw.TableRow(
              children: ['T1', 'T2', 'T3', 'T4', 'T5']
                  .map(
                    (label) => pw.Container(
                      height: 2.35 * _mm,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        label,
                        style: pw.TextStyle(
                          fontSize: 3.25,
                          fontWeight: pw.FontWeight.bold,
                          color: _ink,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
            pw.TableRow(
              children: ['', '', '', '', '']
                  .map(
                    (label) => pw.Container(
                      height: 2.35 * _mm,
                      alignment: pw.Alignment.center,
                      child: pw.Text(
                        label,
                        style: pw.TextStyle(
                          fontSize: 3.8,
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

  static pw.Widget _signatureBlock(
    String logo,
    pw.MemoryImage? logoImage,
    String? logoSvg,
    pw.MemoryImage? kttSignatureImage,
    String? kttSignatureSvg,
    pw.MemoryImage? companyStampImage,
    String? companyStampSvg,
    String kttName,
  ) {
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
          pw.SizedBox(height: 4.5 * _mm),
          pw.SizedBox(
            width: 14.0 * _mm,
            height: 4.4 * _mm,
            child: pw.Row(
              children: [
                pw.Expanded(
                  child: _optionalLogoWidget(
                    image: kttSignatureImage,
                    svg: kttSignatureSvg,
                    fallback: pw.SizedBox(),
                  ),
                ),
                pw.SizedBox(width: 0.6 * _mm),
                pw.Expanded(
                  child: _optionalLogoWidget(
                    image: companyStampImage,
                    svg: companyStampSvg,
                    fallback: pw.SizedBox(),
                  ),
                ),
              ],
            ),
          ),
          pw.Text(
            kttName,
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

  static pw.Widget _qrBlock(String qrCode, String validUntil) {
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
            'Valid Until',
            style: pw.TextStyle(
              fontSize: 3.0,
              fontStyle: pw.FontStyle.italic,
              fontWeight: pw.FontWeight.bold,
              color: _blue,
            ),
          ),
          pw.Text(
            validUntil,
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

  static pw.Widget _simperTable(List<MinePermitTableRow> rows) {
    return pw.Table(
      border: pw.TableBorder.all(color: _line, width: 0.55),
      columnWidths: const {
        0: pw.FixedColumnWidth(6.4),
        1: pw.FixedColumnWidth(26.4),
        2: pw.FixedColumnWidth(5.8),
        3: pw.FixedColumnWidth(12.0),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: _blue),
          children: [
            _tableHeader(''),
            _tableHeader('VEHICLE / EQUIPMENT'),
            _tableHeader('LIC'),
            _tableHeader('EXP DATE'),
          ],
        ),
        ...rows.map((row) {
          return pw.TableRow(
            children: [
              _tableCell(row.code, bold: true),
              _tableCell(row.vehicleEquipment, alignLeft: true),
              _tableCell(row.licenseNumber),
              _tableCell(row.issuedDate),
            ],
          );
        }),
      ],
    );
  }

  static pw.Widget _tableHeader(String value) {
    final isIssuedDate = value == 'EXP DATE';
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
    if (value == 'EXP DATE') return 3.4;
    if (value == 'VEHICLE / EQUIPMENT') return 3.3;
    return 3.8;
  }

  static pw.Widget _tableCell(String value, {bool bold = false, bool alignLeft = false}) {
    return pw.Container(
      height: 3.25 * _mm,
      alignment: alignLeft ? pw.Alignment.centerLeft : pw.Alignment.center,
      padding: pw.EdgeInsets.only(
        left: alignLeft ? 1.2 : 0.45,
        right: 0.45,
      ),
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

  static pw.Widget _rulesBlock(ProfileData profile) {
    final companyShort = _getCompanyShort(profile);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'Catatan:',
          style: pw.TextStyle(
            fontSize: 6.0,
            fontWeight: pw.FontWeight.bold,
            color: _ink,
          ),
        ),
        pw.SizedBox(height: 0.15 * _mm),
        _ruleText('1',
          'Kartu ini harus dipakai selama berada di area kerja dan digunakan sebatas izin akses ke area pertambangan.',
        ),
        _ruleText('2',
          'Kartu ini milik $companyShort, pemegang kartu wajib mengembalikan kartu ini jika habis masa berlaku atau tidak lagi terikat kerja.',
        ),
        _ruleText('3', 'Segera laporkan ke QHSE jika kehilangan kartu ini.'),
        _ruleText('4',
          'Apabila menemukan kartu ini mohon untuk melaporkan ke perusahaan melalui kontak yang tersedia.',
        ),
      ],
    );
  }

  static String _getCompanyShort(ProfileData profile) {
    // If companyDetail is owner, use its code directly
    final detailCategory = profile.companyDetail?.category.trim().toLowerCase() ?? '';
    
    if (detailCategory == 'owner') {
      final code = profile.companyDetail?.code?.trim();
      if (code != null && code.isNotEmpty) {
        return 'PT $code';
      }
    }
    
    // For contractor/sub, detect owner code from company name
    final ownerName = (profile.company ?? '').trim().toLowerCase();
    
    // Map common owner companies to their codes
    if (ownerName.contains('khotai')) {
      return 'PT KMIA';
    }
    if (ownerName.contains('bukit baiduri') || ownerName.contains('bbe')) {
      return 'PT BBE';
    }
    
    // Fallback to full company name
    return profile.company?.trim() ?? 'PT BBE';
  }

  static pw.Widget _ruleText(String number, String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 0.25),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.SizedBox(
            width: 1.9 * _mm,
            child: pw.Text(
              '$number.',
              style: pw.TextStyle(
                fontSize: 4.5,
                height: 0.95,
                color: _ink,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              text,
              style: pw.TextStyle(
                fontSize: 4.5,
                height: 0.95,
                color: _ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Future<pw.MemoryImage?> _loadNetworkImage(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (uri.path.toLowerCase().endsWith('.svg')) return null;
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

  static Future<pw.MemoryImage?> _removeBackground(
    pw.MemoryImage? image,
    String? imageUrl,
  ) async {
    if (image == null) return null;

    try {
      final imgData = img.decodeImage(image.bytes);
      if (imgData == null) return image;

      final processed = img.Image(
        width: imgData.width,
        height: imgData.height,
        numChannels: 4,
      );

      for (var y = 0; y < imgData.height; y++) {
        for (var x = 0; x < imgData.width; x++) {
          final pixel = imgData.getPixel(x, y);
          final r = pixel.r.toInt();
          final g = pixel.g.toInt();
          final b = pixel.b.toInt();

          final brightness = (r + g + b) / 3;
          final isBackground = brightness > 200 || 
              (r > 180 && g > 180 && b > 180);

          if (isBackground) {
            processed.setPixelRgba(x, y, r, g, b, 0);
          } else {
            processed.setPixelRgba(x, y, r, g, b, 255);
          }
        }
      }

      final pngBytes = img.encodePng(processed);
      return pw.MemoryImage(Uint8List.fromList(pngBytes));
    } catch (_) {
      return image;
    }
  }

  static Future<String?> _loadNetworkSvg(String? url) async {
    if (url == null || url.trim().isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      if (!uri.path.toLowerCase().endsWith('.svg')) return null;
      final response = await http.get(uri).timeout(
            const Duration(seconds: 10),
          );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      return response.body;
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

  static pw.Widget _logoWidget({
    required String fallbackSvg,
    required pw.MemoryImage? image,
    required String? svg,
  }) {
    final svgValue = svg?.trim() ?? '';
    if (svgValue.isNotEmpty) {
      return pw.SvgImage(svg: svgValue, fit: pw.BoxFit.contain);
    }
    if (image != null) {
      return pw.Image(image, fit: pw.BoxFit.contain);
    }
    return pw.SvgImage(svg: fallbackSvg, fit: pw.BoxFit.contain);
  }

  static pw.Widget _optionalLogoWidget({
    required pw.MemoryImage? image,
    required String? svg,
    required pw.Widget fallback,
  }) {
    final svgValue = svg?.trim() ?? '';
    if (svgValue.isNotEmpty) {
      return pw.SvgImage(svg: svgValue, fit: pw.BoxFit.contain);
    }
    if (image != null) {
      return pw.Image(image, fit: pw.BoxFit.contain);
    }
    return fallback;
  }

  static String _companyName(ProfileData profile) {
    return _display(
      profile.companyDetail?.name ?? profile.company,
      fallback: 'PT Bukit Baiduri Energi',
    );
  }

  static String _affiliationCompanyName(ProfileData profile) {
    final affiliation = (profile.tipeAfiliasi ?? '').toLowerCase();
    final contractor = profile.perusahaanKontraktor?.trim() ?? '';
    final subcontractor = profile.subKontraktor?.trim() ?? '';
    final owner = _companyName(profile);

    if (affiliation.contains('sub') && subcontractor.isNotEmpty) {
      return subcontractor;
    }
    if (affiliation.contains('kontraktor') && contractor.isNotEmpty) {
      return contractor;
    }
    return owner;
  }

  static String _kttName(ProfileData profile) {
    return _display(
      profile.companyDetail?.kttUser?.fullName,
      fallback: _defaultKttNameForOwner(profile.company),
    );
  }

  static String _defaultKttNameForOwner(String? ownerCompany) {
    final value = (ownerCompany ?? '').toLowerCase();
    if (value.contains('khotai')) return 'Agah Wahyu Nugraha, S.T';
    return 'Reno Barus, S.T';
  }

  static String _companyEmergencyNumberText(ProfileData profile) {
    return profile.companyDetail?.emergencyNumber?.trim() ?? '';
  }

  static String _companyRadioText(ProfileData profile) {
    return [
      profile.companyDetail?.radioLabel,
      profile.companyDetail?.radioChannel,
      profile.companyDetail?.radioFrequency ??
          profile.companyDetail?.ertFreq,
    ]
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  static String _display(String? value, {String fallback = '-'}) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
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

  static String formatExpiry(String? rawIsoDate) {
    final raw = (rawIsoDate ?? '').trim();
    if (raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _formatDate(parsed);
  }

  static String _formatLicenseDate(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return '';

    final parsed = DateTime.tryParse(trimmed.replaceFirst(' ', 'T'));
    if (parsed == null) return trimmed;

    return _formatDate(parsed);
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

  static List<MinePermitTableRow> _simperRows(ProfileData profile) {
    final licenses = _usableLicenses(profile);
    const specs = [
      _SimperRowSpec('A', ['SIM A'], source: _LicenseSource.government),
      _SimperRowSpec('B', ['SIM B1', 'SIM B2'],
          source: _LicenseSource.government),
      _SimperRowSpec('C', ['SIM C'], source: _LicenseSource.government),
      _SimperRowSpec('U', ['DRONE', 'SIM DRONE'], vehicleName: 'Drone'),
      _SimperRowSpec('DT', ['DT', 'DUMP TRUCK'],
          source: _LicenseSource.simper),
      _SimperRowSpec('BD', ['BULLDOZER', 'DOZER', 'BD'],
          source: _LicenseSource.simper),
      _SimperRowSpec('BL', ['BACKHOE', 'BHL', 'BL'],
          source: _LicenseSource.simper),
      _SimperRowSpec('EX', ['EXCAVATOR', 'EX'], source: _LicenseSource.simper),
      _SimperRowSpec('WT', ['WT', 'WATER TRUCK'],
          source: _LicenseSource.simper),
      _SimperRowSpec('WL', ['WHEEL LOADER', 'LOADER', 'WL'],
          source: _LicenseSource.simper),
    ];

    return specs
        .map((spec) {
          final license = _findLicenseForSpec(licenses, spec);
          return MinePermitTableRow(
            code: spec.code,
            vehicleEquipment: license == null
                ? ''
                : (spec.vehicleName ?? license.vehicleEquipment ?? ''),
            licenseNumber: _licenseTableType(license),
            issuedDate: _formatLicenseDate(license?.expiredAt),
          );
        })
        .toList();
  }

  static UserLicense? _findLicenseForSpec(
    List<UserLicense> licenses,
    _SimperRowSpec spec,
  ) {
    final matched = licenses.where((license) {
      if (!_matchesSource(license, spec.source)) return false;
      return _matchesSpecKeyword(license, spec);
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

  static bool _matchesSpecKeyword(UserLicense license, _SimperRowSpec spec) {
    final haystack = _licenseSearchText(license);
    final exactValues = [
      license.simType,
      license.simIndonesiaType,
      license.licenseNumber,
      license.name,
    ].map((value) => (value ?? '').trim().toUpperCase()).toList();

    if (spec.code == 'U') {
      return haystack.contains('DRONE') || exactValues.contains('U');
    }

    if (spec.source == _LicenseSource.government &&
        ['A', 'B', 'C'].contains(spec.code)) {
      if (spec.code == 'B' &&
          (exactValues.contains('B1') || exactValues.contains('B2'))) {
        return true;
      }
      return exactValues.contains(spec.code) ||
          exactValues.contains('SIM ${spec.code}') ||
          spec.keywords.any((keyword) => haystack.contains(keyword));
    }

    return spec.keywords.any((keyword) => haystack.contains(keyword));
  }

  static bool _matchesSource(UserLicense license, _LicenseSource source) {
    final type = license.licenseType.trim().toLowerCase();
    switch (source) {
      case _LicenseSource.any:
        return true;
      case _LicenseSource.government:
        return type.contains('government') ||
            type.contains('pemerintah') ||
            type.contains('sim_indonesia') ||
            type.contains('sim indonesia');
      case _LicenseSource.simper:
        return type.contains('simper') || type.contains('mine');
    }
  }

  static String _licenseTableType(UserLicense? license) {
    if (license == null) return '';
    final values = [
      license.simType,
      license.simIndonesiaType,
      license.licenseNumber,
    ];
    for (final value in values) {
      final trimmed = value?.trim() ?? '';
      if (trimmed.isNotEmpty) return trimmed;
    }
    return '';
  }

  static String _licenseSearchText(UserLicense license) {
    return [
      license.name,
      license.licenseNumber,
      license.licenseType,
      license.vehicleEquipment ?? '',
      license.simType ?? '',
      license.simIndonesiaType ?? '',
      license.issuer ?? '',
    ].join(' ').toUpperCase();
  }

}

enum _LicenseSource { any, government, simper }

class _SimperRowSpec {
  final String code;
  final List<String> keywords;
  final _LicenseSource source;
  final String? vehicleName;

  const _SimperRowSpec(
    this.code,
    this.keywords, {
    this.source = _LicenseSource.any,
    this.vehicleName,
  });
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
