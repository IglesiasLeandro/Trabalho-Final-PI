// arquivo: azulejo_detail_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Classe para organizar os dados do azulejo
class Azulejo {
  final File imageFile;
  final String name;
  final String description;

  Azulejo({
    required this.imageFile,
    required this.name,
    required this.description,
  });
}

Future<Azulejo?> carregarAzulejoPorNome(String nomeDoArquivo) async {
  try {
    // 1. Carrega o JSON com as descrições
    final String response = await rootBundle.loadString(
      'assets/azulejo_details.json',
    );
    final Map<String, dynamic> descriptions = json.decode(response);

    // 2. Pega a descrição específica para este arquivo
    final nomeSemExtensao = p.basenameWithoutExtension(nomeDoArquivo);
    final String? description =
        descriptions[nomeSemExtensao] ?? descriptions['default'];

    if (description == null) {
      print('ERRO: Descrição não encontrada para $nomeSemExtensao no JSON.');
      return null;
    }

    // 3. Encontra o arquivo da imagem no armazenamento interno
    final directory = await getApplicationDocumentsDirectory();
    final imagePath = p.join(directory.path, 'azulejos', nomeDoArquivo);
    final imageFile = File(imagePath);

    if (!await imageFile.exists()) {
      print('ERRO: Arquivo de imagem não encontrado em $imagePath');
      return null;
    }

    // 4. Cria e retorna o objeto Azulejo completo
    return Azulejo(
      imageFile: imageFile,
      name: nomeSemExtensao,
      description: description,
    );
  } catch (e) {
    print('Ocorreu um erro ao carregar o azulejo $nomeDoArquivo: $e');
    return null;
  }
}

class AzulejoDetailScreen extends StatelessWidget {
  final Azulejo azulejo;

  const AzulejoDetailScreen({super.key, required this.azulejo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fundo escuro para destacar a imagem
      appBar: AppBar(
        title: Text(azulejo.name),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          // Permite rolar se o conteúdo for grande
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // O Hero widget que corresponde ao da tela anterior
              Hero(
                tag: azulejo.imageFile.path, // A tag DEVE ser a mesma
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.0),
                  child: Image.file(azulejo.imageFile),
                ),
              ),
              const SizedBox(height: 24),
              // Seção de texto com as características
              Text(
                'Características',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                azulejo.description,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                  height: 1.5, // Espaçamento entre linhas
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
