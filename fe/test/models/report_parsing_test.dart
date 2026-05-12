import 'package:flutter_test/flutter_test.dart';
import 'package:sapahse/models/report.dart';

void main() {
  group('Report hazard category parsing', () {
    test('uses backend hazard_category_names as-is for hazard report detail', () {
      final report = Report.fromJson({
        'id': 'r-1',
        'type': 'hazard',
        'title': 'Unsafe ladder setup',
        'description': 'Ladder is not secured.',
        'status': 'open',
        'sub_status': 'validating',
        'severity': 'medium',
        'location': 'Workshop',
        'hazard_category': 'KTA,TTA',
        'hazard_category_codes': ['KTA', 'TTA'],
        'hazard_category_names': [
          'KTA (Kondisi Tidak Aman)',
          'TTA (Tindakan Tidak Aman)'
        ],
        'created_at': '2026-05-12 10:00:00',
        'reported_by': {'id': 'u-1', 'full_name': 'Reporter'},
      });

      expect(report.hazardCategoryCodes, equals(['KTA', 'TTA']));
      expect(
        report.hazardCategoryNames,
        equals(['KTA (Kondisi Tidak Aman)', 'TTA (Tindakan Tidak Aman)']),
      );
    });

    test('falls back to normalized CSV codes when names are not provided', () {
      final report = Report.fromJson({
        'id': 'r-2',
        'type': 'hazard',
        'title': 'Missing handrail',
        'description': 'Stair has no handrail.',
        'status': 'open',
        'severity': 'high',
        'location': 'Plant',
        'hazard_category': ' kta , TTA , KTA ',
        'created_at': '2026-05-12 10:00:00',
        'reported_by': {'id': 'u-2', 'full_name': 'Reporter'},
      });

      expect(report.hazardCategoryCodes, equals(['KTA', 'TTA']));
      expect(report.hazardCategoryNames, equals(['KTA', 'TTA']));
    });
  });

  group('Report status display', () {
    test('legacy pending is mapped to open', () {
      final report = Report.fromJson({
        'id': 'r-3',
        'type': 'hazard',
        'title': 'Legacy status',
        'description': 'Legacy pending payload',
        'status': 'pending',
        'severity': 'low',
        'location': 'Warehouse',
        'created_at': '2026-05-12 10:00:00',
        'reported_by': {'id': 'u-3', 'full_name': 'Reporter'},
      });

      expect(report.status, ReportStatus.open);
    });

    test('validating sub-status always displays as Validating on open status', () {
      final report = Report.fromJson({
        'id': 'r-4',
        'type': 'hazard',
        'title': 'Validation queue',
        'description': 'Need admin check',
        'status': 'open',
        'sub_status': 'validating',
        'severity': 'medium',
        'location': 'Yard',
        'created_at': '2026-05-12 10:00:00',
        'reported_by': {'id': 'u-4', 'full_name': 'Reporter'},
      });

      expect(report.displayStatus, ReportStatus.open);
      expect(report.displayStatusLabel, 'Validating');
    });
  });
}
