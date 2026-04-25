import 'package:flutter/material.dart';

/// A user-defined category that lives alongside the built-in enum categories.
class CustomCategory {
  final String id;
  final String label;
  final int iconCodePoint; // stores IconData.codePoint
  final String fontFamily; // e.g. 'MaterialIcons'
  final Color color;
  final bool isExpense; // true = expense, false = income

  const CustomCategory({
    required this.id,
    required this.label,
    required this.iconCodePoint,
    required this.fontFamily,
    required this.color,
    required this.isExpense,
  });

  IconData get icon => IconData(iconCodePoint, fontFamily: fontFamily);

  CustomCategory copyWith({
    String? label,
    int? iconCodePoint,
    String? fontFamily,
    Color? color,
    bool? isExpense,
  }) {
    return CustomCategory(
      id: id,
      label: label ?? this.label,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      fontFamily: fontFamily ?? this.fontFamily,
      color: color ?? this.color,
      isExpense: isExpense ?? this.isExpense,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'label': label,
    'iconCodePoint': iconCodePoint,
    'fontFamily': fontFamily,
    'color': color.toARGB32(),
    'isExpense': isExpense,
  };

  factory CustomCategory.fromMap(Map<String, dynamic> map) => CustomCategory(
    id: map['id'] as String,
    label: map['label'] as String,
    iconCodePoint: map['iconCodePoint'] as int,
    fontFamily: map['fontFamily'] as String,
    color: Color(map['color'] as int),
    isExpense: map['isExpense'] as bool,
  );
}

// ── Palette of colors the user can pick from ─────────────────────────────────

const categoryColorPalette = [
  Color(0xFFFF6B6B),
  Color(0xFF4ECDC4),
  Color(0xFFFFBE0B),
  Color(0xFF9B59B6),
  Color(0xFFE74C3C),
  Color(0xFF3498DB),
  Color(0xFF2ECC71),
  Color(0xFF1ABC9C),
  Color(0xFF2D9E6B),
  Color(0xFF27AE60),
  Color(0xFF16A085),
  Color(0xFFE91E63),
  Color(0xFFFF9800),
  Color(0xFF607D8B),
  Color(0xFF795548),
  Color(0xFF00BCD4),
  Color(0xFF8BC34A),
  Color(0xFFCDDC39),
];

// ── Icon pool the user can pick from ─────────────────────────────────────────

class PickableIcon {
  final IconData icon;
  final String label;
  const PickableIcon(this.icon, this.label);
}

const iconPool = [
  // Finance
  PickableIcon(Icons.account_balance_wallet_rounded, 'Wallet'),
  PickableIcon(Icons.savings_rounded, 'Savings'),
  PickableIcon(Icons.credit_card_rounded, 'Card'),
  PickableIcon(Icons.attach_money_rounded, 'Money'),
  PickableIcon(Icons.currency_rupee_rounded, 'Rupee'),
  PickableIcon(Icons.trending_up_rounded, 'Trending Up'),
  PickableIcon(Icons.trending_down_rounded, 'Trending Down'),
  PickableIcon(Icons.bar_chart_rounded, 'Chart'),
  PickableIcon(Icons.pie_chart_rounded, 'Pie Chart'),
  PickableIcon(Icons.receipt_long_rounded, 'Receipt'),
  // Food & Drink
  PickableIcon(Icons.restaurant_rounded, 'Restaurant'),
  PickableIcon(Icons.local_cafe_rounded, 'Cafe'),
  PickableIcon(Icons.local_pizza_rounded, 'Pizza'),
  PickableIcon(Icons.fastfood_rounded, 'Fast Food'),
  PickableIcon(Icons.local_bar_rounded, 'Bar'),
  PickableIcon(Icons.cake_rounded, 'Cake'),
  PickableIcon(Icons.set_meal_rounded, 'Meal'),
  PickableIcon(Icons.lunch_dining_rounded, 'Lunch'),
  // Transport
  PickableIcon(Icons.directions_car_rounded, 'Car'),
  PickableIcon(Icons.directions_bus_rounded, 'Bus'),
  PickableIcon(Icons.train_rounded, 'Train'),
  PickableIcon(Icons.flight_rounded, 'Flight'),
  PickableIcon(Icons.two_wheeler_rounded, 'Bike'),
  PickableIcon(Icons.local_taxi_rounded, 'Taxi'),
  PickableIcon(Icons.directions_walk_rounded, 'Walk'),
  PickableIcon(Icons.electric_scooter_rounded, 'Scooter'),
  // Shopping
  PickableIcon(Icons.shopping_bag_rounded, 'Shopping Bag'),
  PickableIcon(Icons.shopping_cart_rounded, 'Cart'),
  PickableIcon(Icons.storefront_rounded, 'Store'),
  PickableIcon(Icons.local_mall_rounded, 'Mall'),
  PickableIcon(Icons.checkroom_rounded, 'Clothing'),
  PickableIcon(Icons.diamond_rounded, 'Jewellery'),
  // Home & Utilities
  PickableIcon(Icons.home_rounded, 'Home'),
  PickableIcon(Icons.apartment_rounded, 'Apartment'),
  PickableIcon(Icons.bolt_rounded, 'Electricity'),
  PickableIcon(Icons.water_drop_rounded, 'Water'),
  PickableIcon(Icons.wifi_rounded, 'WiFi'),
  PickableIcon(Icons.phone_rounded, 'Phone'),
  PickableIcon(Icons.tv_rounded, 'TV'),
  PickableIcon(Icons.kitchen_rounded, 'Kitchen'),
  // Health
  PickableIcon(Icons.favorite_rounded, 'Health'),
  PickableIcon(Icons.local_hospital_rounded, 'Hospital'),
  PickableIcon(Icons.medication_rounded, 'Medicine'),
  PickableIcon(Icons.fitness_center_rounded, 'Gym'),
  PickableIcon(Icons.spa_rounded, 'Spa'),
  PickableIcon(Icons.self_improvement_rounded, 'Wellness'),
  // Entertainment
  PickableIcon(Icons.movie_rounded, 'Movie'),
  PickableIcon(Icons.music_note_rounded, 'Music'),
  PickableIcon(Icons.sports_esports_rounded, 'Gaming'),
  PickableIcon(Icons.sports_rounded, 'Sports'),
  PickableIcon(Icons.beach_access_rounded, 'Beach'),
  PickableIcon(Icons.hiking_rounded, 'Hiking'),
  PickableIcon(Icons.celebration_rounded, 'Party'),
  PickableIcon(Icons.theater_comedy_rounded, 'Theatre'),
  // Education & Work
  PickableIcon(Icons.school_rounded, 'School'),
  PickableIcon(Icons.menu_book_rounded, 'Books'),
  PickableIcon(Icons.laptop_rounded, 'Laptop'),
  PickableIcon(Icons.work_rounded, 'Work'),
  PickableIcon(Icons.business_center_rounded, 'Business'),
  PickableIcon(Icons.science_rounded, 'Science'),
  // People & Gifts
  PickableIcon(Icons.card_giftcard_rounded, 'Gift'),
  PickableIcon(Icons.people_rounded, 'People'),
  PickableIcon(Icons.child_care_rounded, 'Child'),
  PickableIcon(Icons.pets_rounded, 'Pets'),
  PickableIcon(Icons.volunteer_activism_rounded, 'Charity'),
  // Misc
  PickableIcon(Icons.category_rounded, 'Category'),
  PickableIcon(Icons.star_rounded, 'Star'),
  PickableIcon(Icons.flag_rounded, 'Flag'),
  PickableIcon(Icons.label_rounded, 'Label'),
  PickableIcon(Icons.build_rounded, 'Tools'),
  PickableIcon(Icons.camera_alt_rounded, 'Camera'),
  PickableIcon(Icons.local_florist_rounded, 'Flower'),
  PickableIcon(Icons.park_rounded, 'Park'),
];
