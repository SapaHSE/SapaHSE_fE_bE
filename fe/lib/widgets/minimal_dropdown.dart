import 'package:flutter/material.dart';

// ── Shared design tokens for the modernized dropdown look ────────────────────
// The visual is a "floating card": white surface, soft shadow, no border,
// 14px radius, subtle chevron, dark-but-not-black text. Used consistently
// across every screen so the app feels visually unified.

const double kMinimalDropdownRadius = 10;
const double kMinimalDropdownHeight = 44;
const Color kMinimalDropdownText = Color(0xFF1F2937);
const Color kMinimalDropdownLabel = Color(0xFF6B7280);
const Color kMinimalDropdownMuted = Color(0xFF9CA3AF);

List<BoxShadow> kMinimalDropdownShadow = [
  BoxShadow(
    color: Colors.black.withValues(alpha: 0.06),
    blurRadius: 10,
    offset: const Offset(0, 2),
  ),
];

const TextStyle kMinimalDropdownTextStyle = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w500,
  color: kMinimalDropdownText,
);

const TextStyle kMinimalDropdownLabelStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w500,
  color: kMinimalDropdownLabel,
);

const TextStyle kMinimalDropdownCountStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w400,
  color: kMinimalDropdownMuted,
);

const Icon kMinimalDropdownChevron = Icon(
  Icons.keyboard_arrow_down_rounded,
  size: 20,
  color: kMinimalDropdownMuted,
);

// ── Filter-style dropdown ────────────────────────────────────────────────────
// Drop-in replacement for plain DropdownButton wrapped in a styled Container.
// Use for filters / pickers that aren't part of a Form.
class MinimalDropdown<T> extends StatelessWidget {
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;
  final bool isExpanded;
  final double height;
  final EdgeInsetsGeometry padding;

  const MinimalDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.isExpanded = true,
    this.height = kMinimalDropdownHeight,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
        boxShadow: kMinimalDropdownShadow,
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: isExpanded,
          icon: kMinimalDropdownChevron,
          borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
          elevation: 4,
          dropdownColor: Colors.white,
          style: kMinimalDropdownTextStyle,
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Form-field decoration ────────────────────────────────────────────────────
// Returns an InputDecoration that gives a DropdownButtonFormField (or a
// TextFormField, for that matter) the same floating-card visual. Use when the
// dropdown lives inside a Form and needs validator/label/hint support.
InputDecoration minimalFieldDecoration({
  String? hintText,
  IconData? prefixIcon,
  Widget? suffixIcon,
  EdgeInsetsGeometry? contentPadding,
}) {
  return InputDecoration(
    hintText: hintText,
    hintStyle: const TextStyle(color: Colors.grey, fontSize: 13),
    prefixIcon: prefixIcon != null
        ? Icon(prefixIcon, color: Colors.grey, size: 20)
        : null,
    suffixIcon: suffixIcon,
    contentPadding: contentPadding ??
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    filled: true,
    fillColor: const Color(0xFFF8F8F8),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
      borderSide: BorderSide(color: Colors.grey.shade300),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
      borderSide: const BorderSide(color: Color(0xFF1A56C4), width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
      borderSide: const BorderSide(color: Colors.red),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
      borderSide: const BorderSide(color: Colors.red, width: 1.5),
    ),
  );
}

// Decoration for the surrounding Container of a form-field dropdown so the
// floating-card shadow shows beneath the field.
BoxDecoration kMinimalFieldContainerDecoration = BoxDecoration(
  color: const Color(0xFFF8F8F8),
  borderRadius: BorderRadius.circular(kMinimalDropdownRadius),
);
