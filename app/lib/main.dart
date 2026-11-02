import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'data/mock_glove_source.dart';
import 'state/glove_controller.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => GloveController(MockGloveSource()),
      child: const SmartGloveApp(),
    ),
  );
}