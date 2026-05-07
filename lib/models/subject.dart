// lib/models/subject.dart
//
// A subject (fag) shared by all students in a class.
// Examples: Matematik, Dansk, Engelsk.

class Subject {
  final String id;
  final String name;

  const Subject({
    required this.id,
    required this.name,
  });

  Subject copyWith({String? id, String? name}) {
    return Subject(
      id: id ?? this.id,
      name: name ?? this.name,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Subject && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Subject($name)';
}