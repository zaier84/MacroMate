import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:onboarding/services/api_service.dart';
import 'progress_models.dart';

class ProgressController extends ChangeNotifier {
  final ApiService _api = ApiService();

  bool loading = true;
  String? error;
  ProgressResponse? data;

  DateTime _selectedMonth = DateTime.now();

  DateTime get selectedMonth => _selectedMonth;

  bool get isCurrentMonth {
    final now = DateTime.now();
    return _selectedMonth.year == now.year && _selectedMonth.month == now.month;
  }

  String get monthQuery =>
      "${_selectedMonth.year}-${_selectedMonth.month.toString().padLeft(2, '0')}";


  Future<void> load() async {
    loading = true;
    error = null;
    notifyListeners();

    try {
      final resp = await _api.get('/api/progress/monthly?month=$monthQuery');

      final json = jsonDecode(resp.body);
      data = ProgressResponse.fromJson(json);
    } catch (e) {
      error = 'Unable to fetch progress';
    }

    loading = false;
    notifyListeners();
  }

  void previousMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    load();
  }

  void nextMonth() {
    _selectedMonth = DateTime(_selectedMonth.year, _selectedMonth.month + 1);
    load();
  }
}
