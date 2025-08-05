import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/detector_screen.dart';
import 'package:flutter_application_1/screens/gallery_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _checkForRestore();
  }

  Future<void> _checkForRestore() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('wasOnDetectorScreen') ?? false) {
      await prefs.setBool('wasOnDetectorScreen', false);
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const DetectorScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    final double screenHeight = screenSize.height;
    final double screenWidth = screenSize.width;

    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      padding: EdgeInsets.symmetric(
        //--NOVO AJUSTE: Botões mais estreitos e finos--
        horizontal: screenWidth * 0.07, // Antes era 0.08
        vertical: screenHeight * 0.015, // Antes era 0.018
      ),
      textStyle: TextStyle(
        //--NOVO AJUSTE: Fonte do botão ligeiramente menor--
        fontSize: screenWidth * 0.038, // Antes era 0.04
        fontWeight: FontWeight.bold,
      ),
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
              child: Padding(
                // Adicionado um Padding para garantir que o conteúdo não cole nas bordas
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Detector de Azulejos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        //--NOVO AJUSTE: Redução significativa no título--
                        fontSize: screenWidth * 0.1, // Antes era 0.07
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 1.2,
                      ),
                    ),
                    //--NOVO AJUSTE: Espaçamento principal ainda menor--
                    SizedBox(height: screenHeight * 0.04), // Antes era 0.05

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

                    //--NOVO AJUSTE: Espaçamento entre botões menor--
                    SizedBox(height: screenHeight * 0.018), // Antes era 0.02

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
          ),
        ],
      ),
    );
  }
}
