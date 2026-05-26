import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/profile_model.dart';
import '../services/id_card_pdf_service.dart';

bool _isSvgUrl(String value) {
  final path = Uri.tryParse(value)?.path.toLowerCase() ?? value.toLowerCase();
  return path.endsWith('.svg');
}

class MinePermitPreviewPair extends StatelessWidget {
  final ProfileData profile;
  final UserLicense minePermit;
  final List<MinePermitTableRow> rows;

  const MinePermitPreviewPair({
    super.key,
    required this.profile,
    required this.minePermit,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 540 ? 245.0 : 260.0;
        final cards = [
          _MinePermitFrontPreview(
            profile: profile,
            minePermit: minePermit,
            width: cardWidth,
          ),
          _MinePermitBackPreview(
            profile: profile,
            rows: rows,
            width: cardWidth,
          ),
        ];

        if (constraints.maxWidth >= 540) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              cards[0],
              const SizedBox(width: 14),
              cards[1],
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            cards[0],
            const SizedBox(height: 12),
            cards[1],
          ],
        );
      },
    );
  }
}

class _MinePermitFrontPreview extends StatelessWidget {
  final ProfileData profile;
  final UserLicense minePermit;
  final double width;

  const _MinePermitFrontPreview({
    required this.profile,
    required this.minePermit,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final position = profile.jabatan ?? profile.position ?? '';
    final department = profile.department ?? '';
    final detailCategory =
        profile.companyDetail?.category.trim().toLowerCase() ?? '';
    final logoUrl =
        detailCategory == 'owner' ? profile.companyDetail?.logoUrl?.trim() ?? '' : '';

    return _PreviewCardFrame(
      width: width,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            top: 10,
            child: Center(
              child: SizedBox(
                width: 136,
                height: 36,
                child: logoUrl.isNotEmpty
                    ? (_isSvgUrl(logoUrl)
                        ? SvgPicture.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            placeholderBuilder: (_) =>
                                _companyTextHeader(profile),
                          )
                        : Image.network(
                            logoUrl,
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) =>
                                _companyTextHeader(profile),
                          ))
                    : _companyTextHeader(profile),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 58,
            child: Container(
              height: 31,
              color: const Color(0xFF2F73C8),
              alignment: Alignment.center,
              child: const Text(
                'MINE PERMIT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ),
          ),
          Positioned(
            left: 10,
            top: 103,
            child: Container(
              width: 98,
              height: 128,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF0F7),
                border: Border.all(color: Colors.black),
              ),
              child: Text(
                _initials(profile.fullName),
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ),
          Positioned(
            left: 116,
            top: 104,
            right: 6,
            child: Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _frontInfo('Name', profile.fullName),
                  _frontInfo(
                    'Employee ID',
                    profile.employeeId,
                  ),
                  _frontInfo('Position', position),
                  _frontInfo('Department', department),
                  _frontInfo(
                    'Company',
                    _affiliationCompanyName(profile),
                  ),
                ],
              ),
            ),
          ),
          const Positioned(
            left: 14,
            top: 248,
            child: _AccessTypePreview(),
          ),
          Positioned(
            left: 15,
            bottom: 25,
            child: _MiniSignaturePreview(profile: profile),
          ),
          Positioned(
            left: 29,
            bottom: 1,
            child: const _MiniCounterPreview('VIOLATION'),
          ),
          Positioned(
            right: 19,
            bottom: 1,
            child: const _MiniCounterPreview('INCIDENT'),
          ),
          Positioned(
            right: 18,
            bottom: 20,
            child: Column(
              children: [
                const Icon(Icons.qr_code_2, size: 72),
                const SizedBox(height: 4),
                const Text(
                  'Valid Until',
                  style: TextStyle(
                    color: Color(0xFF2F73C8),
                    fontSize: 6.8,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                Text(
                  IdCardPdfService.formatExpiry(minePermit.expiredAt),
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 8.6,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static Widget _frontInfo(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: Color(0xFF2F73C8),
              fontSize: 6.5,
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: 2,
            softWrap: true,
            style: const TextStyle(
              color: Color(0xFF303744),
              fontSize: 7.4,
              fontWeight: FontWeight.bold,
              height: 1.05,
            ),
          ),
        ],
      ),
    );
  }

  static String _companyShort(String? company) {
    final value = (company ?? '').toLowerCase();
    if (value.contains('khotai')) return 'KHOTAI';
    return 'BBE';
  }

  static String _affiliationCompanyName(ProfileData profile) {
    final affiliation = (profile.tipeAfiliasi ?? '').toLowerCase();
    final contractor = profile.perusahaanKontraktor?.trim() ?? '';
    final subcontractor = profile.subKontraktor?.trim() ?? '';
    final owner = profile.companyDetail?.name ??
        profile.company ??
        'PT Bukit Baiduri Energi';

    if (affiliation.contains('sub') && subcontractor.isNotEmpty) {
      return subcontractor;
    }
    if (affiliation.contains('kontraktor') && contractor.isNotEmpty) {
      return contractor;
    }
    return owner;
  }

  static Widget _companyTextHeader(ProfileData profile) {
    final companyName = profile.company ?? 'PT Bukit Baiduri Energi';
    final detailCategory =
        profile.companyDetail?.category.trim().toLowerCase() ?? '';
    final shortText = detailCategory == 'owner'
        ? (profile.companyDetail?.code ?? _companyShort(companyName))
        : _companyShort(companyName);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          shortText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.bold,
            color: Color(0xFF303744),
            height: 0.95,
          ),
        ),
        Text(
          companyName,
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 5.5),
        ),
      ],
    );
  }
}

