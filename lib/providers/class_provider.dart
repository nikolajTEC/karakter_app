// lib/providers/class_provider.dart

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
      try {
        final list = jsonDecode(raw) as List<dynamic>;
        _classes = list
            .map((e) => SchoolClass.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('Error loading classes: $e');
        _classes = [];
      }
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
  // SHAKE REDISTRIBUTION
  // ─────────────────────────────────────────────────────────

void redistributeGrades(String classId, String subjectId) {
  final cls = _classById(classId);
  if (cls == null) return;

  // 1. Get ONLY students who have a grade for this specific subject
  final candidates = cls.students
      .where((s) => s.gradeFor(subjectId) != null)
      .toList();

  if (candidates.isEmpty) return;

  final n = candidates.length;
  final random = Random();

  // Target grade

  final Map<Grade, double> idealRatios = {
    Grade.minusThree: 0.02,
    Grade.zero:       0.05,
    Grade.two:        0.10,
    Grade.four:       0.23,
    Grade.seven:      (n > 10) ? 0.35 : 0.40, // Heavy bias
    Grade.ten:        0.20,
    Grade.twelve:     0.05,
  };

  // 3. Current count for THIS subject
  final currentCounts = {for (var g in Grade.values) g: 0};
  for (var s in candidates) {
    final g = s.gradeFor(subjectId)!;
    currentCounts[g] = currentCounts[g]! + 1;
  }

  // 4. Force 3-5 movements per shake call
  int movesMade = 0;
  for (int i = 0; i < 5; i++) {
    // Find all grades that are currently ABOVE their ideal ratio
    final overPopulated = Grade.values.where((g) {
      return currentCounts[g]! > (idealRatios[g]! * n);
    }).toList();

    // Find all grades that are currently BELOW their ideal ratio
    final underPopulated = Grade.values.where((g) {
      return currentCounts[g]! < (idealRatios[g]! * n);
    }).toList();

    // If we are perfectly balanced, or no one can move, break
    if (overPopulated.isEmpty || underPopulated.isEmpty) break;

    // Pick a random source and a random destination (allows "jumping" columns)
    final fromGrade = overPopulated[random.nextInt(overPopulated.length)];
    final toGrade = underPopulated[random.nextInt(underPopulated.length)];

    final studentPool = candidates.where((s) => s.gradeFor(subjectId) == fromGrade).toList();
    
    if (studentPool.isNotEmpty) {
      final student = studentPool[random.nextInt(studentPool.length)];
      
      // Update the student in the list
      _updateClass(classId, (c) => c.withUpdatedStudent(student.withGrade(subjectId, toGrade)));
      
      // Update local tracking for the next iteration of this loop
      currentCounts[fromGrade] = currentCounts[fromGrade]! - 1;
      currentCounts[toGrade] = currentCounts[toGrade]! + 1;
      movesMade++;
    }
  }
}

  // ─────────────────────────────────────────────────────────
  // COMPLAINTS
  // ─────────────────────────────────────────────────────────

  void toggleComplaint(String classId, String studentId) {
    _updateClass(classId, (c) {
      final student = c.students.firstWhere((s) => s.id == studentId);
      return c.withUpdatedStudent(
        student.copyWith(hasActiveComplaint: !student.hasActiveComplaint),
      );
    });
  }

  void resolveComplaint(String classId, String studentId) {
    _updateClass(classId, (c) {
      final student = c.students.firstWhere((s) => s.id == studentId);
      return c.withUpdatedStudent(
        student.copyWith(hasActiveComplaint: false),
      );
    });
  }

  void seedDemoData() {
    if (_classes.isNotEmpty) return;

    final random = Random();
    
    final classId = _uuid.v4();
    final List<Subject> subjects = [
      Subject(id: _uuid.v4(), name: 'Matematik'),
      Subject(id: _uuid.v4(), name: 'Dansk'),
      Subject(id: _uuid.v4(), name: 'Engelsk'),
    ];

    final names = [
      'Alice', 'Bob', 'Clara', 'David', 'Eva', 
      'Felix', 'Greta', 'Hugo', 'Ida', 'Johan',
      'Kasper', 'Line', 'Mads', 'Nora', 'Oscar'
    ];

    // Restricting available grades between 00 and 7 based on your enum
    final availableGrades = [
      Grade.zero,  // 00
      Grade.two,   // 02
      Grade.four,  // 4
      Grade.seven, // 7
    ];

    final List<Student> students = [];
    
    for (int i = 0; i < names.length; i++) {
      final Map<String, Grade?> grades = {};
      
      for (var sub in subjects) {
        grades[sub.id] = availableGrades[random.nextInt(availableGrades.length)];
      }

      students.add(Student(
        id: _uuid.v4(),
        name: names[i],
        grades: grades,
        hasActiveComplaint: i < 4, // Ensures exactly 4 have complaints
      ));
    }

    final demoClass = SchoolClass(
      id: classId,
      name: '3A',
      subjects: subjects,
      students: students,
    );

    _classes = [demoClass];
    _selectedClassId = classId;
    _notify();
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