import 'package:flutter_test/flutter_test.dart';
import 'package:sapahse/utils/value_parser.dart';

void main() {
  group('parseFlexibleBool', () {
    test('parses truthy values', () {
      expect(parseFlexibleBool(true), isTrue);
      expect(parseFlexibleBool(1), isTrue);
      expect(parseFlexibleBool('1'), isTrue);
      expect(parseFlexibleBool('true'), isTrue);
      expect(parseFlexibleBool('Aktif'), isTrue);
    });

    test('parses falsy values', () {
      expect(parseFlexibleBool(false), isFalse);
      expect(parseFlexibleBool(0), isFalse);
      expect(parseFlexibleBool('0'), isFalse);
      expect(parseFlexibleBool('false'), isFalse);
      expect(parseFlexibleBool('nonaktif'), isFalse);
    });

    test('uses default for null or unknown values', () {
      expect(parseFlexibleBool(null), isFalse);
      expect(parseFlexibleBool(null, defaultValue: true), isTrue);
      expect(parseFlexibleBool('unknown'), isFalse);
      expect(parseFlexibleBool('unknown', defaultValue: true), isTrue);
    });
  });

  group('parseNullableDisplayName', () {
    test('returns null for null and blank', () {
      expect(parseNullableDisplayName(null), isNull);
      expect(parseNullableDisplayName(''), isNull);
      expect(parseNullableDisplayName('   '), isNull);
    });

    test('returns trimmed name', () {
      expect(parseNullableDisplayName('  John Doe  '), equals('John Doe'));
      expect(parseNullableDisplayName('Siti'), equals('Siti'));
    });
  });
}
