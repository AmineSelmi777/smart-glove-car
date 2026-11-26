import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/config_store.dart';
import 'data/mock_glove_source.dart';
import 'state/config_controller.dart';
import 'state/drive_controller.dart';
import 'state/glove_controller.dart';
import 'state/link_controller.dart';
import 'state/settings_controller.dart';

void main() {
  final link = LinkController()..load();
  final legacySource = MockGloveSource(); // only for the Mappings and History tabs (Random Forest experiment)

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsController()..load()),
        ChangeNotifierProvider.value(value: link),
        ChangeNotifierProvider(create: (_) => DriveController(() => link.gateway)),
        ChangeNotifierProvider(create: (_) => GloveController(legacySource)),
        ChangeNotifierProvider(create: (_) => ConfigController(ConfigStore(), legacySource)..load()),
      ],
      child: const SmartGloveApp(),
    ),
  );
}