import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/game_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } catch (_) {}
  }
  runApp(const WhiteWarApp());
}

class WhiteWarApp extends StatelessWidget {
  const WhiteWarApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'White War',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Baloo',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2B5C9E), brightness: Brightness.dark),
      ),
      home: const GamePage(),
    );
  }
}
