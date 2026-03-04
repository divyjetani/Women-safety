// App/frontend/mobile/lib/services/bubble_websocket_service.dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:mobile/conn_url.dart';
import 'package:mobile/models/bubble_model.dart';

typedef OnLocationUpdate = Function(List<BubbleMember> members);
typedef OnBubbleInfo = Function(Bubble bubble);
typedef OnError = Function(String error);
typedef OnConnectionChanged = Function(bool connected);

class BubbleWebSocketService {
  late WebSocketChannel _channel;
  final String bubbleCode;
  final int userId;
  bool _isConnected = false;

  OnLocationUpdate? onLocationUpdate;
  OnBubbleInfo? onBubbleInfo;
  OnError? onError;
  OnConnectionChanged? onConnectionChanged;

  BubbleWebSocketService({
    required this.bubbleCode,
    required this.userId,
  });

  bool get isConnected => _isConnected;

  // ✅ connect to bubble websocket
  Future<void> connect() async {
    try {
      final baseUrl = ApiUrls.baseUrl;
      final wsUrl = baseUrl.replaceFirst('http', 'ws');
      final url = '$wsUrl/ws/bubble/$bubbleCode/$userId';

      _channel = WebSocketChannel.connect(Uri.parse(url));
      _isConnected = true;
      onConnectionChanged?.call(true);

      _channel.stream.listen(
        (message) {
          _handleMessage(message);
        },
        onError: (error) {
          _isConnected = false;
          onConnectionChanged?.call(false);
          onError?.call('WebSocket error: $error');
        },
        onDone: () {
          _isConnected = false;
          onConnectionChanged?.call(false);
        },
      );
    } catch (e) {
      _isConnected = false;
      onConnectionChanged?.call(false);
      onError?.call('Connection failed: $e');
      rethrow;
    }
  }

  // ✅ handle incoming websocket messages
  void _handleMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final type = data['type'];

      if (type == 'bubble_info') {
        final bubbleData = data['bubble'];
        final bubble = Bubble.fromJson(bubbleData);
        onBubbleInfo?.call(bubble);
      } else if (type == 'location_update') {
        final updateData = data['data'];
        final members = (updateData['members'] as List)
            .map((m) => BubbleMember.fromJson(m))
            .toList();
        onLocationUpdate?.call(members);
      } else if (type == 'pong') {
      }
    } catch (e) {
      onError?.call('Message parse error: $e');
    }
  }

  void shareLocation({
    required double lat,
    required double lng,
    required int battery,
  }) {
    if (!_isConnected) {
      onError?.call('WebSocket not connected');
      return;
    }

    try {
      _channel.sink.add(jsonEncode({
        'type': 'location_update',
        'lat': lat,
        'lng': lng,
        'battery': battery,
      }));
    } catch (e) {
      onError?.call('Failed to send location: $e');
    }
  }

  void sendPing() {
    if (!_isConnected) return;

    try {
      _channel.sink.add(jsonEncode({
        'type': 'ping',
      }));
    } catch (e) {
      onError?.call('Failed to send ping: $e');
    }
  }

  Future<void> disconnect() async {
    try {
      _isConnected = false;
      await _channel.sink.close(status.goingAway);
      onConnectionChanged?.call(false);
    } catch (e) {
      onError?.call('Disconnect error: $e');
    }
  }
}