class _MinePermitBackPreview extends StatelessWidget {
  final ProfileData profile;
  final List<MinePermitTableRow> rows;
  final double width;

  const _MinePermitBackPreview({
    required this.profile,
    required this.rows,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final companyName =
        profile.companyDetail?.name ?? profile.company ?? 'perusahaan';
    final emergencyNumber = _companyEmergencyNumberText(profile);
    final radioContact = _companyRadioText(profile);
    final simperLicenseNumber =
        IdCardPdfService.firstActiveSimperLicenseNumber(profile);

    return _PreviewCardFrame(
      width: width,
      child: Stack(
        children: [
          const Positioned(
            left: 0,
            right: 0,
            top: 8,
            child: Text(
              'SIMPER',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF28B463),
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            top: 26,
            child: Text(
              simperLicenseNumber,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF303744),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Positioned(
            left: 5,
            right: 5,
            top: 56,
            child: _previewTable(rows),
          ),
          const Positioned(
            left: 18,
            right: 18,
            top: 210,
            child: SizedBox(
              width: double.infinity,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Text(
                  'F: Full   P: Probation   R: Restricted   T: Training   I: Instructor',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 6.2,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 5,
            right: 5,
            top: 223,
            child: Container(height: 1, color: Colors.black),
          ),
          Positioned(
            left: 6,
            right: 6,
            top: 229,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Catatan:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
                _rulePreview('1',
                  'Kartu ini harus dipakai selama berada di area kerja dan digunakan sebatas izin akses ke area pertambangan.',
                ),
                _rulePreview('2',
                  'Kartu ini milik $companyName, pemegang kartu wajib mengembalikan kartu ini jika habis masa berlaku.',
                ),
                _rulePreview('3',
                    'Segera laporkan ke QHSE jika kehilangan kartu ini.'),
              ],
            ),
          ),
          Positioned(
            left: 5,
            right: 5,
            top: 290,
            child: Container(
              height: 14,
              color: const Color(0xFFE31B23),
              alignment: Alignment.center,
              child: const Text(
                'EMERGENCY CONTACT',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 6.4,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Positioned(
            left: 5,
            right: 5,
            top: 303,
            child: Container(
              height: 24,
              color: Colors.white,
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    emergencyNumber,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 10.4,
                      fontWeight: FontWeight.bold,
                      height: 0.95,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    radioContact,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 8.8,
                      fontWeight: FontWeight.bold,
                      height: 0.95,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: 23,
              color: const Color(0xFF00A651),
              alignment: Alignment.center,
              child: const Text(
                'WAJIB MEMATUHI PERATURAN K3LH\nSELAMA BERADA DI JOB SITE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  height: 1.05,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _companyEmergencyNumberText(ProfileData profile) {
    return profile.companyDetail?.emergencyNumber?.trim() ?? '';
  }

  static String _companyRadioText(ProfileData profile) {
    final channel = profile.companyDetail?.radioChannel?.trim() ?? '';
    return [
      profile.companyDetail?.radioLabel,
      channel.isEmpty ? null : 'Channel $channel',
    ]
        .map((value) => value?.trim() ?? '')
        .where((value) => value.isNotEmpty)
        .join(' ');
  }

  static Widget _previewTable(List<MinePermitTableRow> rows) {
    const border = BorderSide(color: Colors.black, width: 0.7);
    return Table(
      border: TableBorder.all(color: border.color, width: border.width),
      columnWidths: const {
        0: FlexColumnWidth(0.7),
        1: FlexColumnWidth(3.05),
        2: FlexColumnWidth(0.55),
        3: FlexColumnWidth(1.2),
      },
      children: [
        const TableRow(
          decoration: BoxDecoration(color: Color(0xFF2F73C8)),
          children: [
            _PreviewHeader('TYPE'),
            _PreviewHeader('VEHICLE / EQUIPMENT'),
            _PreviewHeader('LIC'),
            _PreviewHeader('EXP DATE'),
          ],
        ),
        ...rows.map(
          (row) => TableRow(
            children: [
              _PreviewCell(row.code, bold: true),
              _PreviewCell(row.vehicleEquipment, alignLeft: true),
              _PreviewCell(row.licenseNumber),
              _PreviewCell(row.issuedDate),
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewCardFrame extends StatelessWidget {
  final double width;
  final Widget child;

  const _PreviewCardFrame({
    required this.width,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 55 / 86,
        child: Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.black, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: child,
          ),
        ),
      ),
    );
  }
}

class _MiniCounterPreview extends StatelessWidget {
  final String title;

  const _MiniCounterPreview(this.title);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 70,
      child: Column(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF2F73C8),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          Table(
            border: TableBorder.all(
              color: Colors.black,
              width: 0.7,
            ),
            children: const [
              TableRow(
                children: [
                  _PreviewCell('1', bold: true),
                  _PreviewCell('2', bold: true),
                  _PreviewCell('3', bold: true),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniSignaturePreview extends StatelessWidget {
  final ProfileData profile;

  const _MiniSignaturePreview({required this.profile});

  @override
  Widget build(BuildContext context) {
    final kttSignatureUrl =
        profile.companyDetail?.kttSignatureUrl?.trim() ?? '';
    final companyStampUrl = profile.companyDetail?.companyStampUrl?.trim() ?? '';
    final kttName = profile.companyDetail?.kttUser?.fullName ??
        _defaultKttNameForOwner(profile.company);

    return SizedBox(
      width: 98,
      child: Column(
        children: [
          const Text(
            'Disahkan oleh,',
            style: TextStyle(
              color: Color(0xFF2F73C8),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 70,
            height: 13,
            child: Row(
              children: [
                Expanded(
                  child: _signatureImage(
                    kttSignatureUrl,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _signatureImage(
                    companyStampUrl,
                    fallback: const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            kttName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 6.2, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 1),
          const Text(
            'Kepala Teknik Tambang',
            style: TextStyle(
              color: Color(0xFF2F73C8),
              fontSize: 6,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

String _defaultKttNameForOwner(String? ownerCompany) {
  final value = (ownerCompany ?? '').toLowerCase();
  if (value.contains('khotai')) return 'Agah Wahyu Nugraha, S.T';
  return 'Reno Barus, S.T';
}

Widget _signatureImage(String url, {required Widget fallback}) {
  if (url.isEmpty) return fallback;
  return _isSvgUrl(url)
      ? SvgPicture.network(
          url,
          fit: BoxFit.contain,
          placeholderBuilder: (_) => fallback,
        )
      : Image.network(
          url,
          fit: BoxFit.contain,
          errorBuilder: (_, __, ___) => fallback,
        );
}

class _AccessTypePreview extends StatelessWidget {
  const _AccessTypePreview();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      child: Column(
        children: [
          const Text(
            'ACCESS TYPE',
            style: TextStyle(
              color: Color(0xFF2F73C8),
              fontSize: 6.8,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Table(
            border: TableBorder.all(
              color: Colors.black,
              width: 0.4,
            ),
            columnWidths: const {
              0: FlexColumnWidth(),
              1: FlexColumnWidth(),
              2: FlexColumnWidth(),
              3: FlexColumnWidth(),
              4: FlexColumnWidth(),
            },
            children: const [
              TableRow(
                children: [
                  _AccessTypeCell('T1'),
                  _AccessTypeCell('T2'),
                  _AccessTypeCell('T3'),
                  _AccessTypeCell('T4'),
                  _AccessTypeCell('T5'),
                ],
              ),
              TableRow(
                children: [
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                  _AccessTypeCell(''),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccessTypeCell extends StatelessWidget {
  final String text;

  const _AccessTypeCell(this.text);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 7.4,
      child: Center(
        child: Text(
          text,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 6.2,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
      ),
    );
  }
}

Widget _rulePreview(String number, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 7,
          child: Text(
            '$number.',
            style: const TextStyle(
              color: Colors.black,
              fontSize: 7.8,
              height: 1.05,
            ),
          ),
        ),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 7.8,
              height: 1.05,
            ),
          ),
        ),
      ],
    ),
  );
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  final chars = parts
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0])
      .join()
      .toUpperCase();
  return chars.isEmpty ? '?' : chars;
}

class _PreviewHeader extends StatelessWidget {
  final String text;

  const _PreviewHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final isVehicle = text == 'VEHICLE / EQUIPMENT';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
      child: Text(
        text,
        maxLines: 1,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white,
          fontSize: isVehicle ? 6.2 : 5.6,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}

class _PreviewCell extends StatelessWidget {
  final String text;
  final bool bold;
  final bool alignLeft;

  const _PreviewCell(this.text, {this.bold = false, this.alignLeft = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(alignLeft ? 5 : 2, 3, 2, 3),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignLeft ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          fontSize: text.length > 14 ? 6 : 7,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
