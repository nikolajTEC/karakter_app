// lib/providers/class_provider.dart
//
// The single source of truth for the app's state.
// Wrap your MaterialApp with ChangeNotifierProvider<ClassProvider>
// and access it via context.watch<ClassProvider>() / context.read<ClassProvider>().

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/school_class.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../models/grade.dart';

const _uuid = Uuid();

class ClassProvider extends ChangeNotifier {
  // ── State ────────────────────────────────────────────────────────────────

  List<SchoolClass> _classes = [];
  String? _selectedClassId;

  // ── Read-only accessors ──────────────────────────────────────────────────

  List<SchoolClass> get classes => List.unmodifiable(_classes);

  SchoolClass? get selectedClass => _classes
      .cast<SchoolClass?>()
      .firstWhere((c) => c?.id == _selectedClassId, orElse: () => null);

  // ── Class management ─────────────────────────────────────────────────────

  SchoolClass addClass(String name) {
    final newClass = SchoolClass(id: _uuid.v4(), name: name);
    _classes = [..._classes, newClass];
    _selectedClassId ??= newClass.id; // auto-select first class
    notifyListeners();
    return newClass;
  }

  void selectClass(String classId) {
    _selectedClassId = classId;
    notifyListeners();
  }

  void deleteClass(String classId) {
    _classes = _classes.where((c) => c.id != classId).toList();
    if (_selectedClassId == classId) {
      _selectedClassId = _classes.isNotEmpty ? _classes.first.id : null;
    }
    notifyListeners();
  }

  // ── Subject management ───────────────────────────────────────────────────

  void addSubject(String classId, String subjectName) {
    final subject = Subject(id: _uuid.v4(), name: subjectName);
    _updateClass(classId, (c) => c.withSubject(subject));
  }

  void removeSubject(String classId, String subjectId) {
    _updateClass(classId, (c) {
      final updated = c.copyWith(
        subjects: c.subjects.where((s) => s.id != subjectId).toList(),
        // Also wipe that subject's grades from all students
        students: c.students
            .map((s) {
              final newGrades = Map<String, Grade?>.of(s.grades)
                ..remove(subjectId);
              return s.copyWith(grades: newGrades);
            })
            .toList(),
      );
      return updated;
    });
  }

  // ── Student management ───────────────────────────────────────────────────

  void addStudent(String classId, String studentName) {
    final cls = _classById(classId);
    if (cls == null) return;

    // Pre-populate grades map with null for each existing subject
    final grades = {for (final s in cls.subjects) s.id: null as Grade?};
    final student = Student(id: _uuid.v4(), name: studentName, grades: grades);
    _updateClass(classId, (c) => c.withStudent(student));
  }

  void removeStudent(String classId, String studentId) {
    _updateClass(classId, (c) => c.copyWith(
          students: c.students.where((s) => s.id != studentId).toList(),
        ));
  }

  // ── Grading ──────────────────────────────────────────────────────────────

  /// Set a specific grade for a student in a subject.
  void setGrade(String classId, String studentId, String subjectId, Grade grade) {
    _updateClass(classId, (c) {
      final student = c.students.firstWhere((s) => s.id == studentId);
      return c.withUpdatedStudent(student.withGrade(subjectId, grade));
    });
  }

  // ── Complaint handling ───────────────────────────────────────────────────

  void setComplaintActive(String classId, String studentId, bool active) {
    _updateClass(classId, (c) {
      final student = c.students.firstWhere((s) => s.id == studentId);
      return c.withUpdatedStudent(
          student.copyWith(hasActiveComplaint: active));
    });
  }

  // ── Private helpers ──────────────────────────────────────────────────────

  SchoolClass? _classById(String classId) {
    return _classes.cast<SchoolClass?>().firstWhere(
          (c) => c?.id == classId,
          orElse: () => null,
        );
  }

  void _updateClass(String classId, SchoolClass Function(SchoolClass) update) {
    _classes = _classes.map((c) => c.id == classId ? update(c) : c).toList();
    notifyListeners();
  }

  // ── Seed data (useful during development) ────────────────────────────────

  void seedDemoData() {
    if (_classes.isNotEmpty) return; // don't seed twice

    final classA = addClass('3A');

    addSubject(classA.id, 'Matematik');
    addSubject(classA.id, 'Dansk');
    addSubject(classA.id, 'Engelsk');

    for (final name in ['Alice', 'Bob', 'Clara', 'David', 'Eva']) {
      addStudent(classA.id, name);
    }
  }
}