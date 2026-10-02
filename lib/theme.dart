// How the app looks: a lead sheet.
//
// Ink on warm paper, like a Real Book chart, with one accent (the red of a
// pencil mark) kept for what the player marks themselves: the bar that's
// playing, a loop, the note that gives a sound its colour. Everything else
// is ink, paper and the greys between, so the accent means something when
// it appears.
//
// The colours are chosen, not generated from a seed: Material's generated
// schemes tint every surface with the seed's hue, which is what makes an
// app look like every other one built from the same template.
//
// Shapes follow one rule: controls have 10–12 pt corners, cards 14 pt,
// sheets 20 pt. No pills beside squares.
//
// Material's text styles add letter-spacing designed for Roboto. On iPhone
// the system font (San Francisco) already spaces itself for each size, so
// the extra spacing only makes words look loose and fuzzy. It's taken out
// here, small text is a point bigger, and labels and headings are bolder.

import 'package:flutter/material.dart';

/// The accent: a red pencil mark. Also [ColorScheme.tertiary].
const pencilLight = Color(0xFFC23B22);
const pencilDark = Color(0xFFFF8A6E);

/// The hand-lettered face of a Real Book chart, for chord symbols, tune
/// titles and rehearsal letters. Everything else (controls, lists,
/// explanations) stays in the system font, so the lettering stands out as
/// the music.
const handFont = 'PetalumaScript';

/// Fonts for the few signs the hand lettering lacks (Δ). On a phone the
/// system supplies them without being asked; tests, which have no system
/// fonts, name one here.
@visibleForTesting
List<String>? handFontFallback;

/// [base] in the chart's hand lettering. It comes in one weight: asking it
/// to be bold would only smear it.
TextStyle handLettered([TextStyle? base]) =>
    (base ?? const TextStyle()).copyWith(
      fontFamily: handFont,
      fontFamilyFallback: handFontFallback,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
    );

/// [symbol] as the hand lettering writes it: its diminished sign is the
/// raised ring a copyist uses, which the font has, rather than a degree
/// sign, which it doesn't.
String handSymbol(String symbol) => symbol.replaceAll('°', '˚');

/// A right answer, in tune: a quiet green that sits with the paper.
Color successColour(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? const Color(0xFF7FC79A)
    : const Color(0xFF2E7D4F);

const _light = ColorScheme(
  brightness: Brightness.light,
  // Ink: buttons, selection, anything the player acts on.
  primary: Color(0xFF1C1B19),
  onPrimary: Color(0xFFFAF8F4),
  primaryContainer: Color(0xFFE6E1D7),
  onPrimaryContainer: Color(0xFF1C1B19),
  // Graphite: tonal controls and chips.
  secondary: Color(0xFF5E5A53),
  onSecondary: Color(0xFFFAF8F4),
  secondaryContainer: Color(0xFFE6E1D7),
  onSecondaryContainer: Color(0xFF1C1B19),
  // The pencil.
  tertiary: pencilLight,
  onTertiary: Color(0xFFFFFFFF),
  tertiaryContainer: Color(0xFFF8DDD5),
  onTertiaryContainer: Color(0xFF5C170B),
  error: Color(0xFFB3261E),
  onError: Color(0xFFFFFFFF),
  errorContainer: Color(0xFFF9DEDC),
  onErrorContainer: Color(0xFF410E0B),
  // Paper.
  surface: Color(0xFFF7F4EE),
  onSurface: Color(0xFF1C1B19),
  onSurfaceVariant: Color(0xFF6B665D),
  surfaceDim: Color(0xFFE3DED4),
  surfaceBright: Color(0xFFFFFFFF),
  surfaceContainerLowest: Color(0xFFFFFFFF),
  surfaceContainerLow: Color(0xFFFCFAF6),
  surfaceContainer: Color(0xFFEFEBE3),
  surfaceContainerHigh: Color(0xFFE9E4DA),
  surfaceContainerHighest: Color(0xFFE2DDD2),
  outline: Color(0xFFB9B2A5),
  outlineVariant: Color(0xFFE2DCD1),
  inverseSurface: Color(0xFF2B2926),
  onInverseSurface: Color(0xFFF3EFE8),
  inversePrimary: Color(0xFFEDE8DF),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  surfaceTint: Colors.transparent,
);

const _dark = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFFEDE8DF),
  onPrimary: Color(0xFF151413),
  primaryContainer: Color(0xFF34312D),
  onPrimaryContainer: Color(0xFFEDE8DF),
  secondary: Color(0xFFB3ADA2),
  onSecondary: Color(0xFF151413),
  secondaryContainer: Color(0xFF34312D),
  onSecondaryContainer: Color(0xFFEDE8DF),
  tertiary: pencilDark,
  onTertiary: Color(0xFF3A0B03),
  tertiaryContainer: Color(0xFF5A2317),
  onTertiaryContainer: Color(0xFFFFDAD1),
  error: Color(0xFFF2B8B5),
  onError: Color(0xFF601410),
  errorContainer: Color(0xFF8C1D18),
  onErrorContainer: Color(0xFFF9DEDC),
  surface: Color(0xFF151413),
  onSurface: Color(0xFFEDE8DF),
  onSurfaceVariant: Color(0xFFA49E93),
  surfaceDim: Color(0xFF151413),
  surfaceBright: Color(0xFF3A3733),
  surfaceContainerLowest: Color(0xFF100F0E),
  surfaceContainerLow: Color(0xFF1C1B19),
  surfaceContainer: Color(0xFF211F1D),
  surfaceContainerHigh: Color(0xFF2A2825),
  surfaceContainerHighest: Color(0xFF34312D),
  outline: Color(0xFF6B665D),
  outlineVariant: Color(0xFF34312D),
  inverseSurface: Color(0xFFEDE8DF),
  onInverseSurface: Color(0xFF1C1B19),
  inversePrimary: Color(0xFF1C1B19),
  shadow: Color(0xFF000000),
  scrim: Color(0xFF000000),
  surfaceTint: Colors.transparent,
);

