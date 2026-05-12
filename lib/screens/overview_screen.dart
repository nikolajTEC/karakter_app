import 'package:flutter/material.dart';
import 'package:karakter_app/models/subject.dart';
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
      shakeThresholdGravity: 2.2,
      onPhoneShake: _triggerShake,
    );
  }

  void _triggerShake() async {
    if (_isRedistributing || !mounted) return;
    
    final provider = context.read<ClassProvider>();
    final cls = provider.selectedClass;
    if (cls == null || cls.subjects.isEmpty) return;

    final subjectId = cls.subjects[_selectedSubjectIndex].id;

    setState(() => _isRedistributing = true);
    
    // Reduced to 2 bursts with a longer delay to let animations settle
    for (int i = 0; i < 2; i++) {
      if (!mounted) break;
      provider.redistributeGrades(cls.id, subjectId);
      await Future.delayed(const Duration(milliseconds: 300));
    }

    if (mounted) {
      // Keep the "active" state briefly after the last move
      await Future.delayed(const Duration(milliseconds: 200));
      setState(() => _isRedistributing = false);
    }
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
      appBar: AppBar(
        title: const Text('Karakter Overblik'),
        centerTitle: true,
        // MOVED SHAKE BUTTON TO TOP RIGHT
        actions: [
          IconButton(
            onPressed: _triggerShake,
            icon: Icon(
              _isRedistributing ? Icons.refresh : Icons.auto_awesome,
              color: _isRedistributing ? Colors.orange : null,
            ),
          ),
        ],
      ),
      body: cls == null
          ? const Center(child: Text('Ingen klasse valgt'))
          : Column(
              children: [
                _SubjectSelector(
                  subjects: cls.subjects,
                  selectedIndex: _selectedSubjectIndex,
                  onSelected: (i) => setState(() => _selectedSubjectIndex = i),
                ),
                Expanded(
                  child: OrientationBuilder(
                    builder: (context, orientation) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                        child: _VisualDistribution(
                          cls: cls,
                          subjectId: cls.subjects[_selectedSubjectIndex].id,
                          isLandscape: orientation == Orientation.landscape,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class _VisualDistribution extends StatelessWidget {
  final SchoolClass cls;
  final String subjectId;
  final bool isLandscape;

  const _VisualDistribution({
    required this.cls,
    required this.subjectId,
    required this.isLandscape,
  });

  @override
  Widget build(BuildContext context) {
    final slotsByGrade = cls.slotsByGrade(subjectId);
    final grades = Grade.values;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final totalHeight = constraints.maxHeight;
        final columnWidth = totalWidth / grades.length;
        
        final ballSize = isLandscape ? 16.0 : 22.0;
        const bottomPadding = 30.0; 

        return Stack(
          clipBehavior: Clip.none, // Prevents balls from disappearing if they bounce
          children: [
            // BACKGROUND LANES
            Row(
              children: grades.map((g) => Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      g.label,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ],
                ),
              )).toList(),
            ),

            // ANIMATED BALLS
            for (int gIdx = 0; gIdx < grades.length; gIdx++)
              ..._buildGradeBalls(
                grade: grades[gIdx],
                slots: slotsByGrade[grades[gIdx]] ?? [],
                gIdx: gIdx,
                columnWidth: columnWidth,
                totalHeight: totalHeight - bottomPadding,
                ballSize: ballSize,
              ),
          ],
        );
      },
    );
  }

  List<Widget> _buildGradeBalls({
    required Grade grade,
    required List<GradeSlot> slots,
    required int gIdx,
    required double columnWidth,
    required double totalHeight,
    required double ballSize,
  }) {
    return List.generate(slots.length, (i) {
      final xPos = (gIdx * columnWidth) + (columnWidth / 2) - (ballSize / 2);
      final yPos = totalHeight - (i * (ballSize + 2)) - ballSize - 10;

      return AnimatedPositioned(
        // IMPORTANT: ValueKey must be unique to the student, not the index
        key: ValueKey('ball_${slots[i].student.id}'), 
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOutCubic, // Smoother path, less erratic bouncing
        left: xPos,
        top: yPos,
        child: Container(
          width: ballSize,
          height: ballSize,
          decoration: BoxDecoration(
            color: grade.color,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(0, 1)),
            ],
          ),
        ),
      );
    });
  }
}

class _SubjectSelector extends StatelessWidget {
  final List<Subject> subjects;
  final int selectedIndex;
  final Function(int) onSelected;

  const _SubjectSelector({
    required this.subjects,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: subjects.length,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemBuilder: (context, i) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(subjects[i].name),
              selected: i == selectedIndex,
              onSelected: (_) => onSelected(i),
            ),
          );
        },
      ),
    );
  }
}