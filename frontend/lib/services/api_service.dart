import 'package:http/http.dart' as http;
import 'auth_service.dart';

class ApiService {
  // final String backendBase = "http://localhost:8000";
  // Use 10.0.2.2 when running on Android emulator and backend on host machine.
  // On a real device or web, set an appropriate backend URL.
  final String backendBase = "http://10.0.2.2:8000"; // Host machine
  final AuthService _authService = AuthService();

  Future<Map<String, String>> _defaultHeaders() async {
    final idToken = await _authService.getCurrentIdToken(forceRefresh: false);

    if (idToken == null) {
      throw Exception("Not authenticated");
    }

    return {
      "Authorization": "Bearer $idToken",
      // "Content-Type": "application/json",
      "Accept": "application/json",
    };
  }

  Uri _buildUri(String path) {
    if (!path.startsWith("/")) path = "/$path";
    return Uri.parse("$backendBase$path");
  }

  Future<http.Response> get(String path) async {
    final headers = await _defaultHeaders();
    final url = _buildUri(path);
    // return await http.get(url, headers: headers);
    return await http.get(
      url,
      headers: {...headers, "Content-Type": "application/json"},
    );
  }

  Future<http.Response> post(String path, String body) async {
    final headers = await _defaultHeaders();
    final url = _buildUri(path);
    // return await http.post(url, headers: headers, body: body);
    return await http.post(
      url,
      headers: {...headers, "Content-Type": "application/json"},
      body: body,
    );
  }

  Future<http.StreamedResponse> postMultipart(
    String path, {
    required Map<String, String> fields,
    List<http.MultipartFile>? files,
  }) async {
    final headers = await _defaultHeaders();
    final url = _buildUri(path);

    final request = http.MultipartRequest("POST", url);

    // Add auth headers (DO NOT set content-type manually)
    request.headers.addAll(headers);

    // Add form fields
    request.fields.addAll(fields);

    // Add files if any
    if (files != null && files.isNotEmpty) {
      request.files.addAll(files);
    }

    return await request.send();
  }
}
