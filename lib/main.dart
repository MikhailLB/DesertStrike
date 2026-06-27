import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'screens/loading_screen.dart';
import 'services/progress_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ProgressService.instance.init();
  // Immersive full-screen so the artwork fills the surface edge to edge.
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  runApp(const DesertStrikeApp());
}

class DesertStrikeApp extends StatelessWidget {
  const DesertStrikeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Desert Strike',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE08A2B),
          brightness: Brightness.dark,
        ),
        fontFamily: 'sans-serif',
      ),
      home: const LoadingScreen(),
    );
  }
}
