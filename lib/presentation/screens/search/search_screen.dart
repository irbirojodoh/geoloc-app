import 'package:flutter/material.dart';

/// Search screen placeholder
class SearchScreen extends StatelessWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const TextField(
          decoration: InputDecoration(
            hintText: 'Search users or posts...',
            border: InputBorder.none,
          ),
        ),
      ),
      body: const Center(child: Text('Search Screen')),
    );
  }
}
