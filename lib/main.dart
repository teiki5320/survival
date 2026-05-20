import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'widgets/side_scroll_scene.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const TrainCosyApp());
}

class TrainCosyApp extends StatelessWidget {
  const TrainCosyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Train Cosy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF8B6F4E),
        brightness: Brightness.dark,
      ),
      home: const WagonScreen(),
    );
  }
}

class WagonScreen extends StatefulWidget {
  const WagonScreen({super.key});

  @override
  State<WagonScreen> createState() => _WagonScreenState();
}

class _WagonScreenState extends State<WagonScreen> {
  bool _cleaned = true;
  bool _running = true;
  bool _night = false;
  bool _dancing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: SideScrollScene(
              cleaned: _cleaned,
              running: _running,
              night: _night,
              dancing: _dancing,
              onUserInteract: () {
                if (_dancing) setState(() => _dancing = false);
              },
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'toggle_dance',
                    tooltip: _dancing ? 'Arrêter de danser' : 'Danser',
                    onPressed: () => setState(() => _dancing = !_dancing),
                    child: Icon(_dancing ? Icons.stop : Icons.celebration),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'toggle_night',
                    tooltip: _night ? 'Passer en jour' : 'Passer en nuit',
                    onPressed: () => setState(() => _night = !_night),
                    child: Icon(_night ? Icons.wb_sunny : Icons.nightlight_round),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'toggle_clean',
                    tooltip: _cleaned ? 'Salir le wagon' : 'Nettoyer le wagon',
                    onPressed: () => setState(() => _cleaned = !_cleaned),
                    child: Icon(_cleaned ? Icons.cleaning_services : Icons.water_drop),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton.small(
                    heroTag: 'toggle_run',
                    tooltip: _running ? 'Arrêter le train' : 'Démarrer le train',
                    onPressed: () => setState(() => _running = !_running),
                    child: Icon(_running ? Icons.pause : Icons.play_arrow),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
