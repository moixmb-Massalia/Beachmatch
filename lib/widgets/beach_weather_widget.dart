import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/weather_service.dart';
import '../theme/colors.dart';

class BeachWeatherWidget extends StatelessWidget {
  final double latitude;
  final double longitude;
  final bool compact;

  const BeachWeatherWidget({
    super.key,
    required this.latitude,
    required this.longitude,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<BeachWeatherData?>(
      future: WeatherService.getWeather(latitude, longitude),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(color: Colors.white70, strokeWidth: 1.8),
                ),
                SizedBox(width: 8),
                Text("Météo du sable...", style: TextStyle(color: Colors.white60, fontSize: 11)),
              ],
            ),
          );
        }

        final weather = snapshot.data;
        if (weather == null) return const SizedBox.shrink();

        final windColor = weather.isIdeal
            ? const Color(0xFF10B981) // Vert émeraude
            : (weather.isPlayable
                ? const Color(0xFFF59E0B) // Orange
                : const Color(0xFFEF4444)); // Rouge

        if (compact) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "${weather.temperature.round()}°C",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: windColor.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: windColor.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.air_rounded, size: 12, color: windColor),
                      const SizedBox(width: 3),
                      Text(
                        "${weather.windSpeed.round()} km/h",
                        style: TextStyle(color: windColor, fontWeight: FontWeight.bold, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  // Icône & Température
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.wb_sunny_rounded, color: AppColors.gold, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              "${weather.temperature.round()}°C",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 18,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              weather.sandComfortText,
                              style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          weather.beachConditionText,
                          style: TextStyle(
                            color: windColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Pastille Vent
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: windColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: windColor.withOpacity(0.6)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Icon(Icons.air_rounded, size: 14, color: windColor),
                            const SizedBox(width: 4),
                            Text(
                              "${weather.windSpeed.round()} km/h",
                              style: TextStyle(
                                color: windColor,
                                fontWeight: FontWeight.w900,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          weather.windDirectionLabel,
                          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
