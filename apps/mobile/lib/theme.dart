import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// Subflow design system (subF-23) — implemented from design/ "Дизайн-система",
// section 06 "theme.dart — мапінг". Warm neutrals (cream light / ink-violet dark),
// coral + sun as joy accents, a separate red for errors so it never fights the coral.

// 01 · Кольори — LIGHT
const _light = ColorScheme.light(
  primary: Color(0xFF6B5CE7),
  onPrimary: Color(0xFFFFFFFF),
  primaryContainer: Color(0xFFE7E2FF),
  onPrimaryContainer: Color(0xFF231A66),
  secondary: Color(0xFFFF7A59),
  onSecondary: Color(0xFFFFFFFF),
  tertiary: Color(0xFFFFC957),
  onTertiary: Color(0xFF2B2440),
  surface: Color(0xFFFBF7F0),
  onSurface: Color(0xFF2B2440),
  surfaceContainerLow: Color(0xFFFFFFFF),
  surfaceContainerHigh: Color(0xFFF3EDE2),
  onSurfaceVariant: Color(0xFF6E6880),
  outline: Color(0xFFD9D2C6),
  error: Color(0xFFD93F3F),
  onError: Color(0xFFFFFFFF),
);

// 01 · Кольори — DARK
const _dark = ColorScheme.dark(
  primary: Color(0xFFA99EF5),
  onPrimary: Color(0xFF231A66),
  primaryContainer: Color(0xFF4A3DB8),
  onPrimaryContainer: Color(0xFFE7E2FF),
  secondary: Color(0xFFFF9377),
  onSecondary: Color(0xFF2B1208),
  tertiary: Color(0xFFFFD57A),
  onTertiary: Color(0xFF2B2440),
  surface: Color(0xFF17141F),
  onSurface: Color(0xFFEDE9F2),
  surfaceContainerLow: Color(0xFF221D30),
  surfaceContainerHigh: Color(0xFF2B2539),
  onSurfaceVariant: Color(0xFFA49EB5),
  outline: Color(0xFF453F57),
  error: Color(0xFFF2726B),
  onError: Color(0xFF2B0808),
);

/// success/warning live outside ColorScheme (design section 01, footnote).
/// Container values are derived from the palette — confirm against the final HTML.
class SubflowColors extends ThemeExtension<SubflowColors> {
  const SubflowColors({
    required this.success,
    required this.onSuccessContainer,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  static const light = SubflowColors(
    success: Color(0xFF2FA36B),
    successContainer: Color(0xFFDFF2E7),
    onSuccessContainer: Color(0xFF0E4D2E),
    warning: Color(0xFFB07E1F),
    warningContainer: Color(0xFFFFEEC9),
    onWarningContainer: Color(0xFF5C4300),
  );

  static const dark = SubflowColors(
    success: Color(0xFF6FD3A0),
    successContainer: Color(0xFF1D4433),
    onSuccessContainer: Color(0xFFCDEFDC),
    warning: Color(0xFFFFD57A),
    warningContainer: Color(0xFF4A3A14),
    onWarningContainer: Color(0xFFFFEEC9),
  );

  @override
  SubflowColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
  }) {
    return SubflowColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
    );
  }

  @override
  SubflowColors lerp(SubflowColors? other, double t) {
    if (other == null) return this;
    return SubflowColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(successContainer, other.successContainer, t)!,
      onSuccessContainer: Color.lerp(onSuccessContainer, other.onSuccessContainer, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(warningContainer, other.warningContainer, t)!,
      onWarningContainer: Color.lerp(onWarningContainer, other.onWarningContainer, t)!,
    );
  }
}

// 02 · Типографіка: Rubik (заголовки, цифри) + Golos Text (тексти, лейбли).
// Суми набираються tabular figures, щоб цифри не "стрибали" при count-up.
TextTheme _textTheme(ColorScheme scheme) {
  final c = scheme.onSurface;
  TextStyle rubik(double size, double height, FontWeight w) => GoogleFonts.rubik(
        fontSize: size,
        height: height / size,
        fontWeight: w,
        color: c,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
  TextStyle golos(double size, double height, FontWeight w) =>
      GoogleFonts.golosText(fontSize: size, height: height / size, fontWeight: w, color: c);

  return TextTheme(
    displayLarge: rubik(52, 56, FontWeight.w800),
    headlineLarge: rubik(32, 38, FontWeight.w700),
    headlineSmall: rubik(24, 30, FontWeight.w700),
    titleLarge: rubik(19, 24, FontWeight.w600),
    titleMedium: golos(16, 22, FontWeight.w600),
    bodyLarge: golos(16, 24, FontWeight.w400),
    bodyMedium: golos(14, 21, FontWeight.w400),
    labelLarge: golos(14, 20, FontWeight.w600),
    labelSmall: golos(11, 14, FontWeight.w500),
  );
}

// 03 · Форма: чіпи 10 · поля 14 · картки 18 · діалоги/шіти 26 · кнопки stadium (h52).
ThemeData buildTheme(Brightness brightness) {
  final scheme = brightness == Brightness.light ? _light : _dark;
  final isLight = brightness == Brightness.light;
  final textTheme = _textTheme(scheme);

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    textTheme: textTheme,
    extensions: [isLight ? SubflowColors.light : SubflowColors.dark],
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outline),
      ),
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        textStyle: textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: const StadiumBorder(),
        side: BorderSide(color: scheme.outline),
        textStyle: textTheme.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(textStyle: textTheme.labelLarge),
    ),
    // Cards sit on cream as white with a feather shadow; in dark they separate by tone.
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: isLight ? BorderSide.none : BorderSide(color: scheme.outline, width: 0.5),
      ),
      margin: EdgeInsets.zero,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      backgroundColor: scheme.surfaceContainerLow,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      backgroundColor: scheme.surfaceContainerLow,
      showDragHandle: true,
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      side: BorderSide.none,
      labelStyle: textTheme.labelSmall,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      backgroundColor: isLight ? const Color(0xFF2B2440) : scheme.surfaceContainerHigh,
      contentTextStyle: textTheme.bodyMedium?.copyWith(color: isLight ? Colors.white : scheme.onSurface),
    ),
    dividerTheme: DividerThemeData(color: scheme.outline.withValues(alpha: 0.5), thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge,
    ),
  );
}
