// lib/widgets/grade_wheel_widget.dart
//
// A spinning grade wheel built on flutter_fortune_wheel.
// Pass in the student + subjectId, and a callback for when a grade lands.
//
// Usage:
//   GradeWheelWidget(
//     student: student,
//     subjectId: subject.id,
//     onGradeLanded: (grade) => provider.setGrade(...),
//   )

import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_fortune_wheel/flutter_fortune_wheel.dart';

import '../models/grade.dart';
import '../models/student.dart';

class GradeWheelWidget extends StatefulWidget {
  final Student student;
  final String subjectId;
  final String subjectName;

  /// Called once the wheel stops spinning with the landed grade.
  final void Function(Grade grade) onGradeLanded;

  const GradeWheelWidget({
    super.key,
    required this.student,
    required this.subjectId,
    required this.subjectName,
    required this.onGradeLanded,
  });

  @override
  State<GradeWheelWidget> createState() => _GradeWheelWidgetState();
}

class _GradeWheelWidgetState extends State<GradeWheelWidget> {
  // The wheel listens to this stream for which index to land on.
  late final StreamController<int> _wheelController;

  bool _isSpinning = false;
  int _selectedIndex = 0; // index into allGrades

  // The current grade already assigned to this student for this subject
  Grade? get _existingGrade => widget.student.gradeFor(widget.subjectId);

  @override
  void initState() {
    super.initState();
    // Regular (non-broadcast) controller buffers the event until the wheel
    // subscribes — broadcast() drops events if no listener is ready yet,
    // which caused the "always lands on -3" bug.
    _wheelController = StreamController<int>();

    // Start at a random position so the wheel doesn't always open on -3.
    // If already graded, show that grade's segment instead.
    if (_existingGrade != null) {
      _selectedIndex = allGrades.indexOf(_existingGrade!);
    } else {
      _selectedIndex = Random().nextInt(allGrades.length);
    }
  }

  @override
  void dispose() {
    _wheelController.close();
    super.dispose();
  }

  void _spin() {
    if (_isSpinning) return;

    // Pick a random grade index
    final random = Random();
    final landingIndex = random.nextInt(allGrades.length);

    setState(() {
      _isSpinning = true;
      _selectedIndex = landingIndex;
    });

    // Emit the index — the wheel animates to it automatically
    _wheelController.add(landingIndex);
  }

  void _onSpinFinished() {
    final landedGrade = allGrades[_selectedIndex];
    setState(() => _isSpinning = false);
    widget.onGradeLanded(landedGrade);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Header ────────────────────────────────────────────────────────
        Text(
          widget.student.name,
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          widget.subjectName,
          style: theme.textTheme.titleMedium
              ?.copyWith(color: theme.colorScheme.primary),
        ),

        if (_existingGrade != null) ...[
          const SizedBox(height: 4),
          Chip(
            label: Text('Nuværende karakter: ${_existingGrade!.label}'),
            backgroundColor: _existingGrade!.color.withOpacity(0.2),
          ),
        ],

        const SizedBox(height: 16),

        // ── The wheel ─────────────────────────────────────────────────────
        SizedBox(
          height: 300,
          child: FortuneWheel(
            selected: _wheelController.stream,
            // Prevents the wheel from animating to index 0 the moment it opens.
            animateFirst: false,
            onFling: _spin, // fling gesture also triggers spin
            onAnimationEnd: _onSpinFinished,
            duration: const Duration(seconds: 3),
            rotationCount: 8, // how many full rotations before stopping
            items: allGrades.map((grade) {
              return FortuneItem(
                style: FortuneItemStyle(
                  color: grade.color,
                  borderColor: Colors.white,
                  borderWidth: 2,
                  textStyle: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                  ),
                ),
                child: Text(grade.label),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 24),

        // ── Spin button ───────────────────────────────────────────────────
        FilledButton.icon(
          onPressed: _isSpinning ? null : _spin,
          icon: _isSpinning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh),
          label: Text(_isSpinning ? 'Snurrer...' : 'Spin hjulet!'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          'Du kan også swipe hjulet for at snurre',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }
}