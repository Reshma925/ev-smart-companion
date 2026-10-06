import 'dart:convert';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/vehicle.dart';
import '../models/vehicle_telemetry.dart';

class LearningVehicleContext {
  const LearningVehicleContext({
    required this.vehicle,
    required this.telemetry,
  });

  final Vehicle? vehicle;
  final VehicleData? telemetry;

  bool get hasData => vehicle != null || telemetry != null;

  Map<String, Object> toMap() {
    final context = <String, Object>{};
    final vehicleModel = vehicle?.model.trim();
    if (vehicleModel != null && vehicleModel.isNotEmpty) {
      context['vehicleModel'] = vehicleModel;
    }
    final data = telemetry;
    if (data != null) {
      context['batteryPercentage'] = data.battery;
      context['estimatedRangeKm'] = data.range;
      context['batteryHealth'] = data.batteryHealth;
      context['healthScore'] = data.healthScore;
      context['isCharging'] = data.isCharging;
    }
    return context;
  }
}

abstract interface class EvLearningAssistant {
  Future<String> ask(
    String question, {
    required LearningVehicleContext context,
  });
}

class FirebaseLearningAssistantService implements EvLearningAssistant {
  FirebaseLearningAssistantService({FirebaseFunctions? functions})
    : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;

  @override
  Future<String> ask(
    String question, {
    required LearningVehicleContext context,
  }) async {
    final normalizedQuestion = question.trim();
    if (normalizedQuestion.isEmpty) {
      throw const LearningAssistantException(
        'Enter a question before asking the EV assistant.',
      );
    }
    if (normalizedQuestion.length > 2000) {
      throw const LearningAssistantException(
        'Please keep your question under 2,000 characters.',
      );
    }

    try {
      debugPrint('[AI DEBUG] Request started');
      debugPrint('[AI DEBUG] Provider: Google Gemini via Firebase callable');
      debugPrint('[AI DEBUG] Callable: askEvLearningAssistant');
      debugPrint('[AI DEBUG] Request model: gemini-flash-latest');
      final callable = _functions.httpsCallable('askEvLearningAssistant');
      final contextData = context.toMap();
      final requestData = <String, Object>{
        'message': normalizedQuestion,
        'topic': 'EV learning',
        if (contextData.isNotEmpty) 'context': jsonEncode(contextData),
      };
      final request = callable.call(requestData);
      debugPrint('[AI DEBUG] Request started successfully');
      final result = await request.timeout(const Duration(seconds: 40));
      debugPrint('[AI DEBUG] HTTP status: not exposed by Firebase callable');
      debugPrint('[AI DEBUG] Response received');
      debugPrint('[AI DEBUG] Response parsing started');
      final data = result.data;
      if (data is! Map ||
          data['success'] != true ||
          data['answer'] is! String) {
        final error = const LearningAssistantException(
          'The EV assistant returned an invalid response. Please try again.',
        );
        _logError(error, httpStatus: 'not exposed by Firebase callable');
        throw error;
      }
      final answer = (data['answer'] as String).trim();
      if (answer.isEmpty) {
        final error = const LearningAssistantException(
          'The EV assistant did not return an answer. Please try again.',
        );
        _logError(error, httpStatus: 'not exposed by Firebase callable');
        throw error;
      }
      debugPrint('[AI DEBUG] Response parsing succeeded');
      return answer;
    } on LearningAssistantException {
      rethrow;
    } on FirebaseFunctionsException catch (error, stackTrace) {
      _logError(
        error,
        httpStatus:
            'not exposed by Firebase callable; Firebase code=${error.code}',
        stackTrace: stackTrace,
      );
      if (error.code == 'invalid-argument') {
        throw LearningAssistantException(
          error.message ?? 'Check your question and try again.',
        );
      }
      throw const LearningAssistantException(
        'AI assistant is temporarily unavailable. Please try again.',
      );
    } catch (error, stackTrace) {
      _logError(
        error,
        httpStatus: 'not exposed by Firebase callable',
        stackTrace: stackTrace,
      );
      throw const LearningAssistantException(
        'AI assistant is temporarily unavailable. Please try again.',
      );
    }
  }

  void _logError(
    Object error, {
    required String httpStatus,
    StackTrace? stackTrace,
  }) {
    debugPrint('[AI ERROR] Type: ${error.runtimeType}');
    debugPrint('[AI ERROR] Message: $error');
    debugPrint('[AI ERROR] HTTP status: $httpStatus');
    debugPrint('[AI ERROR] Response body: not exposed by Firebase callable');
    debugPrint('[AI ERROR] Stack trace: ${stackTrace ?? StackTrace.current}');
  }
}

class LearningAssistantException implements Exception {
  const LearningAssistantException(this.message);

  final String message;

  @override
  String toString() => message;
}
