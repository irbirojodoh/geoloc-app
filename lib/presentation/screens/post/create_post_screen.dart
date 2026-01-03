import 'package:flutter/material.dart';

/// Create post screen placeholder
class CreatePostScreen extends StatelessWidget {
  const CreatePostScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Post'),
        actions: [
          TextButton(
            onPressed: () {
              // TODO: Implement post creation
            },
            child: const Text('Post'),
          ),
        ],
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Post content field
            TextField(
              maxLines: null,
              decoration: InputDecoration(
                hintText: "What's happening in your area?",
                border: InputBorder.none,
              ),
            ),
            Spacer(),
            // TODO: Add media picker, location display
          ],
        ),
      ),
    );
  }
}
