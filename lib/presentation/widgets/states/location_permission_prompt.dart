import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

/// Standardized "Location Access Required" prompt used wherever a screen
/// can't proceed without location permission.
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
    final cs = Theme.of(context).colorScheme;
    final gold = AppColors.gold(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.huge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.location_off_outlined,
              size: 64,
              color: gold.withValues(alpha: 0.5),
            ),
            const SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.ptSerif(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: AppColors.textMuted(context),
              ),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            OutlinedButton.icon(
              onPressed: onRequest,
              icon: Icon(Icons.location_on_outlined, size: 18, color: gold),
              label: Text(
                'ENABLE LOCATION',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                  color: gold,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextButton(
              onPressed: onOpenSettings,
              child: Text(
                'Open Settings',
                style: GoogleFonts.plusJakartaSans(
                  color: gold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
