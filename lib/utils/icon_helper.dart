import 'package:flutter/material.dart';

class IconHelper {
  static IconData getIconData(String iconName) {
    switch (iconName) {
      case 'person':
        return Icons.person;
      case 'person_outline':
        return Icons.person_outline;
      case 'work':
        return Icons.work;
      case 'shopping_cart':
        return Icons.shopping_cart;
      case 'local_grocery_store':
        return Icons.local_grocery_store;
      case 'payments':
        return Icons.payments;
      case 'home':
        return Icons.home;
      case 'directions_car':
        return Icons.directions_car;
      case 'school':
        return Icons.school;
      case 'sports':
        return Icons.sports;
      case 'restaurant':
        return Icons.restaurant;
      case 'movie':
        return Icons.movie;
      case 'health_and_safety':
        return Icons.health_and_safety;
      case 'pets':
        return Icons.pets;
      case 'card_giftcard':
        return Icons.card_giftcard;
      case 'receipt':
        return Icons.receipt;
      case 'trending_up':
        return Icons.trending_up;
      case 'trending_down':
        return Icons.trending_down;
      case 'swap_horiz':
        return Icons.swap_horiz;
      case 'account_balance_wallet':
        return Icons.account_balance_wallet;
      default:
        return Icons.help_outline;
    }
  }

  static List<String> get availableIcons => [
    'person',
    'person_outline',
    'work',
    'shopping_cart',
    'local_grocery_store',
    'payments',
    'home',
    'directions_car',
    'school',
    'sports',
    'restaurant',
    'movie',
    'health_and_safety',
    'pets',
    'card_giftcard',
    'receipt',
    'trending_up',
    'trending_down',
    'swap_horiz',
    'account_balance_wallet',
  ];
}
