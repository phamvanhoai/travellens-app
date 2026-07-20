import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get display => GoogleFonts.inter(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    height: 1.05,
    letterSpacing: -1.5,
    color: AppColors.ink,
  );

  static TextStyle get h1 => GoogleFonts.inter(
    fontSize: 32,
    fontWeight: FontWeight.w900,
    height: 1.08,
    letterSpacing: -1.2,
    color: AppColors.ink,
  );

  static TextStyle get h2 => GoogleFonts.inter(
    fontSize: 26,
    fontWeight: FontWeight.w800,
    height: 1.12,
    letterSpacing: -0.8,
    color: AppColors.ink,
  );

  static TextStyle get h3 => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w800,
    height: 1.2,
    letterSpacing: -0.4,
    color: AppColors.ink,
  );

  static TextStyle get h4 => GoogleFonts.inter(
    fontSize: 17,
    fontWeight: FontWeight.w700,
    height: 1.3,
    letterSpacing: -0.2,
    color: AppColors.ink,
  );

  static TextStyle get body => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.55,
    color: AppColors.ink,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.5,
    color: AppColors.muted,
  );

  static TextStyle get label => GoogleFonts.inter(
    fontSize: 13,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
    color: AppColors.ink,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    color: AppColors.muted,
  );

  static TextStyle get caption => GoogleFonts.inter(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.4,
    color: AppColors.muted,
  );

  static TextStyle get button => GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.1,
  );

  static TextStyle get price => GoogleFonts.inter(
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
