// lib/models/student.dart
//
// A student belonging to a SchoolClass.
// Grades are stored as a map of subjectId -> Grade.
// A null value means the subject has not been graded yet.

import 'grade.dart';

class Student {
  final String id;
  final String name;

  /// Maps subjectId to the grade given for that subject.
  /// null = not yet graded.
  final Map<String, Grade?> grades;

  /// If true, this student has an active complaint being processed.
  final bool hasActiveComplaint;

  const Student({
    required this.id,
    required this.name,
    this.grades = const {},
    this.hasActiveComplaint = false,
  });

  Student copyWith({
    String? id,
    String? name,
    Map<String, Grade?>? grades,
    bool? hasActiveComplaint,
  }) {
    return Student(
      id: id ?? this.id,
      name: name ?? this.name,
      // Always copy the map to avoid shared mutation
      grades: grades ?? Map.of(this.grades),
      hasActiveComplaint: hasActiveComplaint ?? this.hasActiveComplaint,
    );
  }

  /// Returns the grade for a given subject, or null if not yet graded.
  Grade? gradeFor(String subjectId) => grades[subjectId];

  /// Returns true if every subject in [subjectIds] has been graded.
  bool isFullyGraded(List<String> subjectIds) {
    return subjectIds.every((id) => grades[id] != null);
  }

  /// Returns a new Student with the grade set for [subjectId].
  Student withGrade(String subjectId, Grade grade) {
    final updated = Map<String, Grade?>.of(grades);
    updated[subjectId] = grade;
    return copyWith(grades: updated);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Student && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Student($name)';
}