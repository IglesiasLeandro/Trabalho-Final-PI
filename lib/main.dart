import 'dart:io';
import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart'
    as p; // Usado para manipular caminhos de forma segura
import 'package:image/image.dart' as image_lib;

// Esta função agora será executada em uma thread separada para não travar a UI.
// Substitua a função existente por esta
String _detectarAzulejoIsolate(Map<String, String> paths) {
  try {
    // O código que já funcionava fica dentro de um bloco try...
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
    // Se qualquer erro acontecer (ex: a biblioteca não carregar),
    // ele será capturado e retornado como uma mensagem.
    return "ERRO DENTRO DO ISOLATE: ${e.toString()}";
  }
}

void main() {
  runApp(const CameraTestApp());
}

class CameraTestApp extends StatelessWidget {
  const CameraTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Detector de Azulejo',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const CameraTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class CameraTestScreen extends StatefulWidget {
  const CameraTestScreen({super.key});

  @override
  State<CameraTestScreen> createState() => _CameraTestScreenState();
}

class _CameraTestScreenState extends State<CameraTestScreen> {
  String? _resultado;
  bool _isLoading = false;
  File? _imagemTirada; // Guarda o arquivo da imagem que o usuário tirou

  Future<void> _tirarFoto() async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    // --- INÍCIO DA NORMALIZAÇÃO E REDIMENSIONAMENTO ---

    final imageBytes = await pickedFile.readAsBytes();
    final image_lib.Image? originalImage = image_lib.decodeImage(imageBytes);

    if (originalImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Formato de imagem inválido.')),
      );
      return;
    }

    // --- NOVA LINHA ADICIONADA ---
    // Redimensiona a imagem para uma largura máxima de 800 pixels, mantendo a proporção.
    // Isso reduz drasticamente o uso de memória no C++.
    final image_lib.Image resizedImage = image_lib.copyResize(
      originalImage,
      width: 800,
    );

    // Re-codifica a imagem JÁ REDIMENSIONADA como um JPEG padrão.
    final List<int> processedImageBytes = image_lib.encodeJpg(resizedImage);

    // --- FIM DA NORMALIZAÇÃO ---

    final directory = await getApplicationDocumentsDirectory();
    final imagemDir = Directory(p.join(directory.path, 'imagem'));
    if (!await imagemDir.exists()) {
      await imagemDir.create(recursive: true);
    }
    final String caminhoDaFoto = p.join(imagemDir.path, 'foto_tirada.jpg');
    final fotoSalva = await File(
      caminhoDaFoto,
    ).writeAsBytes(processedImageBytes);

    setState(() {
      _imagemTirada = fotoSalva;
      _resultado = null;
    });
  }

  // Função que prepara os arquivos e dispara o processamento
  // Substitua sua função _iniciarProcessamento por esta versão de TESTE
  Future<void> _iniciarProcessamento() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _resultado = null; // Limpa o resultado anterior
    });

    try {
      // --- INÍCIO DO CÓDIGO DE TESTE ---
      // Em vez de usar a foto da câmera, vamos copiar a 'scene1.jpeg' dos assets
      // para um arquivo temporário e usar o caminho dela.

      //final directory = await getApplicationDocumentsDirectory();
      // final byteData = await rootBundle.load('assets/images/scene1.jpeg');

      // // Define um caminho para a nossa imagem de teste
      // final scenePath = p.join(directory.path, 'scene_test.jpeg');

      // // Escreve os bytes da imagem do asset no novo arquivo
      // await File(scenePath).writeAsBytes(byteData.buffer.asUint8List());

      // print("--> MODO DE TESTE: Usando a imagem de asset em: $scenePath");
      // --- FIM DO CÓDIGO DE TESTE ---
      final String scenePath = _imagemTirada!.path;

      // O resto do código permanece igual, usando o 'scenePath' que acabamos de criar
      final azulejosPath = await _copiarAzulejosParaInterno();
      final paths = {'scenePath': scenePath, 'azulejosPath': azulejosPath};

      final result = await compute(_detectarAzulejoIsolate, paths);

      setState(() {
        _resultado = result;
      });
    } catch (e) {
      setState(() {
        _resultado = 'Erro ao processar: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      } catch (e) {
        // Ignora erros caso o arquivo não seja encontrado, etc.
      }
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
              // Área para mostrar a foto tirada
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: _imagemTirada == null
                      ? const Text(
                          'Nenhuma foto tirada.',
                          style: TextStyle(fontSize: 16),
                        )
                      : Image.file(_imagemTirada!),
                ),
              ),
              const SizedBox(height: 20),

              // Área para mostrar o resultado
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_resultado != null)
                Text(
                  'Azulejo correspondente:\n$_resultado',
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),

              const SizedBox(height: 20),

              // Botões de ação
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
