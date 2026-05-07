import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shake/shake.dart';

import '../models/grade.dart';
import '../models/school_class.dart';
import '../providers/class_provider.dart';

class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  ShakeDetector? _shakeDetector;
  bool _isRedistributing = false;
  int _selectedSubjectIndex = 0;

  @override
  void initState() {
    super.initState();

    _shakeDetector = ShakeDetector.autoStart(
      shakeThresholdGravity: 2.5,
      onPhoneShake: _triggerShake,
    );
  }

  void _triggerShake() {
    if (_isRedistributing || !mounted) return;
    final provider = context.read<ClassProvider>();
    final cls = provider.selectedClass;
    if (cls == null || cls.subjects.isEmpty) return;

    final subjectId = cls.subjects[_selectedSubjectIndex].id;

    setState(() => _isRedistributing = true);
    provider.redistributeGrades(cls.id, subjectId);

    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => _isRedistributing = false);
    });
  }

  @override
  void dispose() {
    _shakeDetector?.stopListening();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();
    final cls = provider.selectedClass;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _triggerShake,
        child: const Icon(Icons.vibration),
      ),
      appBar: AppBar(title: const Text('Overblik')),
      body: cls == null
          ? const Center(child: Text('Opret en klasse først'))
          : _OverviewBody(
              cls: cls,
              subjectIndex: _selectedSubjectIndex,
              isRedistributing: _isRedistributing,
              onSubjectSelected: (i) =>
                  setState(() => _selectedSubjectIndex = i),
            ),
    );
  }
}

class _OverviewBody extends StatelessWidget {
  final SchoolClass cls;
  final int subjectIndex;
  final bool isRedistributing;
  final void Function(int) onSubjectSelected;

  const _OverviewBody({
    required this.cls,
    required this.subjectIndex,
    required this.isRedistributing,
    required this.onSubjectSelected,
  });

  @override
  Widget build(BuildContext context) {
    final subjectId = cls.subjects[subjectIndex].id;
    final slots = cls.slotsByGrade(subjectId);

    return Column(
      children: [
        const SizedBox(height: 10),

        // SUBJECT SELECTOR
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: cls.subjects.length,
            itemBuilder: (context, i) {
              final selected = i == subjectIndex;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: ChoiceChip(
                  label: Text(cls.subjects[i].name),
                  selected: selected,
                  onSelected: (_) => onSubjectSelected(i),
                ),
              );
            },
          ),
        ),

        Expanded(
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: _GradeBarChart(
                  slots: slots,
                  totalStudents: cls.students.length,
                ),
              ),
              _AnimatedStudentCircles(cls: cls, subjectId: subjectId),
            ],
          ),
        ),
      ],
    );
  }
}

class _AnimatedStudentCircles extends StatelessWidget {
  final SchoolClass cls;
  final String subjectId;

  const _AnimatedStudentCircles({
    required this.cls,
    required this.subjectId,
  });

  @override
  Widget build(BuildContext context) {
    final slotsByGrade = cls.slotsByGrade(subjectId);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        final gradeWidth = width / allGrades.length;

        final positionedDots = <Widget>[];

        for (var gradeIndex = 0; gradeIndex < allGrades.length; gradeIndex++) {
          final grade = allGrades[gradeIndex];
          final slots = slotsByGrade[grade] ?? [];

          for (var i = 0; i < slots.length; i++) {
            final slot = slots[i];

            final xCenter = gradeWidth * gradeIndex + gradeWidth / 2;

            // stack vertically inside the bar
            final y = height - 70 - (i * 18);

            positionedDots.add(
              AnimatedPositioned(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
                left: xCenter - 7,
                top: y,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    color: grade.color,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(blurRadius: 4, color: Colors.black26),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        return Stack(children: positionedDots);
      },
    );
  }
}

class _GradeBarChart extends StatelessWidget {
  final Map<Grade, List<GradeSlot>> slots;
  final int totalStudents;

  const _GradeBarChart({
    required this.slots,
    required this.totalStudents,
  });

  @override
  Widget build(BuildContext context) {
    // convert slot lists → counts
    final counts = {
      for (final g in allGrades) g: slots[g]?.length ?? 0,
    };

    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: allGrades.map((grade) {
        final count = counts[grade]!;
        final heightFactor = maxCount == 0 ? 0.0 : count / maxCount;

        return Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(count.toString()),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                height: 180 * heightFactor,
                decoration: BoxDecoration(
                  color: grade.color.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                grade.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}