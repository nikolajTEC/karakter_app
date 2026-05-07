// lib/models/school_class.dart
//
// A school class (klasse) owning a list of Subjects and Students.
// All students in a class share the same subjects.

import 'subject.dart';
import 'student.dart';
import 'grade.dart';

class SchoolClass {
  final String id;
  final String name; // e.g. "3A", "2B"
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
  }) {
    return SchoolClass(
      id: id ?? this.id,
      name: name ?? this.name,
      subjects: subjects ?? List.of(this.subjects),
      students: students ?? List.of(this.students),
    );
  }

  // ── Convenience helpers ──────────────────────────────────────────────────

  /// Returns a new SchoolClass with [student] appended.
  SchoolClass withStudent(Student student) {
    return copyWith(students: [...students, student]);
  }

  /// Returns a new SchoolClass with [subject] appended.
  SchoolClass withSubject(Subject subject) {
    return copyWith(subjects: [...subjects, subject]);
  }

  /// Replaces a student by id (used after grading / complaint handling).
  SchoolClass withUpdatedStudent(Student updated) {
    return copyWith(
      students: students.map((s) => s.id == updated.id ? updated : s).toList(),
    );
  }

  /// All grades across all students for a given subject.
  /// Useful for building the distribution overview.
  List<Grade> gradesForSubject(String subjectId) {
    return students
        .map((s) => s.gradeFor(subjectId))
        .whereType<Grade>()
        .toList();
  }

  /// All grades across all students and all subjects (flat list).
  List<Grade> get allGrades {
    return students
        .expand((s) => s.grades.values.whereType<Grade>())
        .toList();
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SchoolClass && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'SchoolClass($name, ${students.length} students)';
}