// lib/models/student.dart

import 'grade.dart';

class Student {
  final String id;
  final String name;
  final Map<String, Grade?> grades;   // subjectId → Grade?
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
  }) => Student(
    id: id ?? this.id,
    name: name ?? this.name,
    grades: grades ?? Map.of(this.grades),
    hasActiveComplaint: hasActiveComplaint ?? this.hasActiveComplaint,
  );

  Grade? gradeFor(String subjectId) => grades[subjectId];

  bool isFullyGraded(List<String> subjectIds) =>
      subjectIds.every((id) => grades[id] != null);

  Student withGrade(String subjectId, Grade grade) {
    final updated = Map<String, Grade?>.of(grades);
    updated[subjectId] = grade;
    return copyWith(grades: updated);
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    // Store grade as its label string, or null
    'grades': grades.map((k, v) => MapEntry(k, v?.jsonKey)),
    'hasActiveComplaint': hasActiveComplaint,
  };

  factory Student.fromJson(Map<String, dynamic> json) {
    final rawGrades = (json['grades'] as Map<String, dynamic>? ?? {});
    final grades = rawGrades.map((k, v) =>
        MapEntry(k, v == null ? null : gradeFromJson(v as String)));
    return Student(
      id: json['id'] as String,
      name: json['name'] as String,
      grades: grades.cast<String, Grade?>(),
      hasActiveComplaint: json['hasActiveComplaint'] as bool? ?? false,
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Student && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Student($name)';
}