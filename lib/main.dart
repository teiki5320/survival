import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/scene_config.dart';
import 'services/scene_state.dart';
import 'widgets/debug_menu.dart';
import 'widgets/wagon_view.dart';

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
  late Future<SceneConfig> _configFuture;
  SceneState? _state;

  @override
  void initState() {
    super.initState();
    _configFuture = SceneConfig.load('assets/config/scene.json');
  }

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<SceneConfig>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Impossible de charger la scène:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          final config = snapshot.data!;
          final state = _state ??= SceneState(config);

          return Stack(
            children: [
              Positioned.fill(child: WagonView(config: config, state: state)),
              Positioned(
                right: 16,
                bottom: 16,
                child: SafeArea(
                  child: FloatingActionButton(
                    heroTag: 'debug_fab',
                    tooltip: 'Debug — objets',
                    onPressed: () => DebugObjectsSheet.show(
                      context,
                      config: config,
                      state: state,
                    ),
                    child: const Icon(Icons.tune),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
