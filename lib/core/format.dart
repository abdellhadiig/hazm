import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'l10n.dart';

typedef ClockParts = ({String main, String minor, String trace});

abstract final class Fmt {
  static String two(int value) => value.toString().padLeft(2, '0');

  static String clock(Duration duration) {
    final total = math.max(0, duration.inSeconds);
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) return '${two(hours)}:${two(minutes)}:${two(seconds)}';
    return '${two(minutes)}:${two(seconds)}';
  }

  static ClockParts parts(int totalSeconds) {
    final total = math.max(0, totalSeconds);
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    if (hours > 0) return (main: two(hours), minor: ':${two(minutes)}', trace: ':${two(seconds)}');
    if (minutes > 0) return (main: two(minutes), minor: ':${two(seconds)}', trace: '');
    return (main: two(seconds), minor: '', trace: '');
  }

  static String duration(L10n l, int seconds) {
    final total = math.max(0, seconds);
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final h = l.t('unitH');
    final m = l.t('unitM');
    if (hours > 0 && minutes > 0) return '$hours$h $minutes$m';
    if (hours > 0) return '$hours$h';
    if (minutes > 0) return '$minutes$m';
    if (total > 0) return '$total${l.t('unitS')}';
    return '0$m';
  }

  static String minutes(L10n l, int minutes) => duration(l, minutes * 60);

  static String preset(L10n l, int minutes) {
    if (minutes < 60) return '$minutes${l.t('unitM')}';
    final hours = minutes / 60;
    final text = hours == hours.roundToDouble() ? hours.toStringAsFixed(0) : hours.toStringAsFixed(1);
    return '$text${l.t('unitH')}';
  }

  static String hour(BuildContext context, int hour) {
    final l = context.l10n;
    if (MediaQuery.alwaysUse24HourFormatOf(context)) return '${two(hour)}:00';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display ${l.t(hour < 12 ? 'am' : 'pm')}';
  }

  static String time(BuildContext context, DateTime value) {
    final l = context.l10n;
    if (MediaQuery.alwaysUse24HourFormatOf(context)) return '${two(value.hour)}:${two(value.minute)}';
    final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    return '$hour:${two(value.minute)} ${l.t(value.hour < 12 ? 'am' : 'pm')}';
  }

  static String day(L10n l, DateTime value, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(value.year, value.month, value.day);
    final difference = today.difference(target).inDays;
    if (difference == 0) return l.t('today');
    if (difference == 1) return l.t('yesterday');
    return '${value.day} ${l.month(value.month)}';
  }

  static int ceilSeconds(Duration duration) => math.max(0, (duration.inMilliseconds + 999) ~/ 1000);

  static int percent(num part, num whole) => whole <= 0 ? 0 : (part * 100 / whole).round();

  static String pct(L10n l, int value) => l.isArabic ? '$value٪' : '$value%';
}
