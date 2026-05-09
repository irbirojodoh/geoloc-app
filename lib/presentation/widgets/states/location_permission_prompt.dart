import 'package:flutter/material.dart';

/// Standardized Material 3 location permission prompt.
class LocationPermissionPrompt extends StatelessWidget {
  const LocationPermissionPrompt({
    super.key,
    required this.onRequest,
    required this.onOpenSettings,
    this.title = 'Location Access Required',
    this.message =
        'Geoloc needs your location to show posts from people near you.',
  });

  final String title;
  final String message;
  final VoidCallback onRequest;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 96,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: onRequest,
              icon: const Icon(Icons.location_on_outlined),
              label: const Text('Enable location'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: onOpenSettings,
              child: const Text('Open settings'),
            ),
          ],
        ),
      ),
    );
  }
}
