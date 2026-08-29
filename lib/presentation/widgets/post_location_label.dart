import 'package:flutter/material.dart';

/// Location line used on post cards, post detail, and map pin callouts.
///
/// Street-level `location_name` values are longer than the old district
/// labels, so this always ellipsizes rather than overflowing the row.
class PostLocationLabel extends StatelessWidget {
  const PostLocationLabel({
    super.key,
    required this.label,
    this.verified = false,
    this.maxLines = 2,
    this.iconSize = 13,
    this.compact = false,
  });

  /// Single-line variant for map pin callouts.
  const PostLocationLabel.callout({
    super.key,
    required this.label,
    this.verified = false,
  }) : maxLines = 1,
       iconSize = 12,
       compact = true;

  final String label;
  final bool verified;
  final int maxLines;
  final double iconSize;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final trimmed = label.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final style = (compact ? textTheme.labelSmall : textTheme.bodySmall)
        ?.copyWith(color: cs.onSurfaceVariant);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.location_on_outlined,
          size: iconSize,
          color: cs.onSurfaceVariant,
        ),
        SizedBox(width: compact ? 3 : 4),
        Flexible(
          child: Text(
            trimmed,
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
        if (verified) ...[
          SizedBox(width: compact ? 3 : 4),
          Icon(
            Icons.check_circle,
            size: iconSize,
            color: cs.onSurfaceVariant,
            semanticLabel: 'Location verified',
          ),
        ],
      ],
    );
  }
}
