import 'package:flutter/widgets.dart';
import 'package:google_fonts/google_fonts.dart';

enum ThemeName { calm, editorial, telemetry }

extension ThemeNameLabel on ThemeName {
  String get label => switch (this) {
        ThemeName.calm => 'Calm',
        ThemeName.editorial => 'Editorial',
        ThemeName.telemetry => 'Telemetry',
      };
}

/// Design tokens ported 1:1 from the prototype's three theme directions.
class Tokens {
  const Tokens({
    required this.bg,
    required this.panel,
    required this.panel2,
    required this.line,
    required this.ink,
    required this.mute,
    required this.a,
    required this.aSoft,
    required this.b,
    required this.bSoft,
    required this.bInk,
    required this.r,
    required this.rs,
    required this.headFont,
    required this.headWeight,
    required this.headUpper,
    required this.headTracking,
    required this.bodyFont,
    required this.monoFont,
    required this.dark,
  });

  final Color bg, panel, panel2, line, ink, mute, a, aSoft, b, bSoft, bInk;
  final double r, rs;
  final String headFont, bodyFont, monoFont;
  final FontWeight headWeight;
  final bool headUpper;

  /// Letter spacing in em.
  final double headTracking;
  final bool dark;

  static const calm = Tokens(
    bg: Color(0xFF0F1012),
    panel: Color(0xFF16171A),
    panel2: Color(0xFF1E1F23),
    line: Color(0x12FFFFFF),
    ink: Color(0xFFECEBE8),
    mute: Color(0xFF8E8D89),
    a: Color(0xFFC08A82),
    aSoft: Color(0x1FC08A82),
    b: Color(0xFF61D19A),
    bSoft: Color(0x1F50C896),
    bInk: Color(0xFF08140F),
    r: 14,
    rs: 8,
    headFont: 'Geist',
    headWeight: FontWeight.w600,
    headUpper: false,
    headTracking: -0.025,
    bodyFont: 'Geist',
    monoFont: 'Geist Mono',
    dark: true,
  );

  static const editorial = Tokens(
    bg: Color(0xFFF7F6F3),
    panel: Color(0xFFFFFFFF),
    panel2: Color(0xFFFFFFFF),
    line: Color(0xFFEAEAEA),
    ink: Color(0xFF2F3437),
    mute: Color(0xFF787774),
    a: Color(0xFF9F2F2D),
    aSoft: Color(0xFFFDEBEC),
    b: Color(0xFF1F6C9F),
    bSoft: Color(0xFFE1F3FE),
    bInk: Color(0xFFFFFFFF),
    r: 10,
    rs: 5,
    headFont: 'Instrument Serif',
    headWeight: FontWeight.w400,
    headUpper: false,
    headTracking: -0.02,
    bodyFont: 'Geist',
    monoFont: 'Geist Mono',
    dark: false,
  );

  static const telemetry = Tokens(
    bg: Color(0xFF0A0A0A),
    panel: Color(0xFF111111),
    panel2: Color(0xFF161616),
    line: Color(0xFF2A2A2A),
    ink: Color(0xFFEAEAEA),
    mute: Color(0xFF8A8A8A),
    a: Color(0xFFFF2A2A),
    aSoft: Color(0x1FFF2A2A),
    b: Color(0xFF4AF626),
    bSoft: Color(0x174AF626),
    bInk: Color(0xFF0A0A0A),
    r: 0,
    rs: 0,
    headFont: 'Archivo Black',
    headWeight: FontWeight.w400,
    headUpper: true,
    headTracking: -0.03,
    bodyFont: 'JetBrains Mono',
    monoFont: 'JetBrains Mono',
    dark: true,
  );

  static Tokens of(ThemeName n) => switch (n) {
        ThemeName.calm => calm,
        ThemeName.editorial => editorial,
        ThemeName.telemetry => telemetry,
      };

  TextStyle _font(String family, TextStyle base) =>
      GoogleFonts.getFont(family, textStyle: base);

  /// Body text (default 14px).
  TextStyle body({double size = 14, FontWeight weight = FontWeight.w400, Color? color, double height = 1.5}) =>
      _font(bodyFont, TextStyle(fontSize: size, fontWeight: weight, color: color ?? ink, height: height));

  /// Monospace text.
  TextStyle mono({double size = 12, FontWeight weight = FontWeight.w400, Color? color, double height = 1.4, double tracking = 0}) =>
      _font(monoFont,
          TextStyle(fontSize: size, fontWeight: weight, color: color ?? ink, height: height, letterSpacing: tracking * size));

  /// Display heading.
  TextStyle head(double size, {Color? color, double height = 1.1}) => _font(
      headFont,
      TextStyle(
          fontSize: size,
          fontWeight: headWeight,
          color: color ?? ink,
          height: height,
          letterSpacing: headTracking * size));

  String headText(String s) => headUpper ? s.toUpperCase() : s;

  /// Small uppercase mono label ("eyebrow").
  TextStyle get eyebrow => mono(size: 11, weight: FontWeight.w500, color: mute, tracking: .08);

  /// Equivalent of CSS color-mix(in oklab, b pct%, panel).
  Color mixB(double pct) => Color.lerp(panel, b, pct)!;
}

class TokensScope extends InheritedWidget {
  const TokensScope({super.key, required this.tokens, required super.child});
  final Tokens tokens;

  static Tokens of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TokensScope>()!.tokens;

  @override
  bool updateShouldNotify(TokensScope old) => old.tokens != tokens;
}

extension TokensContext on BuildContext {
  Tokens get t => TokensScope.of(this);
}
