// lib/models/school_class.dart

import 'subject.dart';
import 'student.dart';
import 'grade.dart';

// ── GradeSlot ─────────────────────────────────────────────────────────────────
//
// Represents one student sitting in a grade column for a given subject.
// This is the data unit the shake animation will work with:
// each slot is a circle on the bar chart that can "fall" to a new grade.
//
// Step N (animation) will turn these into animated widgets. For now the
// overview screen only reads them to build the bar heights.
class GradeSlot {
  final Student student;
  final Grade grade;
  final String subjectId;

  const GradeSlot({
    required this.student,
    required this.grade,
    required this.subjectId,
  });

  GradeSlot withGrade(Grade newGrade) =>
      GradeSlot(student: student, grade: newGrade, subjectId: subjectId);
}

// ── SchoolClass ───────────────────────────────────────────────────────────────

class SchoolClass {
  final String id;
  final String name;
  final List<Subject> subjects;
  final List<Student> students;

  const SchoolClass({
    required this.id,
    required this.name,
    this.subjects = const [],
    this.students = const [],
  });

  SchoolClass copyWith({
    String? id,
    String? name,
    List<Subject>? subjects,
    List<Student>? students,
  }) => SchoolClass(
    id: id ?? this.id,
    name: name ?? this.name,
    subjects: subjects ?? List.of(this.subjects),
    students: students ?? List.of(this.students),
  );

  SchoolClass withStudent(Student student) =>
      copyWith(students: [...students, student]);

  SchoolClass withSubject(Subject subject) =>
      copyWith(subjects: [...subjects, subject]);

  SchoolClass withUpdatedStudent(Student updated) => copyWith(
    students: students.map((s) => s.id == updated.id ? updated : s).toList(),
  );

  // ── Grade queries ─────────────────────────────────────────────────────────

  List<Grade> gradesForSubject(String subjectId) => students
      .map((s) => s.gradeFor(subjectId))
      .whereType<Grade>()
      .toList();

  List<Grade> get allGrades => students
      .expand((s) => s.grades.values.whereType<Grade>())
      .toList();

  /// Returns one GradeSlot per graded student for [subjectId].
  /// This is the list the overview chart (and later shake animation) consumes.
  List<GradeSlot> gradeSlotsForSubject(String subjectId) => students
      .where((s) => s.gradeFor(subjectId) != null)
      .map((s) => GradeSlot(
            student: s,
            grade: s.gradeFor(subjectId)!,
            subjectId: subjectId,
          ))
      .toList();

  /// Groups GradeSlots by grade — handy for building bar chart data.
  Map<Grade, List<GradeSlot>> slotsByGrade(String subjectId) {
    final slots = gradeSlotsForSubject(subjectId);
    final map = {for (final g in allGradesConst) g: <GradeSlot>[]};
    for (final slot in slots) {
      map[slot.grade]!.add(slot);
    }
    return map;
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'subjects': subjects.map((s) => s.toJson()).toList(),
    'students': students.map((s) => s.toJson()).toList(),
  };

  factory SchoolClass.fromJson(Map<String, dynamic> json) => SchoolClass(
    id: json['id'] as String,
    name: json['name'] as String,
    subjects: (json['subjects'] as List<dynamic>)
        .map((s) => Subject.fromJson(s as Map<String, dynamic>))
        .toList(),
    students: (json['students'] as List<dynamic>)
        .map((s) => Student.fromJson(s as Map<String, dynamic>))
        .toList(),
  );

  // ─────────────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SchoolClass && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SchoolClass($name, ${students.length} students)';
}

// Alias so school_class.dart can reference the full grade list without
// creating a circular import with grade.dart's top-level `allGrades`.
const allGradesConst = Grade.values;