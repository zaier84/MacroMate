import 'dart:convert';
import 'package:onboarding/screens/home/home_response.dart';
import 'package:onboarding/services/api_service.dart';

class HomeController {
  final ApiService _apiService = ApiService();

  Future<HomeResponse> fetchHome() async {
    final response = await _apiService.get("/api/dashboard/home");

    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      return HomeResponse.fromJson(data);
    } else {
      throw Exception("Failed to load home dashboard (${response.statusCode})");
    }
  }
}
