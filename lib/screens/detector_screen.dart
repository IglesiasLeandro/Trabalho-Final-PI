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
import 'package:logger/logger.dart';
import 'azulejo_detail_screen.dart';

String _detectarAzulejoIsolate(Map<String, String> paths) {
  // Logs dentro de um isolate podem não aparecer no console de debug padrão,
  // mas o try/catch nos ajuda a ver erros.
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

final logger = Logger();

class DetectorScreen extends StatefulWidget {
  const DetectorScreen({super.key});

  @override
  State<DetectorScreen> createState() => _DetectorScreenState();
}

class _DetectorScreenState extends State<DetectorScreen> {
  String? _resultado;
  bool _isLoading = false;
  File? _imagemTirada;
  bool _isProcessandoFoto = false;

  @override
  void initState() {
    super.initState();
    print("[DEBUG] initState: Tela de detecção iniciada.");
    _restaurarImagem();
  }

  Future<void> _restaurarImagem() async {
    print(
      "[DEBUG] _restaurarImagem: Verificando se há imagem para restaurar...",
    );
    setState(() => _isProcessandoFoto = true);
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('lastImagePath');

    if (path != null) {
      print("[DEBUG] _restaurarImagem: Caminho encontrado: $path");
      final imagemSalva = File(path);
      if (await imagemSalva.exists()) {
        if (mounted) {
          setState(() => _imagemTirada = imagemSalva);
          print(
            "[DEBUG] _restaurarImagem: Imagem restaurada com sucesso na tela.",
          );
        }
      } else {
        print(
          "[DEBUG] _restaurarImagem: ERRO: Arquivo no caminho salvo não foi encontrado.",
        );
      }
      await prefs.remove('lastImagePath');
    } else {
      print(
        "[DEBUG] _restaurarImagem: Nenhum caminho de imagem para restaurar.",
      );
    }

    if (mounted) setState(() => _isProcessandoFoto = false);
    print("[DEBUG] _restaurarImagem: Verificação concluída.");
  }

  Future<void> _tirarFoto() async {
    logger.d("[DEBUG] _tirarFoto: Botão 'Tirar Foto' pressionado.");
    final prefs = await SharedPreferences.getInstance();
    try {
      await prefs.setBool('wasOnDetectorScreen', true);
      print("[DEBUG] _tirarFoto: Flag 'wasOnDetectorScreen' salva como TRUE.");

      final picker = ImagePicker();
      print("[DEBUG] _tirarFoto: Abrindo a câmera...");
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );

      if (pickedFile == null) {
        print("[DEBUG] _tirarFoto: Usuário cancelou a câmera.");
        return;
      }

      print(
        "[DEBUG] _tirarFoto: Foto capturada. Caminho temporário: ${pickedFile.path}",
      );

      if (mounted)
        setState(() {
          print(
            "[DEBUG] _tirarFoto: Iniciando processamento visual (indicador de carregamento).",
          );
          _isProcessandoFoto = true;
          _imagemTirada = null;
          _resultado = null;
        });

      print(
        "[DEBUG] _tirarFoto: Lendo, decodificando e redimensionando a imagem...",
      );
      final imageBytes = await pickedFile.readAsBytes();
      final image_lib.Image? originalImage = image_lib.decodeImage(imageBytes);

      if (originalImage == null) {
        print("[DEBUG] _tirarFoto: ERRO: Falha ao decodificar a imagem.");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erro: Formato de imagem inválido.')),
          );
          setState(() => _isProcessandoFoto = false);
        }
        return;
      }

      final image_lib.Image resizedImage = image_lib.copyResize(
        originalImage,
        width: 640,
      );
      final List<int> processedImageBytes = image_lib.encodeJpg(resizedImage);

      print(
        "[DEBUG] _tirarFoto: Imagem processada. Salvando no diretório do app...",
      );
      final directory = await getApplicationDocumentsDirectory();
      final imagemDir = Directory(p.join(directory.path, 'imagem'));
      if (!await imagemDir.exists()) {
        await imagemDir.create(recursive: true);
      }
      final String caminhoDaFoto = p.join(imagemDir.path, 'foto_tirada.jpg');
      final fotoSalva = await File(
        caminhoDaFoto,
      ).writeAsBytes(processedImageBytes);

      print(
        "[DEBUG] _tirarFoto: Imagem salva em: ${fotoSalva.path}. Salvando caminho para restauração...",
      );
      await prefs.setString('lastImagePath', fotoSalva.path);

      if (mounted)
        setState(() {
          print(
            "[DEBUG] _tirarFoto: Atualizando a tela para exibir a imagem final.",
          );
          _imagemTirada = fotoSalva;
          _isProcessandoFoto = false;
        });
    } finally {
      await prefs.setBool('wasOnDetectorScreen', false);
      print(
        "[DEBUG] _tirarFoto: Bloco 'finally' executado. Flag 'wasOnDetectorScreen' salva como FALSE.",
      );
    }
  }

  Future<void> _iniciarProcessamento() async {
    print("[DEBUG] _iniciarProcessamento: Botão 'Detectar' pressionado.");
    if (_isLoading || _imagemTirada == null) {
      print(
        "[DEBUG] _iniciarProcessamento: Abortado. Nenhuma imagem para processar.",
      );
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

      print(
        "[DEBUG] _iniciarProcessamento: Enviando caminhos para o Isolate C++: $paths",
      );
      final result = await compute(_detectarAzulejoIsolate, paths);
      print(
        "[DEBUG] _iniciarProcessamento: Resultado recebido do C++: '$result'",
      );

      if (mounted) setState(() => _resultado = result);
    } catch (e) {
      print("[DEBUG] _iniciarProcessamento: ERRO durante o processamento: $e");
      if (mounted) setState(() => _resultado = 'Erro ao processar: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<String> _copiarAzulejosParaInterno() async {
    print(
      '--- Iniciando verificação e cópia de azulejos para o armazenamento interno ---',
    );

    final directory = await getApplicationDocumentsDirectory();
    final destinoDir = Directory(p.join(directory.path, 'azulejos'));
    if (!(await destinoDir.exists())) {
      await destinoDir.create(recursive: true);
      print('[INFO]: Pasta "azulejos" não existia e foi criada.');
    }

    // 1. NOMES CORRIGIDOS PARA MINÚSCULAS, CONFORME SOLICITADO
    final azulejos = [
      'azul1.jpeg',
      'azul2.jpeg',
      'azul3.jpeg',
      'azulejo01.png',
      'azulejo02.png',
      'azulejo03.png',
      'azulejo04.png',
      'azulejo05.png',
    ];

    for (final nome in azulejos) {
      final assetPath = 'assets/azulejos/$nome';
      final file = File(p.join(destinoDir.path, nome));

      // 2. PRINTS ADICIONADOS PARA VERIFICAÇÃO
      if (!await file.exists()) {
        // Se o arquivo não existe, ele será copiado
        print('[COPIANDO]: $nome...');
        try {
          final bytes = await rootBundle.load(assetPath);
          await file.writeAsBytes(bytes.buffer.asUint8List());
        } catch (e) {
          print(
            '[ERRO]: Falha ao copiar o arquivo $nome. Verifique se ele existe em "assets/azulejos/".',
          );
        }
      } else {
        // Se o arquivo já existe, a cópia será pulada
        print('[JÁ EXISTE]: $nome (não será copiado novamente).');
      }
    }

    print('--- Verificação e cópia de azulejos concluída. ---');
    return destinoDir.path;
  }

  @override
  Widget build(BuildContext context) {
    print(
      "[DEBUG] build: Tela sendo reconstruída. _isProcessandoFoto: $_isProcessandoFoto, _imagemTirada: ${_imagemTirada != null}",
    );
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
                  child: _buildImageDisplay(),
                ),
              ),
              const SizedBox(height: 20),
              if (_isLoading)
                const CircularProgressIndicator()
              else if (_resultado != null && _resultado!.isNotEmpty)
                InkWell(
                  onTap: () async {
                    // Ação de clique: carrega os dados e navega
                    print('Clicou no resultado: $_resultado');

                    // Usa a nossa nova função para buscar os dados completos do azulejo
                    final Azulejo? azulejoDetectado =
                        await carregarAzulejoPorNome(_resultado!);

                    // Se encontrou os dados e a tela ainda existe, navega
                    if (azulejoDetectado != null && mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              AzulejoDetailScreen(azulejo: azulejoDetectado),
                        ),
                      );
                    } else if (mounted) {
                      // Mostra um erro se não conseguir carregar os detalhes
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Erro: Não foi possível carregar os detalhes do azulejo.',
                          ),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 20,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Azulejo correspondente:',
                          style: Theme.of(context).textTheme.bodyLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          // Mostra o nome do azulejo sem a extensão (.png)
                          p.basenameWithoutExtension(_resultado!),
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: Colors.blue,
                                fontWeight: FontWeight.bold,
                              ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '(Clique para ver detalhes)',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
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

  Widget _buildImageDisplay() {
    if (_isProcessandoFoto) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text("Processando imagem..."),
        ],
      );
    } else if (_imagemTirada != null) {
      return Image.file(_imagemTirada!, fit: BoxFit.contain);
    } else {
      return const Text(
        'Tire uma foto para começar.',
        style: TextStyle(fontSize: 16),
      );
    }
  }
}
