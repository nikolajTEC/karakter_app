// lib/screens/grading_screen.dart
//
// Shows a list of students in the selected class.
// Tapping a subject chip → bottom sheet with spinning wheel.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/grade.dart';
import '../models/school_class.dart';
import '../models/student.dart';
import '../models/subject.dart';
import '../providers/class_provider.dart';
import '../widgets/grade_wheel_widget.dart';

class GradingScreen extends StatelessWidget {
  const GradingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();
    final cls = provider.selectedClass;

    return Scaffold(
      appBar: AppBar(
        title: _ClassDropdown(provider: provider),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'Tilføj fag',
            onPressed: cls == null
                ? null
                : () => _showAddSubjectDialog(context, provider, cls.id),
          ),
        ],
      ),
      body: cls == null
          ? _EmptyState(onCreateClass: () => _showAddClassDialog(context, provider))
          : cls.students.isEmpty
              ? _NoStudentsState(onAdd: () => _showAddStudentDialog(context, provider, cls.id))
              : _StudentList(cls: cls, provider: provider),
      floatingActionButton: cls == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showAddStudentDialog(context, provider, cls.id),
              icon: const Icon(Icons.person_add),
              label: const Text('Tilføj elev'),
            ),
    );
  }

  void _showAddClassDialog(BuildContext context, ClassProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Opret klasse'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Klassenavn (f.eks. 3A)'),
            autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuller')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.addClass(ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Opret'),
          ),
        ],
      ),
    );
  }

  void _showAddStudentDialog(BuildContext context, ClassProvider provider, String classId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tilføj elev'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Elevens navn'),
            autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuller')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.addStudent(classId, ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Tilføj'),
          ),
        ],
      ),
    );
  }

  void _showAddSubjectDialog(BuildContext context, ClassProvider provider, String classId) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Tilføj fag'),
        content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Fag (f.eks. Matematik)'),
            autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuller')),
          FilledButton(
            onPressed: () {
              if (ctrl.text.trim().isNotEmpty) {
                provider.addSubject(classId, ctrl.text.trim());
                Navigator.pop(context);
              }
            },
            child: const Text('Tilføj'),
          ),
        ],
      ),
    );
  }
}

// ── Student list ──────────────────────────────────────────────────────────────

class _StudentList extends StatelessWidget {
  final SchoolClass cls;
  final ClassProvider provider;

  const _StudentList({required this.cls, required this.provider});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: cls.students.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final student = cls.students[i];
        return _StudentCard(
          student: student,
          cls: cls,
          onSubjectTap: (subject) => _openWheelSheet(context, student, subject),
        );
      },
    );
  }

  void _openWheelSheet(BuildContext context, Student student, Subject subject) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: GradeWheelWidget(
          student: student,
          subjectId: subject.id,
          subjectName: subject.name,
          onGradeLanded: (grade) {
            provider.setGrade(cls.id, student.id, subject.id, grade);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${student.name} fik ${grade.label} i ${subject.name}'),
                backgroundColor: grade.color,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ── Student card ──────────────────────────────────────────────────────────────

class _StudentCard extends StatelessWidget {
  final Student student;
  final SchoolClass cls;
  final void Function(Subject) onSubjectTap;

  const _StudentCard({required this.student, required this.cls, required this.onSubjectTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(student.name[0].toUpperCase())),
                const SizedBox(width: 12),
                Text(student.name,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            if (cls.subjects.isEmpty) ...[
              const SizedBox(height: 8),
              Text('Tilføj et fag via ⊕ øverst til højre',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.outline)),
            ] else ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: cls.subjects.map((subject) {
                  final grade = student.gradeFor(subject.id);
                  return _SubjectChip(subject: subject, grade: grade, onTap: () => onSubjectTap(subject));
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Subject chip ──────────────────────────────────────────────────────────────

class _SubjectChip extends StatelessWidget {
  final Subject subject;
  final Grade? grade;
  final VoidCallback onTap;

  const _SubjectChip({required this.subject, required this.grade, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final hasGrade = grade != null;
    return ActionChip(
      onPressed: onTap,
      avatar: hasGrade
          ? CircleAvatar(
              backgroundColor: grade!.color,
              child: Text(grade!.label,
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
            )
          : const Icon(Icons.casino_outlined, size: 16),
      label: Text(subject.name),
      backgroundColor: hasGrade ? grade!.color.withOpacity(0.1) : null,
      side: hasGrade ? BorderSide(color: grade!.color, width: 1.5) : null,
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreateClass;
  const _EmptyState({required this.onCreateClass});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.class_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Ingen klasse oprettet endnu'),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onCreateClass, icon: const Icon(Icons.add), label: const Text('Opret klasse')),
          ],
        ),
      );
}

class _NoStudentsState extends StatelessWidget {
  final VoidCallback onAdd;
  const _NoStudentsState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.people_outline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text('Ingen elever i klassen endnu'),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onAdd, icon: const Icon(Icons.person_add), label: const Text('Tilføj elev')),
          ],
        ),
      );
}

// ── Class dropdown ────────────────────────────────────────────────────────────

class _ClassDropdown extends StatelessWidget {
  final ClassProvider provider;
  const _ClassDropdown({required this.provider});

  @override
  Widget build(BuildContext context) {
    final classes = provider.classes;
    final selected = provider.selectedClass;
    if (classes.isEmpty) return const Text('Karakterer');
    return DropdownButton<String>(
      value: selected?.id,
      underline: const SizedBox(),
      icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
      dropdownColor: Theme.of(context).colorScheme.surface,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Theme.of(context).colorScheme.onSurface),
      items: classes.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
      onChanged: (id) { if (id != null) provider.selectClass(id); },
    );
  }
}