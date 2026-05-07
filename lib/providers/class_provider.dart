// lib/providers/class_provider.dart
//
// FULL provider with gradual shake redistribution

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
  List<SchoolClass> _classes = [];
  String? _selectedClassId;
  bool _isLoaded = false;

  List<SchoolClass> get classes => List.unmodifiable(_classes);
  bool get isLoaded => _isLoaded;

  SchoolClass? get selectedClass {
    try {
      return _classes.firstWhere((c) => c.id == _selectedClassId);
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────
  // LOAD / SAVE
  // ─────────────────────────────────────────────────────────

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    if (raw != null) {
      final list = jsonDecode(raw) as List<dynamic>;
      _classes =
          list.map((e) => SchoolClass.fromJson(e as Map<String, dynamic>)).toList();
    }

    _selectedClassId = prefs.getString(_selectedClassKey);
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

  void _notify() {
    notifyListeners();
    _save();
  }

  // ─────────────────────────────────────────────────────────
  // CLASS CRUD
  // ─────────────────────────────────────────────────────────

  SchoolClass addClass(String name) {
    final newClass = SchoolClass(id: _uuid.v4(), name: name);
    _classes = [..._classes, newClass];
    _selectedClassId ??= newClass.id;
    _notify();
    return newClass;
  }

  void selectClass(String id) {
    _selectedClassId = id;
    _notify();
  }

  // ─────────────────────────────────────────────────────────
  // SUBJECT CRUD
  // ─────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────
  // STUDENT CRUD
  // ─────────────────────────────────────────────────────────

  void addStudent(String classId, String name) {
    final cls = _classById(classId);
    if (cls == null) return;

    final grades = {for (final s in cls.subjects) s.id: null as Grade?};
    final student = Student(id: _uuid.v4(), name: name, grades: grades);

    _updateClass(classId, (c) => c.withStudent(student));
  }

  void removeStudent(String classId, String studentId) {
    _updateClass(classId,
        (c) => c.copyWith(students: c.students.where((s) => s.id != studentId).toList()));
  }

  // ─────────────────────────────────────────────────────────
  // GRADING
  // ─────────────────────────────────────────────────────────

  void setGrade(String classId, String studentId, String subjectId, Grade grade) {
    _updateClass(classId, (c) {
      final student = c.students.firstWhere((s) => s.id == studentId);
      return c.withUpdatedStudent(student.withGrade(subjectId, grade));
    });
  }

  // ─────────────────────────────────────────────────────────
  // SHAKE REDISTRIBUTION (GRADUAL & PHYSICS FRIENDLY)
  // ─────────────────────────────────────────────────────────

  void redistributeGrades(String classId, String subjectId) {
  final cls = _classById(classId);
  if (cls == null) return;

  final gradedStudents =
      cls.students.where((s) => s.gradeFor(subjectId) != null).toList();
  if (gradedStudents.isEmpty) return;

  final n = gradedStudents.length;

  // MAX 10% movement per shake
  final maxMoves = max(1, (n * 0.10).ceil());

  // current counts
  final currentCounts = {
    for (final g in expectedNormalDistribution.keys) g: 0,
  };

  for (final s in gradedStudents) {
    final g = s.gradeFor(subjectId)!;
    currentCounts[g] = currentCounts[g]! + 1;
  }

  // target counts (Gaussian expectation)
  final targetCounts = {
    for (final g in expectedNormalDistribution.keys)
      g: (expectedNormalDistribution[g]! * n).round()
  };

  int moves = 0;
  final rand = Random();

  // WORKING COPY
  final workingStudents = gradedStudents.toList();

  while (moves < maxMoves) {
  Grade? fromGrade;

  // STRICT: only grades that are OVER target
  for (final g in allGrades) {
    if (currentCounts[g]! > targetCounts[g]!) {
      fromGrade = g;
      break;
    }
  }

  if (fromGrade == null) break;

  final fromIndex = allGrades.indexOf(fromGrade);

  // possible destinations = ONLY underrepresented grades
  final candidates = <Grade>[];

  if (fromIndex > 0) {
    final g = allGrades[fromIndex - 1];
    if (currentCounts[g]! < targetCounts[g]!) {
      candidates.add(g);
    }
  }

  if (fromIndex < allGrades.length - 1) {
    final g = allGrades[fromIndex + 1];
    if (currentCounts[g]! < targetCounts[g]!) {
      candidates.add(g);
    }
  }

  if (candidates.isEmpty) {
    // no valid move → mark as fixed and continue
    currentCounts[fromGrade] = targetCounts[fromGrade]!;
    continue;
  }

  // pick most underrepresented neighbor
  candidates.sort((a, b) =>
      (currentCounts[a]! - targetCounts[a]!)
          .compareTo(currentCounts[b]! - targetCounts[b]!));

  final toGrade = candidates.first;

  final pool = gradedStudents
      .where((s) => s.gradeFor(subjectId) == fromGrade)
      .toList();

  if (pool.isEmpty) {
    currentCounts[fromGrade] = targetCounts[fromGrade]!;
    continue;
  }

  final student = pool[Random().nextInt(pool.length)];

  _updateClass(classId, (c) {
    return c.withUpdatedStudent(
      student.withGrade(subjectId, toGrade),
    );
  });

  currentCounts[fromGrade] = currentCounts[fromGrade]! - 1;
  currentCounts[toGrade] = currentCounts[toGrade]! + 1;

  moves++;
}
}

  // ─────────────────────────────────────────────────────────
  // DEMO DATA
  // ─────────────────────────────────────────────────────────

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

  // ─────────────────────────────────────────────────────────

  SchoolClass? _classById(String id) {
    try {
      return _classes.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  void _updateClass(String classId, SchoolClass Function(SchoolClass) update) {
    _classes = _classes.map((c) => c.id == classId ? update(c) : c).toList();
    _notify();
  }
}