import 'package:flutter/material.dart';

/// Global bottom spacing for all modal sheets.
const double kAppBottomSheetGap = 12;

/// App-wide wrapper around [showModalBottomSheet] with consistent bottom gap.
Future<T?> showAppBottomSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = false,
  bool useRootNavigator = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool showDragHandle = false,
  Color? backgroundColor,
  ShapeBorder? shape,
  Clip? clipBehavior,
  double bottomGap = kAppBottomSheetGap,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useRootNavigator: useRootNavigator,
    isDismissible: isDismissible,
    enableDrag: enableDrag,
    showDragHandle: showDragHandle,
    backgroundColor: backgroundColor,
    shape: shape,
    clipBehavior: clipBehavior,
    builder: (sheetContext) {
      final media = MediaQuery.of(sheetContext);
      final keyboardBottom = media.viewInsets.bottom;
      final safeBottom = media.padding.bottom;
      final baseBottom = keyboardBottom > 0 ? keyboardBottom : safeBottom;
      return Padding(
        padding: EdgeInsets.only(bottom: baseBottom + bottomGap),
        child: builder(sheetContext),
      );
    },
  );
}
