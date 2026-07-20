import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get display => GoogleFonts.outfit(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -1.5,
    color: AppColors.ink,
  );

  static TextStyle get h1 => GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    height: 1.08,
    letterSpacing: -1.2,
    color: AppColors.ink,
  );

  static TextStyle get h2 => GoogleFonts.outfit(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.8,
    color: AppColors.ink,
  );

  static TextStyle get h3 => GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static TextStyle get h4 => GoogleFonts.outfit(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static TextStyle get body => GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.ink,
  );

  static TextStyle get bodySmall => GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.muted,
  );

  static TextStyle get label => GoogleFonts.outfit(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: AppColors.ink,
  );

  static TextStyle get labelSmall => GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.muted,
  );

  static TextStyle get caption => GoogleFonts.outfit(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.muted,
  );

  static TextStyle get button => GoogleFonts.outfit(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static TextStyle get price => GoogleFonts.outfit(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: AppColors.brand,
    letterSpacing: -0.3,
  );

  // White variants for use on dark backgrounds
  static TextStyle get h1White => h1.copyWith(color: Colors.white);
  static TextStyle get h2White => h2.copyWith(color: Colors.white);
  static TextStyle get h3White => h3.copyWith(color: Colors.white);
  static TextStyle get h4White => h4.copyWith(color: Colors.white);
  static TextStyle get bodyWhite => body.copyWith(color: Colors.white.withValues(alpha: .85));
  static TextStyle get bodySmallWhite => bodySmall.copyWith(color: Colors.white.withValues(alpha: .65));

  // Accent/brand tinted
  static TextStyle get labelBrand => label.copyWith(color: AppColors.brand);
  static TextStyle get bodyBrand => body.copyWith(color: AppColors.brand);
}
