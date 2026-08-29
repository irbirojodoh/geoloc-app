import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import 'app_bottom_sheet.dart';

/// Bottom sheet listing feed radii, capped at the server maximum (15 km).
Future<double?> showFeedRadiusPicker({
  required BuildContext context,
  required double selectedKm,
}) {
  final current = AppConfig.clampFeedRadiusKm(selectedKm);
  return showAppBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final cs = Theme.of(sheetContext).colorScheme;
      final textTheme = Theme.of(sheetContext).textTheme;
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  'Show posts within',
                  style: textTheme.titleMedium?.copyWith(color: cs.onSurface),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Maximum ${AppConfig.formatFeedRadiusKm(AppConfig.maxFeedRadiusKm)}',
                  style: textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              for (final option in AppConfig.feedRadiusOptionsKm)
                ListTile(
                  title: Text(AppConfig.formatFeedRadiusKm(option)),
                  trailing: option == current
                      ? Icon(Icons.check, color: cs.primary)
                      : null,
                  onTap: () => Navigator.of(sheetContext).pop(option),
                ),
            ],
          ),
        ),
      );
    },
  );
}
