// lib/models/subject.dart

class Subject {
  final String id;
  final String name;

  const Subject({required this.id, required this.name});

  Subject copyWith({String? id, String? name}) =>
      Subject(id: id ?? this.id, name: name ?? this.name);

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Subject.fromJson(Map<String, dynamic> json) =>
      Subject(id: json['id'] as String, name: json['name'] as String);

  // ─────────────────────────────────────────────────────────────────────────

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Subject && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Subject($name)';
}