// lib/screens/overview_screen.dart
//
// Placeholder — Step 3 will add the grade distribution chart
// and the shake-to-adjust feature.

import 'package:flutter/material.dart';

class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Overblik'), centerTitle: true),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Fordeling af karakterer\nog normalfordeling\nkommer i næste trin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}