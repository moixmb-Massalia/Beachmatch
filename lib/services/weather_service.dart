import 'dart:convert';
import 'package:http/http.dart' as http;

class BeachWeatherData {
  final double temperature;
  final double apparentTemperature;
  final double windSpeed;
  final double windGusts;
  final int windDirection;
  final int weatherCode;

  BeachWeatherData({
    required this.temperature,
    required this.apparentTemperature,
    required this.windSpeed,
    required this.windGusts,
    required this.windDirection,
    required this.weatherCode,
  });

  String get windDirectionLabel {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SO', 'O', 'NO'];
    final index = ((windDirection + 22.5) % 360 / 45).floor();
    return directions[index % 8];
  }

  String get weatherConditionLabel {
    if (weatherCode == 0) return "Ensoleillé ☀️";
    if (weatherCode <= 3) return "Partiellement voilé ⛅";
    if (weatherCode <= 48) return "Brume 🌫️";
    if (weatherCode <= 67) return "Pluie 🌧️";
    if (weatherCode <= 82) return "Averses 🌦️";
    return "Orageux ⛈️";
  }

  String get beachConditionText {
    if (windSpeed < 15) return "Conditions idéales 🏖️";
    if (windSpeed <= 28) return "Vent modéré 🌬️";
    return "Fortes rafales ⚠️";
  }

  bool get isIdeal => windSpeed < 15;
  bool get isPlayable => windSpeed <= 28;
}

class WeatherService {
  static final Map<String, BeachWeatherData> _cache = {};
  static final Map<String, DateTime> _cacheTime = {};

  static Future<BeachWeatherData?> getWeather(double latitude, double longitude) async {
    final key = "${latitude.toStringAsFixed(2)}_${longitude.toStringAsFixed(2)}";

    // Cache de 15 minutes
    if (_cache.containsKey(key) && _cacheTime.containsKey(key)) {
      final diff = DateTime.now().difference(_cacheTime[key]!);
      if (diff.inMinutes < 15) {
        return _cache[key];
      }
    }

    try {
      final url = Uri.parse(
        "https://api.open-meteo.com/v1/forecast?latitude=$latitude&longitude=$longitude&current=temperature_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m&timezone=auto",
      );

      final response = await http.get(url).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final current = data['current'] as Map<String, dynamic>;

        final weather = BeachWeatherData(
          temperature: (current['temperature_2m'] as num?)?.toDouble() ?? 22.0,
          apparentTemperature: (current['apparent_temperature'] as num?)?.toDouble() ?? 22.0,
          windSpeed: (current['wind_speed_10m'] as num?)?.toDouble() ?? 10.0,
          windGusts: (current['wind_gusts_10m'] as num?)?.toDouble() ?? 15.0,
          windDirection: (current['wind_direction_10m'] as num?)?.toInt() ?? 0,
          weatherCode: (current['weather_code'] as num?)?.toInt() ?? 0,
        );

        _cache[key] = weather;
        _cacheTime[key] = DateTime.now();
        return weather;
      }
    } catch (_) {
      // Ignorer l'erreur et retourner null sans planter
    }
    return null;
  }
}
