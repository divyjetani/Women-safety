// App/frontend/mobile/lib/services/websocket_services.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:mobile/conn_url.dart';

class WebSocketService {
  static final WebSocketService _instance = WebSocketService._internal();
  factory WebSocketService() => _instance;
  WebSocketService._internal();

  IOWebSocketChannel? _channel;
  StreamSubscription? _sub;
  bool _connecting = false;

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
      _sub = _channel!.stream.listen(
        (msg) {
          // handle text/binary responses from backend
          // print or forward to listeners
        },
        onDone: _onDone,
        onError: _onError,
        cancelOnError: true,
      );
    } finally {
      _connecting = false;
    }
  }

  void _onDone() {
    _disposeChannel();
    // optional: schedule reconnect
    Future.delayed(const Duration(seconds: 2), () => connect());
  }

  void _onError(Object err) {
    _disposeChannel();
    Future.delayed(const Duration(seconds: 2), () => connect());
  }

  Future<void> sendAudioChunk(Uint8List chunk) async {
    if (_channel == null) await connect();
    // send raw bytes — backend must accept binary frames
    _channel?.sink.add(chunk);
  }

  Future<void> close() async {
    await _sub?.cancel();
    _channel?.sink.close(status.normalClosure);
    _disposeChannel();
  }

  void _disposeChannel() {
    _sub = null;
    _channel = null;
  }
}
