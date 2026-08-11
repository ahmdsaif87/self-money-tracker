import 'package:flutter/material.dart';

/// Icon component — mirrors src/components/Icon.tsx (lucide-react-native)
/// Maps lucide kebab-case names to Material Icons.
class AppIcon extends StatelessWidget {
  final String name;
  final double size;
  final Color color;

  const AppIcon(
    this.name, {
    this.size = 24,
    this.color = const Color(0xFF2C2623),
    super.key,
  });

  static const Map<String, IconData> _map = {
    'grid-2x2': Icons.grid_view_rounded,
    'receipt-text': Icons.receipt_long_rounded,
    'plus': Icons.add_rounded,
    'chart-pie': Icons.pie_chart_rounded,
    'settings': Icons.settings_rounded,
    'wallet': Icons.account_balance_wallet_rounded,
    'banknote': Icons.payments_rounded,
    'credit-card': Icons.credit_card_rounded,
    'user': Icons.person_rounded,
    'receipt': Icons.receipt_rounded,
    'arrow-right-left': Icons.swap_horiz_rounded,
    'arrow-left': Icons.arrow_back_rounded,
    'tag': Icons.sell_rounded,
    'search': Icons.search_rounded,
    'x': Icons.close_rounded,
    'inbox': Icons.inbox_rounded,
    'chevron-left': Icons.chevron_left_rounded,
    'chevron-right': Icons.chevron_right_rounded,
    'chevron-down': Icons.keyboard_arrow_down_rounded,
    'bot': Icons.smart_toy_rounded,
    'sparkles': Icons.auto_awesome_rounded,
    'wifi-off': Icons.wifi_off_rounded,
    'refresh-cw': Icons.refresh_rounded,
    'circle-check': Icons.check_circle_rounded,
    'circle-alert': Icons.error_rounded,
    'clock': Icons.schedule_rounded,
    'send': Icons.send_rounded,
    'download': Icons.download_rounded,
    'upload': Icons.upload_rounded,
    'moon': Icons.dark_mode_rounded,
    'sun': Icons.light_mode_rounded,
    'image': Icons.image_rounded,
    'camera': Icons.photo_camera_rounded,
    'pencil': Icons.edit_rounded,
    'circle-plus': Icons.add_circle_rounded,
    'calendar': Icons.calendar_today_rounded,
    'check': Icons.check_rounded,
    'trending-down': Icons.trending_down_rounded,
    'trending-up': Icons.trending_up_rounded,
    'shopping-cart': Icons.shopping_cart_rounded,
    'utensils': Icons.restaurant_rounded,
    'file-text': Icons.description_rounded,
    'car': Icons.directions_car_rounded,
    'shopping-bag': Icons.shopping_bag_rounded,
    'heart': Icons.favorite_rounded,
    'film': Icons.movie_rounded,
    'briefcase': Icons.work_rounded,
    'laptop': Icons.laptop_rounded,
    'gift': Icons.card_giftcard_rounded,
    'coffee': Icons.coffee_rounded,
    'house': Icons.home_rounded,
    'tv': Icons.tv_rounded,
    'book': Icons.menu_book_rounded,
    'zap': Icons.bolt_rounded,
    'smile': Icons.emoji_emotions_rounded,
    'star': Icons.star_rounded,
    'wrench': Icons.build_rounded,
    'shield': Icons.shield_rounded,
    'dollar-sign': Icons.attach_money_rounded,
    'music': Icons.music_note_rounded,
    'package': Icons.inventory_2_rounded,
    'activity': Icons.show_chart_rounded,
    'award': Icons.emoji_events_rounded,
    'phone': Icons.phone_rounded,
    'wifi': Icons.wifi_rounded,
    'key': Icons.key_rounded,
    'scissors': Icons.content_cut_rounded,
    'piggy-bank': Icons.savings_rounded,
    'arrow-up-right': Icons.north_east_rounded,
    'arrow-down-left': Icons.south_west_rounded,
    'help': Icons.help_outline_rounded,
    'x-circle': Icons.cancel_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final data = _map[name] ?? _map['help']!;
    return Icon(data, size: size, color: color);
  }
}
