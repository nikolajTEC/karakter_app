// lib/screens/complaints_screen.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/student.dart';
import '../providers/class_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Palette & constants
// ─────────────────────────────────────────────────────────────────────────────

const _navy   = Color(0xFF0D1B2A);
const _ink    = Color(0xFF1A2B3C);
const _gold   = Color(0xFFD4A017);
const _amber  = Color(0xFFF0C040);
const _cream  = Color(0xFFFFF8E7);
const _muted  = Color(0xFF8A9BB0);
const _red    = Color(0xFFE53935);
const _white  = Color(0xFFFFFFFF);

const _excuseUrl =
    'https://excuses.onrender.com/excuse?count=1&category=backend';

// ─────────────────────────────────────────────────────────────────────────────

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen>
    with SingleTickerProviderStateMixin {
  Student? _selected;
  String?  _excuse;
  bool     _loading = false;
  bool     _hasError = false;

  late final AnimationController _stampCtrl;
  late final Animation<double>   _stampScale;
  late final Animation<double>   _stampOpacity;

  @override
  void initState() {
    super.initState();
    _stampCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _stampScale = CurvedAnimation(
      parent: _stampCtrl,
      curve: Curves.elasticOut,
    );
    _stampOpacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _stampCtrl, curve: const Interval(0, 0.3)),
    );
  }

  @override
  void dispose() {
    _stampCtrl.dispose();
    super.dispose();
  }

  // ── API call ───────────────────────────────────────────────────────────────

  Future<void> _handleComplaint() async {
    if (_selected == null) return;
    setState(() {
      _loading  = true;
      _excuse   = null;
      _hasError = false;
    });
    _stampCtrl.reset();

    try {
      final response = await http
          .get(Uri.parse(_excuseUrl))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final excuse = body['text'];

        setState(() {
          _excuse  = excuse;
          _loading = false;
        });
        _stampCtrl.forward();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (_) {
      setState(() {
        _hasError = true;
        _loading  = false;
      });
    }
  }

  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ClassProvider>();
    final cls      = provider.selectedClass;

    return Scaffold(
      backgroundColor: _navy,
      body: SafeArea(
        child: cls == null
            ? _buildNoClass()
            : _buildContent(context, provider, cls.students),
      ),
    );
  }

  Widget _buildNoClass() => const Center(
    child: Text(
      'Ingen klasse valgt',
      style: TextStyle(color: _muted, fontSize: 16),
    ),
  );

  // ── Main layout ────────────────────────────────────────────────────────────

  Widget _buildContent(
    BuildContext context,
    ClassProvider provider,
    List<Student> students,
  ) {
    // Filter logic
    final complainingStudents = students.where((s) => s.hasActiveComplaint).toList();
    final peacefulStudents = students.where((s) => !s.hasActiveComplaint).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeader(),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                
                // Section 1: Active Complaints
                _buildSectionLabel('Aktive Klager'),
                const SizedBox(height: 10),
                _buildStudentGrid(provider, complainingStudents),
                
                const SizedBox(height: 32),
                const Divider(color: Color(0xFF263545), thickness: 1),
                const SizedBox(height: 24),

                // Section 2: Add New Complaint
                _buildSectionLabel('Tilføj Ny Klage'),
                const SizedBox(height: 12),
                _buildAddComplaintSection(provider, peacefulStudents),

                const SizedBox(height: 32),

                // Section 3: Actions & Results
                if (_selected != null) ...[
                  _buildHandleButton(provider),
                  const SizedBox(height: 28),
                ],
                
                if (_loading)   _buildLoadingCard()
                else if (_hasError) _buildErrorCard()
                else if (_excuse != null) _buildExcuseCard(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() => Container(
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
    decoration: const BoxDecoration(
      color: _ink,
      border: Border(bottom: BorderSide(color: Color(0xFF263545), width: 1)),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _gold.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.gavel, color: _gold, size: 22),
        ),
        const SizedBox(width: 14),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Klagebehandling',
              style: TextStyle(
                color: _white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            Text(
              'Håndtér eksisterende eller opret nye',
              style: TextStyle(color: _muted, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _buildSectionLabel(String label) => Text(
    label.toUpperCase(),
    style: const TextStyle(
      color: _muted,
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.4,
    ),
  );

  // ── Active Student grid ────────────────────────────────────────────────────

  Widget _buildStudentGrid(ClassProvider provider, List<Student> students) {
    if (students.isEmpty) {
      return const _EmptyState(message: 'Ingen elever har klaget endnu.');
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: students.map((s) => _StudentChip(
        student:    s,
        isSelected: _selected?.id == s.id,
        onTap: () => setState(() {
          _selected = (_selected?.id == s.id) ? null : s;
          _excuse   = null;
          _hasError = false;
          _stampCtrl.reset();
        }),
        onComplaintToggle: () {
          provider.toggleComplaint(provider.selectedClass!.id, s.id);
          if (_selected?.id == s.id) {
            setState(() {
              _selected = null;
              _excuse = null;
            });
          }
        },
      )).toList(),
    );
  }

  // ── Add Complaint Section ──────────────────────────────────────────────────

  Widget _buildAddComplaintSection(ClassProvider provider, List<Student> students) {
    if (students.isEmpty) {
      return const Text(
        'Alle elever har en aktiv klage.',
        style: TextStyle(color: _muted, fontSize: 13, fontStyle: FontStyle.italic),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: students.map((s) => GestureDetector(
        onTap: () => provider.toggleComplaint(provider.selectedClass!.id, s.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _muted.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add, color: _muted, size: 14),
              const SizedBox(width: 6),
              Text(s.name, style: const TextStyle(color: _muted, fontSize: 13)),
            ],
          ),
        ),
      )).toList(),
    );
  }

  // ── Handle button ──────────────────────────────────────────────────────────

  Widget _buildHandleButton(ClassProvider provider) {
    final ready = _selected != null && !_loading;

    return GestureDetector(
      onTap: ready ? _handleComplaint : null,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _gold,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.bolt_rounded, color: _navy, size: 20),
            const SizedBox(width: 10),
            Text(
              'Håndtér klage for ${_selected!.name}',
              style: const TextStyle(
                color: _navy,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── UI Components (Loading, Error, Excuse Card) ────────────────────────────

  Widget _buildLoadingCard() => const _Card(
    child: Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          SizedBox(
            width: 28, height: 28,
            child: CircularProgressIndicator(strokeWidth: 2, color: _gold),
          ),
          SizedBox(height: 16),
          Text('Behandler klagesag...', style: TextStyle(color: _muted, fontSize: 14)),
        ],
      ),
    ),
  );

  Widget _buildErrorCard() => _Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _red, size: 32),
          const SizedBox(height: 12),
          const Text('Netværksfejl', style: TextStyle(color: _white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _retryButton(),
        ],
      ),
    ),
  );

  Widget _buildExcuseCard() {
    return ScaleTransition(
      scale: _stampScale,
      child: FadeTransition(
        opacity: _stampOpacity,
        child: _Card(
          borderColor: _gold.withOpacity(0.4),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'OFFICIEL BEGRUNDELSE',
                  style: TextStyle(color: _amber, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _cream.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '"$_excuse"',
                    style: const TextStyle(color: _cream, fontSize: 15, fontStyle: FontStyle.italic, height: 1.5),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _retryButton()),
                    const SizedBox(width: 10),
                    Expanded(child: _resolveButton()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _retryButton() => _OutlineButton(
    icon: Icons.refresh_rounded,
    label: 'Prøv igen',
    onTap: _handleComplaint,
  );

  Widget _resolveButton() => _FilledButton(
    icon: Icons.check_circle_outline_rounded,
    label: 'Løst',
    onTap: () {
      final provider = context.read<ClassProvider>();
      if (provider.selectedClass != null && _selected != null) {
        provider.resolveComplaint(provider.selectedClass!.id, _selected!.id);
      }
      setState(() {
        _selected = null;
        _excuse   = null;
      });
      _stampCtrl.reset();
    },
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _StudentChip extends StatelessWidget {
  final Student student;
  final bool    isSelected;
  final VoidCallback onTap;
  final VoidCallback onComplaintToggle;

  const _StudentChip({
    required this.student,
    required this.isSelected,
    required this.onTap,
    required this.onComplaintToggle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? _gold.withOpacity(0.15) : _ink,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? _gold : const Color(0xFF263545), width: 1.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 8, height: 8, decoration: const BoxDecoration(color: _red, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(
              student.name,
              style: TextStyle(color: isSelected ? _amber : _white, fontSize: 14, fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onComplaintToggle,
              child: const Icon(Icons.close, color: _muted, size: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  final Color? borderColor;
  const _Card({required this.child, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor ?? const Color(0xFF263545)),
      ),
      child: child,
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _OutlineButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _muted.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: _muted, size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: _muted, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _FilledButton extends StatelessWidget {
  final IconData icon;
  final String   label;
  final VoidCallback onTap;
  const _FilledButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: const Color(0xFF1A3A2A),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2E6B4A)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check, color: Color(0xFF66BB6A), size: 16),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Color(0xFF66BB6A), fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Text(message, style: const TextStyle(color: _muted, fontSize: 14)),
      ),
    );
  }
}