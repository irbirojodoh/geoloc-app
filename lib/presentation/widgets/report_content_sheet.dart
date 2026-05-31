import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_extensions.dart';

import '../../services/moderation_service.dart';
import 'app_bottom_sheet.dart';

const _reportReasons = <({String apiValue, String label})>[
  (apiValue: 'spam', label: 'Spam'),
  (apiValue: 'harassment', label: 'Harassment'),
  (apiValue: 'inappropriate', label: 'Inappropriate content'),
  (apiValue: 'other', label: 'Other'),
];

/// Bottom sheet for POST /api/v1/reports. Returns whether submission succeeded.
Future<bool> showReportContentSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String targetType,
  required String targetId,
}) async {
  String selectedReason = _reportReasons.first.apiValue;
  final descriptionCtrl = TextEditingController();

  final success = await showAppBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(2)),
    ),
    builder: (ctx) {
      final cs = Theme.of(ctx).colorScheme;

      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: const EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'REPORT',
                  style: context.sectionLabel,
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Reason',
                    labelStyle: context.bodySmall,
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      isExpanded: true,
                      value: selectedReason,
                      style: context.bodyMedium,
                      items: [
                        for (final r in _reportReasons)
                          DropdownMenuItem<String>(
                            value: r.apiValue,
                            child: Text(
                              r.label,
                              style: context.bodyMedium,
                            ),
                          ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setSheetState(() => selectedReason = v);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: descriptionCtrl,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Details (optional)',
                    labelStyle: context.bodySmall,
                  ),
                  style: context.bodyMedium,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 44,
                  child: OutlinedButton(
                    onPressed: () async {
                      try {
                        await ref.read(moderationServiceProvider).report(
                              targetType: targetType,
                              targetId: targetId,
                              reason: selectedReason,
                              description: descriptionCtrl.text.trim().isEmpty
                                  ? null
                                  : descriptionCtrl.text.trim(),
                            );
                        if (ctx.mounted) Navigator.pop(ctx, true);
                      } on DioException {
                        if (ctx.mounted) Navigator.pop(ctx, false);
                      } catch (_) {
                        if (ctx.mounted) Navigator.pop(ctx, false);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: cs.primary,
                      side: BorderSide(color: cs.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    child: Text(
                      'SUBMIT REPORT',
                      style: context.username,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(
                    'Cancel',
                    style: context.bodyMedium.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );

  descriptionCtrl.dispose();
  return success == true;
}
