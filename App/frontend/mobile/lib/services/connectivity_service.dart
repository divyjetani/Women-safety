// App/frontend/mobile/lib/services/connectivity_service.dart
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final Connectivity _connectivity = Connectivity();

  static Future<bool> isConnected() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  static Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(
          (result) => result != ConnectivityResult.none,
    );
  }
}