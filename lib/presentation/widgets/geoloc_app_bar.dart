import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_spacing.dart';

/// App-wide top-bar replacing the per-screen inline `Container + Row` pattern
/// that was duplicated across feed/post-detail/notifications/edit-profile/etc.
///
/// Layout (left → center → right):
///
/// ```
/// ┌──────┬───────────────────────┬──────┐
/// │ lead │        title          │trail │
/// └──────┴───────────────────────┴──────┘
/// ```
///
/// - Inserts top safe-area padding (so callers don't manually add
///   `MediaQuery.padding.top`).
/// - Draws a 0.5-pt outline divider at the bottom for separation.
/// - Centers a string [title] or arbitrary [titleWidget] (e.g. [Wordmark]).
/// - [leading] / [trailing] should typically be [IconSquareButton]s.
class GeolocAppBar extends StatelessWidget implements PreferredSizeWidget {
  const GeolocAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.leading,
    this.trailing,
    this.showBottomDivider = true,
  }) : assert(
         title == null || titleWidget == null,
         'Provide either `title` or `titleWidget`, not both.',
       );

  /// Plain text title (rendered via [Wordmark] styling). Mutually exclusive
  /// with [titleWidget].
  final String? title;

  /// Custom title widget — use for the "Geoloc" wordmark via [Wordmark].
  final Widget? titleWidget;

  final Widget? leading;
  final Widget? trailing;
  final bool showBottomDivider;

  /// Vertical chrome height (excluding status-bar inset).
  static const double kBarHeight = 54;

  @override
  Size get preferredSize => const Size.fromHeight(kBarHeight);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final topPadding = MediaQuery.paddingOf(context).top;

    return Container(
      color: cs.surface,
      padding: EdgeInsets.only(top: topPadding),
      child: Container(
        height: kBarHeight,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        decoration: showBottomDivider
            ? BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cs.outline, width: 0.5),
                ),
              )
            : null,
        child: Row(
          children: [
            SizedBox(
              width: AppTapTarget.iosMinimum,
              child: leading,
            ),
            Expanded(
              child: Center(
                child: titleWidget ??
                    (title != null
                        ? Text(
                            title!,
                            style: GoogleFonts.ptSerif(
                              fontSize: 17,
                              fontStyle: FontStyle.italic,
                              color: cs.onSurface,
                            ),
                          )
                        : const SizedBox.shrink()),
              ),
            ),
            SizedBox(
              width: AppTapTarget.iosMinimum,
              child: Align(
                alignment: Alignment.centerRight,
                child: trailing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