/// The card colour: white paper on the page in light mode, a step up from
/// the background in dark.
Color cardColour(ColorScheme scheme) => scheme.brightness == Brightness.dark
    ? scheme.surfaceContainerLow
    : scheme.surfaceContainerLowest;

/// The whole scheme, on [paper] instead of the app's own.
///
/// Not a seeded Material scheme: those tint every surface with the seed's
/// hue and would throw away the relationships the two schemes above were
/// written for. This keeps those relationships and moves them onto the new
/// paper, so a chart on green paper is the same chart.
///
/// Only the paper family moves. Ink, the pencil accent and the error reds
/// stay as they were, because they are not paper and should not take its
/// hue; whichever of the two base schemes suits the paper's own lightness
/// is the one they come from, so dark paper gets light ink without
/// anything being worked out twice.
ColorScheme schemeForPaper(Color paper) {
  final dark = paper.computeLuminance() < 0.4;
  final base = dark ? _dark : _light;
  final from = HSLColor.fromColor(base.surface);
  final to = HSLColor.fromColor(paper);

  /// A paper colour, moved onto the new paper: its hue and depth, and the
  /// distance it always sat from the paper kept.
  Color papery(Color colour) {
    final was = HSLColor.fromColor(colour);
    // How far this tone sits from the paper, which is the thing to keep:
    // a card is a little lighter than the page, a rule a little darker.
    final apart = was.lightness - from.lightness;
    var lightness = to.lightness + apart;
    // On white paper a lighter card has nowhere to go and would come out
    // white as well, which is a card you cannot see. Keep the distance
    // and turn it round instead.
    if (lightness > 1 || lightness < 0) lightness = to.lightness - apart;
    return HSLColor.fromAHSL(
      was.alpha,
      to.hue,
      // Keep a little of the tone's own depth, so a flat grey paper does
      // not flatten every container to exactly the same colour.
      (to.saturation * 0.85 + was.saturation * 0.15).clamp(0.0, 1.0),
      lightness.clamp(0.0, 1.0),
    ).toColor();
  }

  final scheme = base.copyWith(
    surface: paper,
    surfaceDim: papery(base.surfaceDim),
    surfaceBright: papery(base.surfaceBright),
    surfaceContainerLowest: papery(base.surfaceContainerLowest),
    surfaceContainerLow: papery(base.surfaceContainerLow),
    surfaceContainer: papery(base.surfaceContainer),
    surfaceContainerHigh: papery(base.surfaceContainerHigh),
    surfaceContainerHighest: papery(base.surfaceContainerHighest),
    outline: papery(base.outline),
    outlineVariant: papery(base.outlineVariant),
  );
  // And the ink has to be readable on it whatever happens, because a
  // paper nobody can read off is not a choice worth offering.
  return scheme.copyWith(
    onSurface: _inkOn(scheme.onSurface, paper),
    onSurfaceVariant: _inkOn(scheme.onSurfaceVariant, paper, least: 2.5),
  );
}

/// [ink] if it reads on [paper], or black or white if it does not.
Color _inkOn(Color ink, Color paper, {double least = 7}) {
  double contrast(Color a, Color b) {
    final x = a.computeLuminance();
    final y = b.computeLuminance();
    return x > y ? (x + 0.05) / (y + 0.05) : (y + 0.05) / (x + 0.05);
  }

  if (contrast(ink, paper) >= least) return ink;
  final black = contrast(const Color(0xFF000000), paper);
  final white = contrast(const Color(0xFFFFFFFF), paper);
  return black > white ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
}

