// services/api_service.dart — All HTTP calls to the FastAPI backend.

import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/attendance_record.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

class ApiService {
  static final _timeout = Duration(seconds: AppConfig.apiTimeoutSeconds);

  // ─────────────────────────────────────────────────────────────────
  // Authentication
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> authLogin(String name, String contactNumber) async {
    try {
      final res = await http.post(
        Uri.parse(AppConfig.authLoginUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'contact_number': contactNumber,
        }),
      ).timeout(_timeout);
      
      _checkStatus(res);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('Cannot connect to server. Check your Wi-Fi and API URL.');
    } catch (e) {
      throw ApiException('Failed to login: $e');
    }
  }

  static Future<Map<String, dynamic>> authSignup(String name, String designation, String contactNumber) async {
    try {
      final res = await http.post(
        Uri.parse(AppConfig.authSignupUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'name': name,
          'designation': designation,
          'contact_number': contactNumber,
        }),
      ).timeout(_timeout);
      
      _checkStatus(res);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('Cannot connect to server. Check your Wi-Fi and API URL.');
    } catch (e) {
      throw ApiException('Failed to signup: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Health
  // ─────────────────────────────────────────────────────────────────

  static Future<bool> isBackendReachable() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.healthUrl))
          .timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Check-In
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkIn(File imageFile) async {
    return _sendFaceImage(AppConfig.checkInUrl, imageFile);
  }

  // ─────────────────────────────────────────────────────────────────
  // Check-Out
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> checkOut(File imageFile) async {
    return _sendFaceImage(AppConfig.checkOutUrl, imageFile);
  }

  // ─────────────────────────────────────────────────────────────────
  // Recognize
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> recognize(File imageFile) async {
    return _sendFaceImage(AppConfig.recognizeUrl, imageFile);
  }

  // ─────────────────────────────────────────────────────────────────
  // Register Employee Face
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> registerEmployeeFace(
      String name, String employeeId, File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(AppConfig.registerUrl));
      request.fields['name'] = name;
      request.fields['employee_id'] = employeeId;
      request.files.add(await http.MultipartFile.fromPath(
        'images',
        imageFile.path,
        filename: 'face.jpg',
      ));

      final streamed = await request.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final detail = body['detail']?.toString() ?? 'Error ${res.statusCode}';
        throw ApiException(detail, statusCode: res.statusCode);
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException('Cannot connect to server. Check your Wi-Fi and API URL.');
    } catch (e) {
      throw ApiException('Failed to register face: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Attendance: Today
  // ─────────────────────────────────────────────────────────────────

  static Future<List<AttendanceRecord>> getTodayAttendance() async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.todayUrl))
          .timeout(_timeout);
      _checkStatus(res);
      final data = jsonDecode(res.body) as Map<String, dynamic>;
      final records = data['records'] as List<dynamic>;
      return records
          .map((r) => AttendanceRecord.fromJson(r as Map<String, dynamic>))
          .toList();
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
          'Cannot connect to server. Check your Wi-Fi and API URL.');
    } catch (e) {
      throw ApiException('Failed to load attendance: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Attendance: History
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> getAttendanceHistory(
      String employeeId) async {
    try {
      final res = await http
          .get(Uri.parse(AppConfig.historyUrl(employeeId)))
          .timeout(_timeout);
      _checkStatus(res);
      return jsonDecode(res.body) as Map<String, dynamic>;
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
          'Cannot connect to server. Check your Wi-Fi and API URL.');
    } catch (e) {
      throw ApiException('Failed to load history: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Internal helpers
  // ─────────────────────────────────────────────────────────────────

  static Future<Map<String, dynamic>> _sendFaceImage(
      String url, File imageFile) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath(
        'image',
        imageFile.path,
        filename: 'face.jpg',
      ));

      final streamed = await request.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);

      if (res.statusCode >= 200 && res.statusCode < 300) {
        return jsonDecode(res.body) as Map<String, dynamic>;
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        final detail = body['detail']?.toString() ?? 'Unknown error';
        throw ApiException(detail, statusCode: res.statusCode);
      }
    } on ApiException {
      rethrow;
    } on SocketException {
      throw const ApiException(
          'Cannot connect to server.\nMake sure you are on the same Wi-Fi network.');
    } on http.ClientException catch (e) {
      throw ApiException('Network error: ${e.message}');
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Unexpected error: $e');
    }
  }

  static void _checkStatus(http.Response res) {
    if (res.statusCode < 200 || res.statusCode >= 300) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final detail = body['detail']?.toString() ?? 'Error ${res.statusCode}';
      throw ApiException(detail, statusCode: res.statusCode);
    }
  }
}
