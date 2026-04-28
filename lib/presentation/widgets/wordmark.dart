import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// "Geoloc" wordmark in italic PT Serif. Single source of truth so the
/// font/size/style stay synchronized across the top bar, splash, and modals.
class Wordmark extends StatelessWidget {
  const Wordmark({
    super.key,
    this.fontSize = 18,
    this.color,
  });

  /// Default 18pt; modal headers use 17pt.
  final double fontSize;

  /// Falls back to `colorScheme.onSurface`.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Geoloc',
      header: true,
      child: Text(
        'Geoloc',
        style: GoogleFonts.ptSerif(
          fontSize: fontSize,
          fontStyle: FontStyle.italic,
          color: color ?? Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
