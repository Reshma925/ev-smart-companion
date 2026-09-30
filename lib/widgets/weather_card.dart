import 'dart:async';

import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/weather_data.dart';
import '../services/weather_service.dart';

class WeatherCard extends StatefulWidget {
  const WeatherCard({super.key, required this.service});

  final WeatherService service;

  @override
  State<WeatherCard> createState() => _WeatherCardState();
}

class _WeatherCardState extends State<WeatherCard> with WidgetsBindingObserver {
  late Future<WeatherData> _weather;
  Timer? _refreshTimer;
  WeatherLoadStage _stage = WeatherLoadStage.checkingPermission;
  bool _permanentlyDenied = false;
  bool _waitingForSettings = false;
  bool _hasLoadedWeather = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _weather = _loadWeather();
    _refreshTimer = Timer.periodic(const Duration(minutes: 20), (_) {
      if (mounted && _hasLoadedWeather) _refresh();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _waitingForSettings && mounted) {
      _waitingForSettings = false;
      _refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<WeatherData> _loadWeather() async {
    try {
      final data = await widget.service.fetchCurrentConditions(
        onStage: (stage) {
          if (mounted && _stage != stage) {
            setState(() => _stage = stage);
          }
        },
      );
      _hasLoadedWeather = true;
      _permanentlyDenied = false;
      return data;
    } catch (error) {
      if (error is WeatherPermissionException) {
        _permanentlyDenied = error.permanentlyDenied;
      }
      rethrow;
    }
  }

  void _refresh() {
    setState(() {
      _stage = WeatherLoadStage.checkingPermission;
      _weather = _loadWeather();
    });
  }

  Future<void> _openSettings() async {
    if (widget.service.isWeb) return;
    final opened = await widget.service.openAppSettings();
    if (opened && mounted) setState(() => _waitingForSettings = true);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WeatherData>(
      future: _weather,
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F3F7),
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEAF5F7), Color(0xFFF3F7F8)],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.cloud_outlined, color: AppTheme.navy),
                  const SizedBox(width: 9),
                  const Expanded(
                    child: Text(
                      'DRIVING CONDITIONS',
                      style: TextStyle(
                        color: AppTheme.mutedBlue,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Refresh weather',
                    onPressed:
                        snapshot.connectionState == ConnectionState.waiting
                        ? null
                        : _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              if (snapshot.connectionState == ConnectionState.waiting &&
                  data == null)
                _WeatherLoading(label: _weatherStageLabel(_stage))
              else if (snapshot.hasError || data == null)
                _WeatherError(
                  message: _messageForError(snapshot.error),
                  loadingStage: _stage,
                  permissionDenied:
                      snapshot.error is WeatherPermissionException,
                  permanentlyDenied: _permanentlyDenied,
                  isWeb: widget.service.isWeb,
                  onRetry: _refresh,
                  onOpenSettings: _permanentlyDenied && !widget.service.isWeb
                      ? _openSettings
                      : null,
                )
              else
                _WeatherContent(data: data),
            ],
          ),
        );
      },
    );
  }

  String _messageForError(Object? error) {
    if (error is WeatherPermissionException) {
      if (error.permanentlyDenied) {
        return error.isWeb
            ? 'Location access is blocked for this site. Allow location in your browser’s site settings, then retry.'
            : 'Location permission is disabled for this app. Open app settings and allow location to see local driving conditions.';
      }
      return 'Location permission is required to show local driving conditions.';
    }
    if (error is WeatherServiceException) return error.message;
    return 'Weather could not be loaded: $error';
  }
}

class _WeatherLoading extends StatelessWidget {
  const _WeatherLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Row(
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Text(label),
      ],
    ),
  );
}

String _weatherStageLabel(WeatherLoadStage stage) => switch (stage) {
  WeatherLoadStage.checkingPermission => 'Checking location access…',
  WeatherLoadStage.requestingPermission => 'Requesting location permission…',
  WeatherLoadStage.gettingLocation => 'Getting your location…',
  WeatherLoadStage.fetchingWeather => 'Fetching local weather…',
};

