// lib/models/grade.dart
//
// The Danish 7-step grading scale (7-trinsskalaen).

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
  String get label {
    switch (this) {
      case Grade.minusThree: return '-3';
      case Grade.zero:       return '00';
      case Grade.two:        return '02';
      case Grade.four:       return '4';
      case Grade.seven:      return '7';
      case Grade.ten:        return '10';
      case Grade.twelve:     return '12';
    }
  }

  int get numericValue {
    switch (this) {
      case Grade.minusThree: return -3;
      case Grade.zero:       return 0;
      case Grade.two:        return 2;
      case Grade.four:       return 4;
      case Grade.seven:      return 7;
      case Grade.ten:        return 10;
      case Grade.twelve:     return 12;
    }
  }

  Color get color {
    switch (this) {
      case Grade.minusThree: return const Color(0xFFE53935);
      case Grade.zero:       return const Color(0xFFEF6C00);
      case Grade.two:        return const Color(0xFFFDD835);
      case Grade.four:       return const Color(0xFF8BC34A);
      case Grade.seven:      return const Color(0xFF43A047);
      case Grade.ten:        return const Color(0xFF1E88E5);
      case Grade.twelve:     return const Color(0xFF5E35B1);
    }
  }

  bool get isPassing => numericValue >= 2;

  /// Serialisation key — stable string stored in JSON.
  String get jsonKey => label;
}

/// Deserialise a grade from its JSON key (the label string).
Grade gradeFromJson(String key) =>
    allGrades.firstWhere((g) => g.label == key);

/// All grades in ascending order.
const List<Grade> allGrades = Grade.values;

// ── Normal distribution ───────────────────────────────────────────────────────
//
// Expected proportion of students at each grade level in a typical class,
// based on Danish grading guidelines. Used by the overview screen.
//
// These are approximate; they sum to 1.0.
const Map<Grade, double> expectedNormalDistribution = {
  Grade.minusThree: 0.02,
  Grade.zero:       0.05,
  Grade.two:        0.10,
  Grade.four:       0.15,
  Grade.seven:      0.30,
  Grade.ten:        0.25,
  Grade.twelve:     0.13,
};