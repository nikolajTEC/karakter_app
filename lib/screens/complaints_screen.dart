// lib/screens/complaints_screen.dart
//
// Placeholder — Step 4 will add API call for bad excuses
// and re-spin the wheel for the complaining student.

import 'package:flutter/material.dart';

class ComplaintsScreen extends StatelessWidget {
  const ComplaintsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Klager'), centerTitle: true),
      body: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gavel, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Klagebehandling med\ndårlige undskyldninger fra AI\nkommer i næste trin.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}