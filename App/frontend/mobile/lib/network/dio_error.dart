// App/frontend/mobile/lib/network/dio_error.dart
import 'dart:io';
import 'package:dio/dio.dart';

class DioErrorMapper {
  static String message(dynamic error) {
    if (error is DioException) {
      if (error.error is SocketException) {
        return "No internet connection. Please check your WiFi or mobile data.";
      }

      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return "Connection timeout. Server is taking too long.";
        case DioExceptionType.sendTimeout:
          return "Request timeout. Please try again.";
        case DioExceptionType.receiveTimeout:
          return "Response timeout. Please retry.";
        case DioExceptionType.connectionError:
          return "Network error. Check your internet connection.";
        case DioExceptionType.badResponse:
          final code = error.response?.statusCode;
          return "Server error ($code). Please try again.";
        case DioExceptionType.cancel:
          return "Request cancelled.";
        case DioExceptionType.badCertificate:
          return "Security error (bad certificate).";
        case DioExceptionType.unknown:
          return "Something went wrong. Please try again.";
      }
    }

    return "Unexpected error. Please retry.";
  }
}
