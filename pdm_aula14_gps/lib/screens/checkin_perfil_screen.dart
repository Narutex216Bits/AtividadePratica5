import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../services/media_service.dart';

class CheckinPerfilScreen extends StatefulWidget {
  const CheckinPerfilScreen({super.key});

  @override
  State<CheckinPerfilScreen> createState() => _CheckinPerfilScreenState();
}

class _CheckinPerfilScreenState extends State<CheckinPerfilScreen> {
  static const String _chaveFotoPerfil = 'caminho_foto_perfil';
  static const double _latReferenciaMatao = -21.6020;
  static const double _lngReferenciaMatao = -48.3595;

  final _mediaService = MediaService();
  final _locationService = LocationService();
  final _nomeController = TextEditingController(text: 'Diego Menegassi');

  File? _imagemPerfil;

  Position? _posicaoAtual;
  bool _carregandoGps = false;
  String? _mensagemErroGps;
  StreamSubscription<Position>? _positionStreamSub;
  bool _rastreando = false;

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
                leading: const Icon(Icons.camera_alt, color: Colors.teal),
                title: const Text('Tirar Foto com a Câmera'),
                onTap: () => _capturarImagem(true),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library, color: Colors.teal),
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

  Future<void> _buscarLocalizacao() async {
    setState(() {
      _carregandoGps = true;
      _mensagemErroGps = null;
    });

    try {
      final posicao = await _locationService.obterPosicaoAtual();
      if (mounted) {
        setState(() => _posicaoAtual = posicao);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensagemErroGps = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _carregandoGps = false);
      }
    }
  }

  void _alternarRastreamento() {
    if (_rastreando) {
      _positionStreamSub?.cancel();
      _positionStreamSub = null;
      setState(() => _rastreando = false);
    } else {
      setState(() {
        _mensagemErroGps = null;
        _rastreando = true;
      });
      _positionStreamSub = _locationService.monitorarPosicao().listen(
        (pos) => setState(() => _posicaoAtual = pos),
        onError: (err) => setState(() {
          _mensagemErroGps = err.toString().replaceFirst('Exception: ', '');
          _rastreando = false;
        }),
      );
    }
  }

  Future<void> _abrirNoMapa() async {
    final pos = _posicaoAtual;
    if (pos == null) return;

    final uri = Uri.parse(
      'https://maps.google.com/?q=${pos.latitude},${pos.longitude}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível abrir o mapa.')),
        );
      }
    }
  }

  Widget _buildChipPrecisao(double precisao) {
    Color corFundo;
    Color corTexto;
    String rotulo;

    if (precisao < 15) {
      corFundo = Colors.green.shade100;
      corTexto = Colors.green.shade900;
      rotulo = 'Alta precisão (${precisao.toStringAsFixed(1)}m)';
    } else if (precisao <= 50) {
      corFundo = Colors.amber.shade100;
      corTexto = Colors.amber.shade900;
      rotulo = 'Precisão média (${precisao.toStringAsFixed(1)}m)';
    } else {
      corFundo = Colors.red.shade100;
      corTexto = Colors.red.shade900;
      rotulo = 'Baixa precisão (${precisao.toStringAsFixed(1)}m)';
    }

    return Chip(
      backgroundColor: corFundo,
      label: Text(
        rotulo,
        style: TextStyle(color: corTexto, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  void dispose() {
    _positionStreamSub?.cancel();
    _nomeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final temFoto = _imagemPerfil != null;
    final pos = _posicaoAtual;
    final distanciaMetros = pos != null
        ? _locationService.calcularDistanciaEmMetros(
            latOrigem: pos.latitude,
            lngOrigem: pos.longitude,
            latDestino: _latReferenciaMatao,
            lngDestino: _lngReferenciaMatao,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Check-in, GPS & Perfil'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
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
                        radius: 64,
                        backgroundColor: Colors.teal.shade100,
                        backgroundImage:
                            temFoto ? FileImage(_imagemPerfil!) : null,
                        child: !temFoto
                            ? const Icon(
                                Icons.person,
                                size: 64,
                                color: Colors.teal,
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
            const SizedBox(height: 20),
            TextField(
              controller: _nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome Completo',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const Divider(height: 32),
            if (_carregandoGps) const CircularProgressIndicator(),
            if (_mensagemErroGps != null)
              Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _mensagemErroGps!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ),
            if (pos != null) ...[
              Card(
                elevation: 3,
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.my_location, color: Colors.blue),
                      title: const Text('Latitude'),
                      subtitle: Text('${pos.latitude}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.location_on, color: Colors.green),
                      title: const Text('Longitude'),
                      subtitle: Text('${pos.longitude}'),
                    ),
                    ListTile(
                      leading: const Icon(Icons.speed, color: Colors.orange),
                      title: const Text('Precisão / Altitude'),
                      subtitle: Text(
                        'Precisão: ${pos.accuracy.toStringAsFixed(1)}m | '
                        'Alt: ${pos.altitude.toStringAsFixed(1)}m',
                      ),
                    ),
                    if (distanciaMetros != null)
                      ListTile(
                        leading: const Icon(Icons.straighten, color: Colors.purple),
                        title: const Text('Distância até referência (Matão/SP)'),
                        subtitle: Text(
                          '${distanciaMetros.toStringAsFixed(1)} metros',
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: _buildChipPrecisao(pos.accuracy),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _abrirNoMapa,
                icon: const Icon(Icons.map),
                label: const Text('Abrir no Mapa'),
              ),
              const SizedBox(height: 8),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _carregandoGps ? null : _buscarLocalizacao,
                icon: const Icon(Icons.gps_fixed),
                label: const Text('Capturar Localização Atual'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _alternarRastreamento,
                icon: Icon(_rastreando ? Icons.stop : Icons.play_arrow),
                label: Text(
                  _rastreando
                      ? 'Parar Rastreamento'
                      : 'Iniciar Rastreamento Contínuo',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}