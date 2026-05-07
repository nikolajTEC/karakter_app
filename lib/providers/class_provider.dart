// lib/providers/class_provider.dart
//
// Single source of truth. Persists to shared_preferences on every change.
// Also exposes redistributeGrades() used by the shake feature.

import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../models/grade.dart';
import '../models/school_class.dart';
import '../models/student.dart';
import '../models/subject.dart';

const _uuid = Uuid();
const _storageKey = 'grade_wheel_classes';
const _selectedClassKey = 'grade_wheel_selected_class';

class ClassProvider extends ChangeNotifier {
  // ── State ─────────────────────────────────────────────────────────────────

  List<SchoolClass> _classes = [];
  String? _selectedClassId;
  bool _isLoaded = false;

  // ── Read-only accessors ───────────────────────────────────────────────────

  List<SchoolClass> get classes => List.unmodifiable(_classes);
  bool get isLoaded => _isLoaded;

  SchoolClass? get selectedClass => _classes
      .cast<SchoolClass?>()
      .firstWhere((c) => c?.id == _selectedClassId, orElse: () => null);

  // ── Persistence ───────────────────────────────────────────────────────────

  /// Call once at startup (done in main.dart via ClassProvider()..load()).
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _classes = list
          .map((e) => SchoolClass.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    _selectedClassId = prefs.getString(_selectedClassKey);
    // Fall back to first class if saved selection is gone
    if (_selectedClassId == null ||
        !_classes.any((c) => c.id == _selectedClassId)) {
      _selectedClassId = _classes.isNotEmpty ? _classes.first.id : null;
    }
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_classes.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
    if (_selectedClassId != null) {
      await prefs.setString(_selectedClassKey, _selectedClassId!);
    }
  }

  // ── Class management ──────────────────────────────────────────────────────

  SchoolClass addClass(String name) {
    final newClass = SchoolClass(id: _uuid.v4(), name: name);
    _classes = [..._classes, newClass];
    _selectedClassId ??= newClass.id;
    _notify();
    return newClass;
  }

  void selectClass(String classId) {
    _selectedClassId = classId;
    _notify();
  }

  void deleteClass(String classId) {
    _classes = _classes.where((c) => c.id != classId).toList();
    if (_selectedClassId == classId) {
      _selectedClassId = _classes.isNotEmpty ? _classes.first.id : null;
    }
    _notify();
  }

  // ── Subject management ────────────────────────────────────────────────────

  void addSubject(String classId, String subjectName) {
    final subject = Subject(id: _uuid.v4(), name: subjectName);
    _updateClass(classId, (c) => c.withSubject(subject));
  }

  void removeSubject(String classId, String subjectId) {
    _updateClass(classId, (c) {
      return c.copyWith(
        subjects: c.subjects.where((s) => s.id != subjectId).toList(),
        students: c.students.map((s) {
          final newGrades = Map<String, Grade?>.of(s.grades)..remove(subjectId);
          return s.copyWith(grades: newGrades);
        }).toList(),
      );
    });
  }

  // ── Student management ────────────────────────────────────────────────────

  void addStudent(String classId, String studentName) {
    final cls = _classById(classId);
    if (cls == null) return;
    final grades = {for (final s in cls.subjects) s.id: null as Grade?};
    final student = Student(id: _uuid.v4(), name: studentName, grades: grades);
    _updateClass(classId, (c) => c.withStudent(student));
  }

  void removeStudent(String classId, String studentId) {
    _updateClass(classId, (c) => c.copyWith(
          students: c.students.where((s) => s.id != studentId).toList(),
        ));
  }

  // ── Grading ───────────────────────────────────────────────────────────────

  void setGrade(
      String classId, String studentId, String subjectId, Grade grade) {
    _updateClass(classId, (c) {
      final student = c.students.firstWhere((s) => s.id == studentId);
      return c.withUpdatedStudent(student.withGrade(subjectId, grade));
    });
  }

  // ── Complaint handling ────────────────────────────────────────────────────

  void setComplaintActive(String classId, String studentId, bool active) {
    _updateClass(classId, (c) {
      final student = c.students.firstWhere((s) => s.id == studentId);
      return c.withUpdatedStudent(
          student.copyWith(hasActiveComplaint: active));
    });
  }

  // ── Shake redistribution ──────────────────────────────────────────────────
  //
  // Redistributes grades for [subjectId] in [classId] so the overall
  // distribution better matches expectedNormalDistribution.
  //
  // Algorithm:
  //   1. Count how many students are graded for the subject.
  //   2. Compute target counts per grade from the expected percentages.
  //   3. Build a shuffled list of target grades and assign one per student.
  //
  // This is called by the overview screen when a shake is detected.
  // The animation layer (future step) will interpolate the old→new positions.
  void redistributeGrades(String classId, String subjectId) {
    final cls = _classById(classId);
    if (cls == null) return;

    final gradedStudents = cls.students
        .where((s) => s.gradeFor(subjectId) != null)
        .toList();
    if (gradedStudents.isEmpty) return;

    final n = gradedStudents.length;

    // Build target distribution
    final targetGrades = _buildTargetGradeList(n);

    // Shuffle so assignment is random
    targetGrades.shuffle(Random());

    // Apply new grades
    _updateClass(classId, (c) {
      var updated = c;
      for (var i = 0; i < gradedStudents.length; i++) {
        final student = gradedStudents[i];
        updated = updated.withUpdatedStudent(
            student.withGrade(subjectId, targetGrades[i]));
      }
      return updated;
    });
  }

  /// Builds a list of [n] grades whose proportions match
  /// [expectedNormalDistribution] as closely as possible.
  List<Grade> _buildTargetGradeList(int n) {
    final result = <Grade>[];
    int assigned = 0;

    // Assign floor(n * proportion) for each grade
    final remainders = <Grade, double>{};
    for (final entry in expectedNormalDistribution.entries) {
      final exact = n * entry.value;
      final floor = exact.floor();
      result.addAll(List.filled(floor, entry.key));
      assigned += floor;
      remainders[entry.key] = exact - floor;
    }

    // Fill remaining slots with grades that have the largest remainders
    final remaining = n - assigned;
    final sorted = remainders.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (var i = 0; i < remaining; i++) {
      result.add(sorted[i % sorted.length].key);
    }

    return result;
  }

  // ── Seed data ─────────────────────────────────────────────────────────────

  void seedDemoData() {
    if (_classes.isNotEmpty) return;
    final classA = addClass('3A');
    addSubject(classA.id, 'Matematik');
    addSubject(classA.id, 'Dansk');
    addSubject(classA.id, 'Engelsk');
    for (final name in ['Alice', 'Bob', 'Clara', 'David', 'Eva']) {
      addStudent(classA.id, name);
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  SchoolClass? _classById(String classId) => _classes
      .cast<SchoolClass?>()
      .firstWhere((c) => c?.id == classId, orElse: () => null);

  void _updateClass(String classId, SchoolClass Function(SchoolClass) update) {
    _classes = _classes.map((c) => c.id == classId ? update(c) : c).toList();
    _notify();
  }

  void _notify() {
    notifyListeners();
    _save(); // fire-and-forget persist
  }
}