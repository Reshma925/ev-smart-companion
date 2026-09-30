class WeatherData {
  const WeatherData({
    required this.temperatureC,
    required this.feelsLikeC,
    required this.humidityPercent,
    required this.windSpeedKmh,
    required this.visibilityMeters,
    required this.precipitationMm,
    required this.rainMm,
    required this.weatherCode,
    required this.isDay,
    required this.locationLabel,
    required this.observedAt,
  });

  final double temperatureC;
  final double feelsLikeC;
  final int humidityPercent;
  final double windSpeedKmh;
  final double? visibilityMeters;
  final double precipitationMm;
  final double rainMm;
  final int weatherCode;
  final bool isDay;
  final String locationLabel;
  final DateTime observedAt;

  factory WeatherData.fromOpenMeteo(
    Map<String, dynamic> json, {
    required String locationLabel,
  }) {
    final current = json['current'] as Map<String, dynamic>?;
    if (current == null) {
      throw const FormatException(
        'Weather API did not return current conditions.',
      );
    }

    double number(String key) {
      final value = current[key];
      if (value is num) return value.toDouble();
      throw FormatException('Weather API field "$key" is missing or invalid.');
    }

    double? optionalNumber(String key) {
      final value = current[key];
      return value is num ? value.toDouble() : null;
    }

    final rawTime = current['time'];
    final observedAt = rawTime is String
        ? DateTime.tryParse(rawTime) ?? DateTime.now()
        : DateTime.now();

    return WeatherData(
      temperatureC: number('temperature_2m'),
      feelsLikeC: number('apparent_temperature'),
      humidityPercent: number('relative_humidity_2m').round(),
      windSpeedKmh: number('wind_speed_10m'),
      visibilityMeters: optionalNumber('visibility'),
      precipitationMm: number('precipitation'),
      rainMm: number('rain'),
      weatherCode: number('weather_code').round(),
      isDay: number('is_day') == 1,
      locationLabel: locationLabel,
      observedAt: observedAt,
    );
  }

  String get condition => switch (weatherCode) {
    0 => 'Clear sky',
    1 => 'Mostly clear',
    2 => 'Partly cloudy',
    3 => 'Overcast',
    45 || 48 => 'Foggy',
    51 || 53 || 55 => 'Drizzle',
    56 || 57 => 'Freezing drizzle',
    61 || 63 || 65 => 'Rain',
    66 || 67 => 'Freezing rain',
    71 || 73 || 75 || 77 => 'Snow',
    80 || 81 || 82 => 'Rain showers',
    85 || 86 => 'Snow showers',
    95 || 96 || 99 => 'Thunderstorms',
    _ => 'Current conditions',
  };
}
