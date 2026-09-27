import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/holiday.dart';

class HolidaysRepository {
  static const String _cacheKey = 'holidays_cache_';
  static const String _apiUrl = 'https://apis.digital.gob.cl/fl/feriados';

  /// Obtiene los feriados de un año determinado.
  /// Primero revisa la caché (SharedPreferences), si no está o está forzado, consulta la API.
  Future<List<Holiday>> getHolidays(int year, {bool forceRefresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = '$_cacheKey$year';

    // 1. Intentar obtener de la API primero para asegurar datos actualizados
    try {
      final response = await http.get(Uri.parse('$_apiUrl/$year')).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(response.body);
        final holidays = jsonList.map((j) => Holiday.fromJson(j)).toList();

        // Guardar/Actualizar caché
        await prefs.setString(cacheKey, json.encode(holidays.map((h) => h.toJson()).toList()));
        return holidays;
      }
    } catch (e) {
      debugPrint('Error de conexión, intentando cargar desde caché: $e');
    }

    // 2. Si falló la API, intentar cargar desde caché
    if (prefs.containsKey(cacheKey)) {
      final String? cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        try {
          final List<dynamic> jsonList = json.decode(cachedData);
          return jsonList.map((j) => Holiday.fromJson(j)).toList();
        } catch (e) {
          debugPrint('Error crítico leyendo caché: $e');
        }
      }
    }

    // 3. Fallo total
    throw Exception('No es posible obtener feriados. Verifica tu conexión.');
  }
}