/// [fontFamily] is for tests, which load a real font by name.
ThemeData appTheme(Brightness brightness, {String? fontFamily, Color? paper}) {
  final scheme = paper != null
      ? schemeForPaper(paper)
      : (brightness == Brightness.dark ? _dark : _light);
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: fontFamily,
    scaffoldBackgroundColor: scheme.surface,
    splashFactory: InkSparkle.splashFactory,
  );
  final text = _tidy(base.textTheme);

  const control = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
  final hairline = BorderSide(color: scheme.outlineVariant);
  TextStyle label(double size, FontWeight weight) => TextStyle(
    fontFamily: fontFamily,
    fontSize: size,
    letterSpacing: 0,
    fontWeight: weight,
  );

  return base.copyWith(
    textTheme: text,
    primaryTextTheme: _tidy(base.primaryTextTheme),
    // Sizes are spelled out below: these styles aren't given the text
    // theme's sizes the way the text theme itself is.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      // Screen titles are lettered by hand, like the title across the top
      // of a chart.
      titleTextStyle: handLettered(label(26, FontWeight.w400))
          .copyWith(color: scheme.onSurface, height: 1.1),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 68,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      indicatorColor: Colors.transparent,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return label(12, selected ? FontWeight.w700 : FontWeight.w500).copyWith(
          color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected)
              ? scheme.onSurface
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: cardColour(scheme),
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        side: hairline,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      side: WidgetStateBorderSide.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? BorderSide(color: scheme.primary)
            : hairline,
      ),
      color: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? scheme.primary
            : cardColour(scheme),
      ),
      // Ink on paper; paper on ink once chosen.
      labelStyle: label(14, FontWeight.w600).copyWith(
        color: WidgetStateColor.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
      ),
      secondaryLabelStyle: label(
        14,
        FontWeight.w600,
      ).copyWith(color: scheme.onPrimary),
      checkmarkColor: scheme.onPrimary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(control),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.primary
              : cardColour(scheme),
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : scheme.onSurface,
        ),
        textStyle: WidgetStatePropertyAll(label(14, FontWeight.w600)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: control,
        minimumSize: const Size(64, 48),
        textStyle: label(16, FontWeight.w700),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape: control,
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size(48, 44),
        textStyle: label(15, FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        shape: control,
        foregroundColor: scheme.onSurface,
        textStyle: label(15, FontWeight.w600),
      ),
    ),
    // Plain icon buttons are drawn in the same ink as the text rather than
    // Material's lighter grey. This carries a trap, so it's worth saying
    // plainly: a theme's icon button style applies to *every* kind of icon
    // button, filled ones included, and in this palette the primary colour
    // and the text ink are the same near-black, so a filled icon button
    // would come out dark on dark and disappear. Anything filled has to
    // say its own colours: see [filledIconButton].
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurface),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 3,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
      ),
      extendedTextStyle: label(16, FontWeight.w700),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainer,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      prefixIconColor: scheme.onSurfaceVariant,
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: scheme.primary, width: 1.5),
      ),
    ),
    switchTheme: SwitchThemeData(
      trackOutlineColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? Colors.transparent
            : scheme.outline,
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: scheme.onSurfaceVariant,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: scheme.outline,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(20)),
      ),
    ),
    menuTheme: MenuThemeData(
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(cardColour(scheme)),
        surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            side: hairline,
          ),
        ),
      ),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: cardColour(scheme),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.all(Radius.circular(12)),
        side: hairline,
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: scheme.primary,
      thumbColor: scheme.primary,
      inactiveTrackColor: scheme.outlineVariant,
      // A level is a level: no row of dots along the track.
      tickMarkShape: SliderTickMarkShape.noTickMark,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(color: scheme.primary),
  );
}

/// No added letter-spacing anywhere; the smallest sizes a point larger.
TextTheme _tidy(TextTheme t) {
  TextStyle? plain(TextStyle? style, {double? size, FontWeight? weight}) =>
      style?.copyWith(letterSpacing: 0, fontSize: size, fontWeight: weight);
  return TextTheme(
    displayLarge: plain(t.displayLarge),
    displayMedium: plain(t.displayMedium),
    displaySmall: plain(t.displaySmall),
    headlineLarge: plain(t.headlineLarge, weight: FontWeight.w700),
    headlineMedium: plain(t.headlineMedium, weight: FontWeight.w700),
    headlineSmall: plain(t.headlineSmall, weight: FontWeight.w700),
    titleLarge: plain(t.titleLarge, weight: FontWeight.w700),
    titleMedium: plain(t.titleMedium, weight: FontWeight.w600),
    titleSmall: plain(t.titleSmall, weight: FontWeight.w600),
    bodyLarge: plain(t.bodyLarge),
    bodyMedium: plain(t.bodyMedium),
    bodySmall: plain(t.bodySmall, size: 13),
    labelLarge: plain(t.labelLarge, weight: FontWeight.w600),
    labelMedium: plain(t.labelMedium, size: 13),
    labelSmall: plain(t.labelSmall, size: 12),
  );
}

/// The colours a filled icon button needs to be seen.
///
/// The app's icon button theme paints every icon in the text's ink, which
/// on a filled button's dark background is invisible. A filled one has to
/// put its own colours back; `icon_buttons_test.dart` fails if one is added
/// that doesn't.
ButtonStyle filledIconButton(ColorScheme scheme) => IconButton.styleFrom(
  backgroundColor: scheme.primary,
  foregroundColor: scheme.onPrimary,
);
