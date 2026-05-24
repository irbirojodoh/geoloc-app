import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_spacing.dart';
import 'top_bar_backdrop.dart';

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
/// - Left-aligns a string [title] or arbitrary [titleWidget].
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
    const bottomRadius = Radius.circular(20);

    return SizedBox(
      height: topPadding + kBarHeight,
      child: Stack(
        children: [
          Positioned.fill(
            child: TopBarBackdrop(
              blurTintColor: cs.surface,
              blendColor: cs.surface,
              borderRadius: const BorderRadius.vertical(bottom: bottomRadius),
            ),
          ),
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: kBarHeight,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: showBottomDivider
                    ? Border(
                        bottom: BorderSide(color: cs.outline, width: 0.5),
                      )
                    : null,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: AppTapTarget.iosMinimum,
                    child: leading,
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
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
          ),
        ],
      ),
    );
  }
}
