// lib/services/websocket_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/io.dart';
import 'package:mobile/conn_url.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connecting = false;
  static final StreamController<Map<String, dynamic>> _threatController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get threatStream => _threatController.stream;

  String get _wsUrl {
    final base = ApiUrls.baseUrl;
    if (base.startsWith('https://')) return base.replaceFirst('https://', 'wss://') + '/ws';
    if (base.startsWith('http://')) return base.replaceFirst('http://', 'ws://') + '/ws';
    return base + '/ws';
  }

  Future<void> connect() async {
    if (_channel != null || _connecting) return;
    _connecting = true;
    try {
      _channel = IOWebSocketChannel.connect(_wsUrl);
      _sub = _channel!.stream.listen((msg) {
        if (msg is String) {
          try {
            final data = jsonDecode(msg);
            if (data is Map<String, dynamic>) {
              final type = data['type']?.toString();
              final isThreat = data['threat'] == true;
              if (type == 'threat_detected' || (isThreat && data['auto_sos'] == true)) {
                _threatController.add(data);
              }
            }
          } catch (_) {
            // ignore non-json text frames
          }
        }
      }, onDone: _onDone, onError: _onError, cancelOnError: true);
    } finally {
      _connecting = false;
    }
  }

  void _onDone() {
    _disposeChannel();
    Future.delayed(const Duration(seconds: 2), () => connect());
  }

  void _onError(Object err) {
    _disposeChannel();
    Future.delayed(const Duration(seconds: 2), () => connect());
  }

  Future<void> sendAudioSamples(List<int> samples) async {
    if (_channel == null) await connect();
    final payload = jsonEncode({
      'type': 'audio',
      'data': samples,
    });
    _channel?.sink.add(payload);
  }

  Future<void> sendProximity(double value) async {
    if (_channel == null) await connect();
    final payload = jsonEncode({
      'type': 'proximity',
      'value': value,
    });
    _channel?.sink.add(payload);
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _disposeChannel();
  }

  void _disposeChannel() {
    _sub = null;
    _channel = null;
  }
}
