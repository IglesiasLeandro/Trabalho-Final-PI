import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/home_screen.dart'; // Importa a nova tela inicial

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detector de Azulejo',
      theme: ThemeData(
        brightness: Brightness.dark, // Um tema escuro combina com o overlay
        primarySwatch: Colors.lightBlue,
        useMaterial3: true,
      ),
      home:
          const HomeScreen(), // A nova tela inicial é a primeira a ser exibida
      debugShowCheckedModeBanner: false,
    );
  }
}
