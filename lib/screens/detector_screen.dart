// 1. LISTA DE IMPORTS CORRETA E COMPLETA
import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:image/image.dart' as image_lib;
import 'package:shared_preferences/shared_preferences.dart';

// O RESTO DO SEU CÓDIGO (EXATAMENTE COMO ESTAVA)
String _detectarAzulejoIsolate(Map<String, String> paths) {
  try {
    final DynamicLibrary nativeLib = DynamicLibrary.open(
      "libazulejo_detector.so",
    );
    final Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)
    getBestTitle = nativeLib
        .lookup<
          NativeFunction<Pointer<Utf8> Function(Pointer<Utf8>, Pointer<Utf8>)>
        >("get_best_title")
        .asFunction();
    final scenePath = paths['scenePath']!;
    final azulejosPath = paths['azulejosPath']!;
    final scenePathPtr = scenePath.toNativeUtf8();
    final azulejosPathPtr = azulejosPath.toNativeUtf8();
    final resultPtr = getBestTitle(scenePathPtr, azulejosPathPtr);
    final result = resultPtr.toDartString();
    calloc.free(scenePathPtr);
    calloc.free(azulejosPathPtr);
    return result;
  } catch (e) {
    return "ERRO DENTRO DO ISOLATE: ${e.toString()}";
  }
}

class DetectorScreen extends StatefulWidget {
  const DetectorScreen({super.key});

  @override
  State<DetectorScreen> createState() => _DetectorScreenState();
}

class _DetectorScreenState extends State<DetectorScreen> {
  String? _resultado;
  bool _isLoading = false;
  File? _imagemTirada;

  Future<void> _tirarFoto() async {
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setBool('wasOnDetectorScreen', true);

      final picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      final imageBytes = await pickedFile.readAsBytes();
      final image_lib.Image? originalImage = image_lib.decodeImage(imageBytes);

      if (originalImage == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Formato de imagem inválido.')),
          );
        }
        return;
      }

      final image_lib.Image resizedImage = image_lib.copyResize(
        originalImage,
        width: 800,
      );
      final List<int> processedImageBytes = image_lib.encodeJpg(resizedImage);
      final directory = await getApplicationDocumentsDirectory();
      final imagemDir = Directory(p.join(directory.path, 'imagem'));
      if (!await imagemDir.exists()) {
        await imagemDir.create(recursive: true);
      }
      final String caminhoDaFoto = p.join(imagemDir.path, 'foto_tirada.jpg');
      final fotoSalva = await File(
        caminhoDaFoto,
      ).writeAsBytes(processedImageBytes);

      if (mounted) {
        setState(() {
          _imagemTirada = fotoSalva;
          _resultado = null;
        });
      }
    } finally {
      await prefs.setBool('wasOnDetectorScreen', false);
    }
  }

  Future<void> _iniciarProcessamento() async {
    if (_isLoading || _imagemTirada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, tire uma foto primeiro.')),
      );
      return;
    }
    if (mounted) setState(() => _isLoading = true);
    try {
      final String scenePath = _imagemTirada!.path;
      final azulejosPath = await _copiarAzulejosParaInterno();
      final paths = {'scenePath': scenePath, 'azulejosPath': azulejosPath};
      final result = await compute(_detectarAzulejoIsolate, paths);
      if (mounted) setState(() => _resultado = result);
    } catch (e) {
      if (mounted) setState(() => _resultado = 'Erro ao processar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _copiarAzulejosParaInterno() async {
    final directory = await getApplicationDocumentsDirectory();
    final destinoDir = Directory(p.join(directory.path, 'azulejos'));
    if (!(await destinoDir.exists())) {
      await destinoDir.create(recursive: true);
    }
    final azulejos = ['azul1.jpeg', 'azul2.jpeg', 'azul3.jpeg'];
    for (final nome in azulejos) {
      final assetPath = 'assets/azulejos/$nome';
      try {
        final bytes = await rootBundle.load(assetPath);
        final file = File(p.join(destinoDir.path, nome));
        await file.writeAsBytes(bytes.buffer.asUint8List());
      } catch (e) {}
    }
    return destinoDir.path;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detector de Azulejo')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade600),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: _imagemTirada == null
                      ? const Text(
                          'Tire uma foto para começar.',
                          style: TextStyle(fontSize: 16),
                        )
                      : Image.file(_imagemTirada!, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_resultado != null)
                Text(
                  'Azulejo correspondente:\n$_resultado',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton.icon(
                    onPressed: _tirarFoto,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Tirar Foto'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _iniciarProcessamento,
                    icon: const Icon(Icons.search),
                    label: const Text('Detectar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
