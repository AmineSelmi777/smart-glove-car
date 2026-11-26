import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  ThemeMode themeMode = ThemeMode.dark;

  // Will come from the driver profile later.
  double maxSpeedKmh = 12;

  // Flex calibration (raw ADC), persisted.
  static const int defaultFlexOpen = 1250;
  static const int defaultFlexClosed = 2750;
  int flexOpen = defaultFlexOpen;
  int flexClosed = defaultFlexClosed;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode = p.getString('theme') == 'light' ? ThemeMode.light : ThemeMode.dark;
    flexOpen = p.getInt('flex_open') ?? defaultFlexOpen;
    flexClosed = p.getInt('flex_closed') ?? defaultFlexClosed;
    notifyListeners();
  }

  Future<void> toggleTheme() async {
    themeMode = themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString('theme', themeMode == ThemeMode.light ? 'light' : 'dark');
  }

  Future<void> setFlexCalibration({int? open, int? closed}) async {
    flexOpen = open ?? flexOpen;
    flexClosed = closed ?? flexClosed;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setInt('flex_open', flexOpen);
    await p.setInt('flex_closed', flexClosed);
  }
}
