// App/frontend/mobile/lib/services/websocket_service.dart
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
  int? _lastUserId;
  static final StreamController<Map<String, dynamic>> _threatController =
      StreamController<Map<String, dynamic>>.broadcast();

  static Stream<Map<String, dynamic>> get threatStream => _threatController.stream;

  String _wsUrl({int? userId}) {
    final base = ApiUrls.baseUrl;
    final wsBase = base.startsWith('https://')
        ? base.replaceFirst('https://', 'wss://')
        : (base.startsWith('http://') ? base.replaceFirst('http://', 'ws://') : base);
    final query = (userId != null && userId > 0) ? '?user_id=$userId' : '';
    return '$wsBase/ws$query';
  }

  Future<void> connect([int? userId]) async {
    if (_channel != null || _connecting) return;
    _connecting = true;
    _lastUserId = userId ?? _lastUserId;
    try {
      _channel = IOWebSocketChannel.connect(_wsUrl(userId: _lastUserId));
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
          }
        }
      }, onDone: _onDone, onError: _onError, cancelOnError: true);
    } finally {
      _connecting = false;
    }
  }

  void _onDone() {
    _disposeChannel();
    Future.delayed(const Duration(seconds: 2), () => connect(_lastUserId));
  }

  void _onError(Object err) {
    _disposeChannel();
    Future.delayed(const Duration(seconds: 2), () => connect(_lastUserId));
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
    _lastUserId = null;
  }

  void _disposeChannel() {
    _sub = null;
    _channel = null;
  }
}
