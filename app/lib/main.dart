import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/config_store.dart';
import 'data/mock_glove_source.dart';
import 'state/config_controller.dart';
import 'state/glove_controller.dart';

void main() {
  final source = MockGloveSource();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GloveController(source)),
        ChangeNotifierProvider(
          create: (_) => ConfigController(ConfigStore(), source)..load(),
        ),
      ],
      child: const SmartGloveApp(),
    ),
  );
}