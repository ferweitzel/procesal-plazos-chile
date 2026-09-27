import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';

class HistoryRepository {
  static const String _key = 'calculation_history';

  Future<void> saveRecord(CalculationRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    
    // Inserta al inicio
    history.insert(0, json.encode(record.toMap()));
    
    // Mantiene hasta 100 registros
    if (history.length > 100) {
      history.removeLast();
    }
    
    await prefs.setStringList(_key, history);
  }

  Future<List<CalculationRecord>> getHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    
    return history.map((jsonStr) {
      try {
        return CalculationRecord.fromMap(json.decode(jsonStr));
      } catch (e) {
        return null;
      }
    }).whereType<CalculationRecord>().toList();
  }

  Future<void> deleteRecord(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> history = prefs.getStringList(_key) ?? [];
    
    history.removeWhere((item) {
      try {
        final map = json.decode(item);
        return map['id'] == id;
      } catch (_) {
        return false;
      }
    });
    
    await prefs.setStringList(_key, history);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
