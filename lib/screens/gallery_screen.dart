import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  // Lista para guardar os caminhos dos arquivos de imagem dos azulejos
  List<File> _azulejoImages = [];

  @override
  void initState() {
    super.initState();
    // Carrega as imagens dos azulejos quando a tela inicia
    _loadAzulejos();
  }

  Future<void> _loadAzulejos() async {
    final directory = await getApplicationDocumentsDirectory();
    final azulejosDir = Directory(p.join(directory.path, 'azulejos'));

    if (await azulejosDir.exists()) {
      final files = azulejosDir.listSync().whereType<File>().toList();
      setState(() {
        _azulejoImages = files;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Azulejos'),
        backgroundColor: Colors.black.withOpacity(0.3),
      ),
      body: _azulejoImages.isEmpty
          ? const Center(child: Text('Nenhum azulejo no catálogo.'))
          : GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // 2 colunas
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
              ),
              itemCount: _azulejoImages.length,
              itemBuilder: (context, index) {
                final file = _azulejoImages[index];
                final fileName = p.basename(file.path);

                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: GridTile(
                    footer: GridTileBar(
                      backgroundColor: Colors.black45,
                      title: Text(fileName, textAlign: TextAlign.center),
                    ),
                    child: Image.file(file, fit: BoxFit.cover),
                  ),
                );
              },
            ),
    );
  }
}
