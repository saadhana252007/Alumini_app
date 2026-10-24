import 'package:flutter/material.dart';

class AppColors {
  static const navy = Color(0xFF0B2545);
  static const navyLight = Color(0xFF13315C);
  static const navyDark = Color(0xFF06172E);
  static const gold = Color(0xFFB8963E);
  static const goldSoft = Color(0xFFF3EBD3);
  static const canvas = Color(0xFFF4F6FA);
  static const ink = Color(0xFF1B2433);
  static const muted = Color(0xFF5B6678);
  static const line = Color(0xFFDDE2EA);
  static const success = Color(0xFF1E7B4F);
  static const danger = Color(0xFFB3261E);
  static const warning = Color(0xFFB7791F);
  static const info = Color(0xFF2B6CB0);

  static Color tint(Color c, [double opacity = 0.12]) =>
      c.withAlpha((opacity * 255).round());
}
