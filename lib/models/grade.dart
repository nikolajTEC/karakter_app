// lib/models/grade.dart
//
// The Danish 7-step grading scale (7-trinsskalaen).
// Each grade has a display label, a numeric value used for statistics,
// and a color for the wheel segments.

import 'package:flutter/material.dart';

enum Grade {
  minusThree,
  zero,
  two,
  four,
  seven,
  ten,
  twelve,
}

extension GradeExtension on Grade {
  /// The label shown on the wheel and in the UI.
  String get label {
    switch (this) {
      case Grade.minusThree:
        return '-3';
      case Grade.zero:
        return '00';
      case Grade.two:
        return '02';
      case Grade.four:
        return '4';
      case Grade.seven:
        return '7';
      case Grade.ten:
        return '10';
      case Grade.twelve:
        return '12';
    }
  }

  /// Numeric value used for computing distribution statistics.
  int get numericValue {
    switch (this) {
      case Grade.minusThree:
        return -3;
      case Grade.zero:
        return 0;
      case Grade.two:
        return 2;
      case Grade.four:
        return 4;
      case Grade.seven:
        return 7;
      case Grade.ten:
        return 10;
      case Grade.twelve:
        return 12;
    }
  }

  /// Color used for this grade on the wheel and charts.
  Color get color {
    switch (this) {
      case Grade.minusThree:
        return const Color(0xFFE53935); // deep red
      case Grade.zero:
        return const Color(0xFFEF6C00); // orange
      case Grade.two:
        return const Color(0xFFFDD835); // yellow
      case Grade.four:
        return const Color(0xFF8BC34A); // light green
      case Grade.seven:
        return const Color(0xFF43A047); // green
      case Grade.ten:
        return const Color(0xFF1E88E5); // blue
      case Grade.twelve:
        return const Color(0xFF5E35B1); // purple
    }
  }

  /// Whether this is considered a passing grade (02 and above).
  bool get isPassing => numericValue >= 2;
}

/// All grades in ascending order — useful for building the wheel.
const List<Grade> allGrades = Grade.values;