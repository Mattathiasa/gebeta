import 'package:flutter/material.dart';

/// Gebeta's visual language: the carved wooden board, cream clay,
/// honey-gold (tej) accents. Dark enough for outdoor Addis sunlight,
/// warm enough to feel like wood and not like a spreadsheet.
abstract final class GebetaColors {
  // Surfaces
  static const cream = Color(0xFFFAF4E8);
  static const creamDeep = Color(0xFFF1E6D0);
  static const wood = Color(0xFF8B5E3C);
  static const woodDark = Color(0xFF5C3A21);
  static const woodDarkest = Color(0xFF3E2723);

  // Brand
  static const gold = Color(0xFFD4A017);
  static const goldDeep = Color(0xFFB8860B);
  static const honey = Color(0xFFE8B94A);

  // Seeds — two sides of the board
  static const seedDark = Color(0xFF3E2723);
  static const seedLight = Color(0xFFF5E6C8);

  // Semantic
  static const win = Color(0xFF2E7D32);
  static const danger = Color(0xFFC62828);
  static const info = Color(0xFF1565C0);

  // Text
  static const ink = Color(0xFF2B1D12);
  static const inkSoft = Color(0xFF6B5644);
  static const onDark = Color(0xFFFAF4E8);

  // Dark theme flips the wood to the background
  static const darkBackground = Color(0xFF1A120B);
  static const darkSurface = Color(0xFF2B1D12);
}
