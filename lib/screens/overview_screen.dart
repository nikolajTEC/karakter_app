// lib/screens/overview_screen.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shake/shake.dart';

import '../models/grade.dart';
import '../models/school_class.dart';
import '../models/subject.dart';
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
      onPhoneShake: () {
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
      },
    );
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
        title: const Text('Overblik'),
        centerTitle: true,
      ),
      body: cls == null
          ? const _EmptyState()
          : cls.subjects.isEmpty
              ? const _NoSubjectsState()
              : _OverviewBody(
                  cls: cls,
                  selectedSubjectIndex: _selectedSubjectIndex,
                  isRedistributing: _isRedistributing,
                  onSubjectSelected: (i) =>
                      setState(() => _selectedSubjectIndex = i),
                ),
    );
  }
}

// ── Overview body ─────────────────────────────────────────────────────────────

class _OverviewBody extends StatelessWidget {
  final SchoolClass cls;
  final int selectedSubjectIndex;
  final bool isRedistributing;
  final void Function(int) onSubjectSelected;

  const _OverviewBody({
    required this.cls,
    required this.selectedSubjectIndex,
    required this.isRedistributing,
    required this.onSubjectSelected,
  });

  Subject get _subject => cls.subjects[selectedSubjectIndex];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final slots = cls.slotsByGrade(_subject.id);
    final totalStudents = cls.students.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Subject selector tabs ────────────────────────────────────────
        _SubjectTabBar(
          subjects: cls.subjects,
          selectedIndex: selectedSubjectIndex,
          onSelected: onSubjectSelected,
        ),

        // ── Shake hint ───────────────────────────────────────────────────
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          color: isRedistributing
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.vibration,
                size: 16,
                color: isRedistributing
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 6),
              Text(
                isRedistributing
                    ? 'Omfordeler karakterer…'
                    : 'Ryst telefonen for at normalisere fordelingen',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isRedistributing
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.outline,
                ),
              ),
            ],
          ),
        ),

        // ── Legend ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _LegendDot(color: theme.colorScheme.primary, label: 'Faktisk'),
              const SizedBox(width: 16),
              _LegendDot(
                  color: theme.colorScheme.primary.withOpacity(0.25),
                  label: 'Forventet (normalfordeling)'),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── Bar chart ────────────────────────────────────────────────────
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 24, 16),
            child: _GradeBarChart(
              slots: slots,
              totalStudents: totalStudents,
              subjectColor: theme.colorScheme.primary,
            ),
          ),
        ),

        // ── Student circles placeholder ──────────────────────────────────
        // TODO (Step N — Shake animation):
        // Replace the Expanded above with a Stack that overlays
        // AnimatedGradeSlotCircles on top of each bar.
        // Each circle corresponds to one GradeSlot from cls.gradeSlotsForSubject().
        // On shake, they animate from old column to new column using
        // AnimatedPositioned or a physics simulation.
        //
        // Data is ready: cls.gradeSlotsForSubject(subjectId) gives you
        // the full list with student names, current grade, and subjectId.

        // ── Summary row ──────────────────────────────────────────────────
        _SummaryRow(slots: slots, totalStudents: totalStudents),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ── Bar chart ─────────────────────────────────────────────────────────────────

class _GradeBarChart extends StatelessWidget {
  final Map<Grade, List<dynamic>> slots; // Grade → List<GradeSlot>
  final int totalStudents;
  final Color subjectColor;

  const _GradeBarChart({
    required this.slots,
    required this.totalStudents,
    required this.subjectColor,
  });

  @override
  Widget build(BuildContext context) {
    final maxActual = slots.values
        .map((s) => s.length)
        .fold(0, (a, b) => a > b ? a : b);

    final maxExpected = expectedNormalDistribution.values
        .map((p) => (totalStudents * p).ceil())
        .fold(0, (a, b) => a > b ? a : b);

    final maxY = (maxActual > maxExpected ? maxActual : maxExpected)
        .toDouble()
        .clamp(1.0, double.infinity);

    final groups = allGrades.asMap().entries.map((entry) {
      final i = entry.key;
      final grade = entry.value;
      final actual = slots[grade]!.length.toDouble();
      final expected =
          (totalStudents * (expectedNormalDistribution[grade] ?? 0.0));

      return BarChartGroupData(
        x: i,
        groupVertically: false,
        barRods: [
          // Actual bar
          BarChartRodData(
            toY: actual,
            width: 14,
            color: grade.color,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
          // Expected bar (translucent)
          BarChartRodData(
            toY: expected,
            width: 14,
            color: grade.color.withOpacity(0.25),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            borderSide: BorderSide(color: grade.color.withOpacity(0.6)),
          ),
        ],
        barsSpace: 3,
      );
    }).toList();

    return BarChart(
      BarChartData(
        maxY: maxY + 1.0,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1,
          getDrawingHorizontalLine: (v) => FlLine(
            color: Colors.grey.withOpacity(0.2),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final grade = allGrades[group.x];
              final label = rodIndex == 0 ? 'Faktisk' : 'Forventet';
              return BarTooltipItem(
                '${grade.label}\n$label: ${rod.toY.toStringAsFixed(rodIndex == 0 ? 0 : 1)}',
                const TextStyle(color: Colors.white, fontSize: 12),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final grade = allGrades[value.toInt()];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    grade.label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: grade.color,
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value != value.roundToDouble()) return const SizedBox();
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                );
              },
            ),
          ),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        barGroups: groups,
      ),
      swapAnimationDuration: const Duration(milliseconds: 500),
      swapAnimationCurve: Curves.easeInOut,
    );
  }
}

// ── Subject tab bar ───────────────────────────────────────────────────────────

class _SubjectTabBar extends StatelessWidget {
  final List<Subject> subjects;
  final int selectedIndex;
  final void Function(int) onSelected;

  const _SubjectTabBar({
    required this.subjects,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: subjects.asMap().entries.map((entry) {
          final i = entry.key;
          final subject = entry.value;
          final selected = i == selectedIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(subject.name),
              selected: selected,
              onSelected: (_) => onSelected(i),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Summary row ───────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final Map<Grade, List<dynamic>> slots;
  final int totalStudents;

  const _SummaryRow({required this.slots, required this.totalStudents});

  @override
  Widget build(BuildContext context) {
    final graded = slots.values.fold(0, (sum, s) => sum + s.length);
    final passing = slots.entries
        .where((e) => e.key.isPassing)
        .fold(0, (sum, e) => sum + e.value.length);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _StatChip(label: 'Bedømt', value: '$graded / $totalStudents'),
          _StatChip(
            label: 'Bestået',
            value: graded == 0
                ? '–'
                : '${(passing / graded * 100).round()}%',
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold)),
        Text(label,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.outline)),
      ],
    );
  }
}

// ── Legend dot ────────────────────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

// ── Empty states ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Opret en klasse på Karakterer-siden først.'),
      );
}

class _NoSubjectsState extends StatelessWidget {
  const _NoSubjectsState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Text('Tilføj mindst ét fag for at se overblikket.'),
      );
}