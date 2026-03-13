import 'package:flutter/material.dart';

class AppField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  const AppField({required this.controller, required this.label});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label),
    );
  }
}
