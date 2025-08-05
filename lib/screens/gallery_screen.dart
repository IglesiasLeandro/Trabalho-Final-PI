// arquivo: gallery_screen.dart

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

// MUDANÇA 1: Imports adicionados
import 'dart:convert';
import 'package:flutter/services.dart';

import 'azulejo_detail_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<Azulejo> _azulejos = [];
  bool _isLoading = true;

  // MUDANÇA 2: Variável para guardar os dados do JSON
  Map<String, dynamic> _azulejoDescriptions = {};

  @override
  void initState() {
    super.initState();
    _loadAzulejos();
  }

  // MUDANÇA 3: Nova função para carregar o JSON
  Future<void> _loadDescriptions() async {
    final String response = await rootBundle.loadString(
      'assets/azulejo_details.json',
    );
    final data = await json.decode(response);
    setState(() {
      _azulejoDescriptions = data;
    });
  }

  // MUDANÇA 5: Função de detalhes substituída para buscar no Map
  String _getAzulejoDetails(String fileName) {
    return _azulejoDescriptions[fileName] ??
        _azulejoDescriptions['default'] ??
        'Descrição não encontrada.';
  }

  Future<void> _loadAzulejos() async {
    setState(() {
      _isLoading = true;
    });

    // MUDANÇA 4: Chamada para carregar as descrições ANTES
    await _loadDescriptions();

    final directory = await getApplicationDocumentsDirectory();
    final azulejosDir = Directory(p.join(directory.path, 'azulejos'));

    if (await azulejosDir.exists()) {
      final files = azulejosDir.listSync().whereType<File>().toList();
      final List<Azulejo> loadedAzulejos = [];

      for (var file in files) {
        final fileName = p.basenameWithoutExtension(file.path);
        loadedAzulejos.add(
          Azulejo(
            imageFile: file,
            name: fileName,
            description: _getAzulejoDetails(fileName), // Agora pega do JSON!
          ),
        );
      }
      setState(() {
        _azulejos = loadedAzulejos;
      });
    }
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // O seu método build não precisa de nenhuma alteração.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Azulejos'),
        backgroundColor: Colors.black.withOpacity(0.3),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _azulejos.isEmpty
          ? const Center(child: Text('Nenhum azulejo no catálogo.'))
          : GridView.builder(
              padding: const EdgeInsets.all(8.0),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 8.0,
                mainAxisSpacing: 8.0,
                childAspectRatio: 0.8,
              ),
              itemCount: _azulejos.length,
              itemBuilder: (context, index) {
                final azulejo = _azulejos[index];

                return Hero(
                  tag: azulejo.imageFile.path,
                  child: Card(
                    clipBehavior: Clip.antiAlias,
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                AzulejoDetailScreen(azulejo: azulejo),
                          ),
                        );
                      },
                      child: GridTile(
                        footer: GridTileBar(
                          backgroundColor: Colors.black45,
                          title: Text(
                            azulejo.name,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        child: Image.file(azulejo.imageFile, fit: BoxFit.cover),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
