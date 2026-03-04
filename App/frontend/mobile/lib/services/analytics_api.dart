// App/frontend/mobile/lib/services/analytics_api.dart
import 'package:dio/dio.dart';
import 'package:mobile/models/analytics_models.dart';

class AnalyticsApi {
  final Dio dio;

  AnalyticsApi(this.dio);

  Future<AnalyticsResponse> fetchAnalytics() async {
    final res = await dio.get('/analytics/overview');
    return AnalyticsResponse.fromJson(res.data);
  }

  Future<StatCardData> fetchStatDetail(String id) async {
    final res = await dio.get('/analytics/stats/$id');
    return StatCardData.fromJson(res.data);
  }
}
