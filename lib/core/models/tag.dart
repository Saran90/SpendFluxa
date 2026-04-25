import 'package:flutter/material.dart';

/// Represents a tag that can be applied to transactions for grouping.
/// Example: "Wedding", "Vacation", "Birthday Party", etc.
class Tag {
  final String id;
  final String name;
  final Color color;
  final IconData icon;
  final DateTime createdAt;

  const Tag({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.createdAt,
  });

  Tag copyWith({String? name, Color? color, IconData? icon}) {
    return Tag(
      id: id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'color': color.value,
    'iconCodePoint': icon.codePoint,
    'iconFontFamily': icon.fontFamily ?? 'MaterialIcons',
    'createdAt': createdAt.toIso8601String(),
  };

  factory Tag.fromMap(Map<String, dynamic> map) => Tag(
    id: map['id'] as String,
    name: map['name'] as String,
    color: Color(map['color'] as int),
    icon: IconData(
      map['iconCodePoint'] as int,
      fontFamily: map['iconFontFamily'] as String,
    ),
    createdAt: DateTime.parse(map['createdAt'] as String),
  );
}

// ── Tag color palette ─────────────────────────────────────────────────────────

const tagColorPalette = [
  Color(0xFFFF6B6B), // Red
  Color(0xFF4ECDC4), // Teal
  Color(0xFFFFBE0B), // Yellow
  Color(0xFF9B59B6), // Purple
  Color(0xFFE74C3C), // Dark Red
  Color(0xFF3498DB), // Blue
  Color(0xFF2ECC71), // Green
  Color(0xFF1ABC9C), // Turquoise
  Color(0xFF2D9E6B), // Dark Green
  Color(0xFF27AE60), // Forest Green
  Color(0xFF16A085), // Dark Turquoise
  Color(0xFFE91E63), // Pink
  Color(0xFFFF9800), // Orange
  Color(0xFF607D8B), // Blue Grey
  Color(0xFF795548), // Brown
  Color(0xFF00BCD4), // Cyan
  Color(0xFF8BC34A), // Light Green
  Color(0xFFCDDC39), // Lime
  Color(0xFFF44336), // Bright Red
  Color(0xFF673AB7), // Deep Purple
];

// ── Tag icon pool ─────────────────────────────────────────────────────────────

const tagIconPool = [
  Icons.label_rounded,
  Icons.local_offer_rounded,
  Icons.bookmark_rounded,
  Icons.flag_rounded,
  Icons.star_rounded,
  Icons.favorite_rounded,
  Icons.celebration_rounded,
  Icons.cake_rounded,
  Icons.card_giftcard_rounded,
  Icons.beach_access_rounded,
  Icons.flight_rounded,
  Icons.hotel_rounded,
  Icons.restaurant_rounded,
  Icons.local_cafe_rounded,
  Icons.shopping_bag_rounded,
  Icons.home_rounded,
  Icons.work_rounded,
  Icons.school_rounded,
  Icons.fitness_center_rounded,
  Icons.sports_esports_rounded,
  Icons.music_note_rounded,
  Icons.movie_rounded,
  Icons.camera_alt_rounded,
  Icons.palette_rounded,
  Icons.build_rounded,
  Icons.lightbulb_rounded,
  Icons.pets_rounded,
  Icons.child_care_rounded,
  Icons.volunteer_activism_rounded,
  Icons.park_rounded,
];