class _WeatherError extends StatelessWidget {
  const _WeatherError({
    required this.message,
    required this.loadingStage,
    required this.permissionDenied,
    required this.permanentlyDenied,
    required this.isWeb,
    required this.onRetry,
    this.onOpenSettings,
  });

  final String message;
  final WeatherLoadStage loadingStage;
  final bool permissionDenied;
  final bool permanentlyDenied;
  final bool isWeb;
  final VoidCallback onRetry;
  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (!permissionDenied) ...[
        Text(
          _stageLabel(loadingStage),
          style: const TextStyle(
            color: AppTheme.blue,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 5),
      ],
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            permissionDenied
                ? Icons.location_disabled_outlined
                : Icons.location_off_outlined,
            color: AppTheme.mutedBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: AppTheme.navy, height: 1.35),
            ),
          ),
        ],
      ),
      if (permissionDenied && permanentlyDenied && !isWeb) ...[
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings_outlined),
            label: const Text('Open Settings'),
          ),
        ),
      ] else ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRetry,
            icon: Icon(
              permissionDenied && !permanentlyDenied
                  ? Icons.location_on_outlined
                  : Icons.refresh_rounded,
            ),
            label: Text(
              permissionDenied && !permanentlyDenied
                  ? 'Grant Permission'
                  : 'Retry',
            ),
          ),
        ),
      ],
    ],
  );

  String _stageLabel(WeatherLoadStage stage) => switch (stage) {
    WeatherLoadStage.checkingPermission => 'Checking location access…',
    WeatherLoadStage.requestingPermission => 'Requesting location permission…',
    WeatherLoadStage.gettingLocation => 'Getting your location…',
    WeatherLoadStage.fetchingWeather => 'Fetching local weather…',
  };
}

class _WeatherContent extends StatelessWidget {
  const _WeatherContent({required this.data});

  final WeatherData data;

  @override
  Widget build(BuildContext context) {
    final icon = switch (data.weatherCode) {
      0 ||
      1 => data.isDay ? Icons.wb_sunny_outlined : Icons.nights_stay_outlined,
      2 || 3 || 45 || 48 => Icons.cloud_outlined,
      51 ||
      53 ||
      55 ||
      56 ||
      57 ||
      61 ||
      63 ||
      65 ||
      66 ||
      67 ||
      80 ||
      81 ||
      82 => Icons.water_drop_outlined,
      71 || 73 || 75 || 77 || 85 || 86 => Icons.ac_unit,
      95 || 96 || 99 => Icons.thunderstorm_outlined,
      _ => Icons.wb_cloudy_outlined,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(icon, size: 43, color: AppTheme.blue),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.temperatureC.round()}°C · ${data.condition}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navy,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Feels like ${data.feelsLikeC.round()}° · ${data.locationLabel}',
                    style: const TextStyle(color: AppTheme.mutedBlue),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 18,
          runSpacing: 10,
          children: [
            _WeatherMetric(
              icon: Icons.water_drop_outlined,
              label: 'Humidity ${data.humidityPercent}%',
            ),
            _WeatherMetric(
              icon: Icons.air_rounded,
              label: 'Wind ${data.windSpeedKmh.round()} km/h',
            ),
            _WeatherMetric(
              icon: Icons.umbrella_outlined,
              label: data.rainMm > 0
                  ? 'Rain ${data.rainMm.toStringAsFixed(1)} mm'
                  : 'Precip. ${data.precipitationMm.toStringAsFixed(1)} mm',
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Updated ${TimeOfDay.fromDateTime(data.observedAt).format(context)} · Open-Meteo',
          style: const TextStyle(fontSize: 11, color: AppTheme.mutedBlue),
        ),
      ],
    );
  }
}

class _WeatherMetric extends StatelessWidget {
  const _WeatherMetric({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 16, color: AppTheme.mutedBlue),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.navy)),
    ],
  );
}
