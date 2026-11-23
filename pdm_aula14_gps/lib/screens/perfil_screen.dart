import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/media_service.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  static const String _chaveFotoPerfil = 'caminho_foto_perfil';

  final _mediaService = MediaService();
  final _nomeController = TextEditingController(text: 'Diego Menegassi');
  File? _imagemPerfil;

  @override
  void initState() {
    super.initState();
    _carregarFotoSalva();
  }

  Future<void> _carregarFotoSalva() async {
    final prefs = await SharedPreferences.getInstance();
    final caminho = prefs.getString(_chaveFotoPerfil);
    if (caminho != null && caminho.isNotEmpty) {
      final arquivo = File(caminho);
      if (await arquivo.exists() && mounted) {
        setState(() => _imagemPerfil = arquivo);
      }
    }
  }

  Future<void> _salvarCaminhoFoto(String? caminho) async {
    final prefs = await SharedPreferences.getInstance();
    if (caminho == null) {
      await prefs.remove(_chaveFotoPerfil);
    } else {
      await prefs.setString(_chaveFotoPerfil, caminho);
    }
  }

  Future<void> _capturarImagem(bool daCamera) async {
    Navigator.pop(context);
    final File? imagem = daCamera
        ? await _mediaService.tirarFoto()
        : await _mediaService.selecionarDaGaleria();

    if (imagem != null && mounted) {
      setState(() => _imagemPerfil = imagem);
      await _salvarCaminhoFoto(imagem.path);
    }
  }

  Future<void> _removerFoto() async {
    Navigator.pop(context);
    setState(() => _imagemPerfil = null);
    await _salvarCaminhoFoto(null);
  }

  void _abrirTelaCheia() {
    final foto = _imagemPerfil;
    if (foto == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: const Text('Foto de Perfil'),
          ),
          body: Center(
            child: Hero(
              tag: 'foto_perfil_hero',
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: Image.file(foto),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _exibirOpcoesMidia() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.pink),
                title: const Text('Tirar Foto com a Câmera'),
                onTap: () => _capturarImagem(true),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.pink),
                title: const Text('Escolher da Galeria'),
                onTap: () => _capturarImagem(false),
              ),
              if (_imagemPerfil != null)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Remover Foto'),
                  onTap: _removerFoto,
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final temFoto = _imagemPerfil != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil do Usuário'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  GestureDetector(
                    onTap: temFoto ? _abrirTelaCheia : _exibirOpcoesMidia,
                    child: Hero(
                      tag: 'foto_perfil_hero',
                      child: CircleAvatar(
                        radius: 70,
                        backgroundColor: Colors.pink.shade100,
                        backgroundImage:
                            temFoto ? FileImage(_imagemPerfil!) : null,
                        child: !temFoto
                            ? const Icon(
                                Icons.person,
                                size: 70,
                                color: Colors.pink,
                              )
                            : null,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: FloatingActionButton.small(
                      onPressed: _exibirOpcoesMidia,
                      child: const Icon(Icons.camera_alt),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome Completo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
          ],
        ),
      ),
    );
  }
}