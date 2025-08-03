import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/detector_screen.dart';
import 'package:flutter_application_1/screens/gallery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // 1. Importe o pacote

// 2. A tela foi transformada em StatefulWidget para usar o initState
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkForRestore(); // 3. Verifica o estado assim que a tela é construída
  }

  // 4. Lógica de restauração para lidar com a "Morte de Processo" do Android
  Future<void> _checkForRestore() async {
    final prefs = await SharedPreferences.getInstance();

    // Verifica se a "lembrança" de que estávamos na tela de detecção existe
    if (prefs.getBool('wasOnDetectorScreen') ?? false) {
      // Limpa a "lembrança" para não acontecer de novo sem querer
      await prefs.setBool('wasOnDetectorScreen', false);

      // Navega para a tela de detecção
      if (mounted) {
        // 'mounted' verifica se a tela ainda existe
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DetectorScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // O resto do seu código da interface continua exatamente igual
    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/background.png', fit: BoxFit.cover),
          Container(color: Colors.black.withOpacity(0.5)),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Detector de Azulejos',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 50),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const DetectorScreen(),
                        ),
                      );
                    },
                    style: buttonStyle,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Iniciar Detector'),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const GalleryScreen(),
                        ),
                      );
                    },
                    style: buttonStyle.copyWith(
                      backgroundColor: MaterialStateProperty.all(
                        Colors.white30,
                      ),
                    ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('Ver Catálogo'),
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
