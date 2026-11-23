import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';

class GeolocalizacaoScreen extends StatefulWidget {
  const GeolocalizacaoScreen({super.key});

  @override
  State<GeolocalizacaoScreen> createState() => _GeolocalizacaoScreenState();
}

class _GeolocalizacaoScreenState extends State<GeolocalizacaoScreen> {
  final _locationService = LocationService();

  // Referência aproximada da região de Matão / SP para cálculo de distância
  static const double _latReferenciaMatao = -21.6020;
  static const double _lngReferenciaMatao = -48.3595;

  Position? _posicaoAtual;
  bool _carregando = false;
  String? _mensagemErro;
  StreamSubscription<Position>? _positionStreamSub;
  bool _rastreando = false;

  Future<void> _buscarLocalizacao() async {
    setState(() {
      _carregando = true;
      _mensagemErro = null;
    });

    try {
      final posicao = await _locationService.obterPosicaoAtual();
      if (mounted) {
        setState(() => _posicaoAtual = posicao);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _mensagemErro = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _carregando = false);
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
        _mensagemErro = null;
        _rastreando = true;
      });
      _positionStreamSub = _locationService.monitorarPosicao().listen(
        (pos) => setState(() => _posicaoAtual = pos),
        onError: (err) => setState(() {
          _mensagemErro = err.toString().replaceFirst('Exception: ', '');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Check-in & GPS'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (_carregando) const CircularProgressIndicator(),
            if (_mensagemErro != null)
              Card(
                color: Colors.red.shade100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Text(
                    _mensagemErro!,
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
            ],
            const Spacer(),
            ElevatedButton.icon(
              onPressed: _carregando ? null : _buscarLocalizacao,
              icon: const Icon(Icons.gps_fixed),
              label: const Text('Capturar Localização Atual'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _alternarRastreamento,
              icon: Icon(_rastreando ? Icons.stop : Icons.play_arrow),
              label: Text(
                _rastreando
                    ? 'Parar Rastreamento'
                    : 'Iniciar Rastreamento Contínuo',
              ),
            ),
          ],
        ),
      ),
    );
  }
}