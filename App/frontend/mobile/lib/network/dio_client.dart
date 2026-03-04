// App/frontend/mobile/lib/network/dio_client.dart
import 'dart:io';
import 'package:dio/dio.dart';

class DioClient {
  static Dio create({
    required String baseUrl,
  }) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        headers: {
          "Content-Type": "application/json",
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // ✅ you can add tokens here later
          // options.headers["authorization"] = "bearer token";
          handler.next(options);
        },
        onError: (error, handler) async {
          final shouldRetry = _shouldRetry(error);

          if (!shouldRetry) {
            handler.next(error);
            return;
          }

          const maxRetries = 2;
          final retryCount = (error.requestOptions.extra["retryCount"] ?? 0) as int;

          if (retryCount >= maxRetries) {
            handler.next(error);
            return;
          }

          // ✅ delay before retry (simple backoff)
          final delay = Duration(milliseconds: 600 * (retryCount + 1));
          await Future.delayed(delay);

          final newOptions = error.requestOptions;
          newOptions.extra["retryCount"] = retryCount + 1;

          try {
            final response = await dio.fetch(newOptions);
            handler.resolve(response);
          } catch (e) {
            handler.next(e as DioException);
          }
        },
      ),
    );

    return dio;
  }

  static bool _shouldRetry(DioException e) {
    // ✅ network / no internet / dns fail etc.
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return true;
    }

    if (e.error is SocketException) return true;

    // ✅ retry on server errors (5xx)
    final status = e.response?.statusCode ?? 0;
    if (status >= 500 && status <= 599) return true;

    return false;
  }
}
