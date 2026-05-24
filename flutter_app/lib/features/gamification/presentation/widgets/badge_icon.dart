import 'package:flutter/material.dart';

/// Resolves the backend's ``icon`` name string into a Material
/// [IconData]. The backend ships icon names (e.g.
/// ``"local_fire_department_rounded"``) so we don't have to round-trip
/// codepoints across the wire — and so renaming an icon in the catalog
/// doesn't break already-earned badges.
///
/// Unknown names fall back to a generic [Icons.shield_rounded] so a
/// future catalog addition still renders (it just won't have a
/// pretty icon until this map is updated).
IconData iconForBadgeName(String name) {
  return _iconMap[name] ?? Icons.shield_rounded;
}

const Map<String, IconData> _iconMap = {
  // First-time milestones
  'spa_rounded': Icons.spa_rounded,
  'style_rounded': Icons.style_rounded,

  // Streak progression
  'whatshot_rounded': Icons.whatshot_rounded,
  'local_fire_department_rounded': Icons.local_fire_department_rounded,
  'emoji_events_rounded': Icons.emoji_events_rounded,
  'military_tech_rounded': Icons.military_tech_rounded,

  // Question volume
  'menu_book_rounded': Icons.menu_book_rounded,
  'school_rounded': Icons.school_rounded,
  'auto_awesome_rounded': Icons.auto_awesome_rounded,

  // Accuracy
  'adjust_rounded': Icons.adjust_rounded,
  'gps_fixed_rounded': Icons.gps_fixed_rounded,
  'workspace_premium_rounded': Icons.workspace_premium_rounded,

  // XP
  'star_rounded': Icons.star_rounded,
  'bolt_rounded': Icons.bolt_rounded,
  // The catalog has ``trophy_rounded``; Material's name is
  // ``emoji_events`` (no separate rounded variant for the trophy
  // glyph). Mapped to the closest match.
  'trophy_rounded': Icons.emoji_events_rounded,

  // Flashcards
  'filter_drama_rounded': Icons.filter_drama_rounded,
  'psychology_rounded': Icons.psychology_rounded,

  // Level
  'emoji_events_outlined': Icons.emoji_events_outlined,
  'auto_stories_rounded': Icons.auto_stories_rounded,
};
