import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/vehicle.dart';
import 'package:flutter_application_2/models/vehicle_telemetry.dart';
import 'package:flutter_application_2/screens/learn_screen.dart';
import 'package:flutter_application_2/services/learning_assistant_service.dart';

class _FakeAssistant implements EvLearningAssistant {
  _FakeAssistant({this.answer = 'EVs use electric motors.', this.failure});

  final String answer;
  final Object? failure;
  final List<String> questions = [];
  final List<LearningVehicleContext> contexts = [];

  @override
  Future<String> ask(
    String question, {
    required LearningVehicleContext context,
  }) async {
    questions.add(question);
    contexts.add(context);
    if (failure != null) throw failure!;
    return answer;
  }
}

class _PendingAssistant implements EvLearningAssistant {
  final Completer<String> response = Completer<String>();

  @override
  Future<String> ask(
    String question, {
    required LearningVehicleContext context,
  }) {
    return response.future;
  }
}

const _vehicle = Vehicle(
  id: 'EV001',
  model: 'EV Smart X1',
  registrationNumber: 'REG-001',
  ownerName: 'Driver',
  vin: 'VIN-001',
  maximumRangeKm: 300,
);

const _telemetry = VehicleData(
  battery: 54,
  range: 153,
  batteryHealth: 96,
  healthScore: 90,
  isCharging: false,
);

Widget _learnApp({
  required EvLearningAssistant assistant,
  Vehicle? vehicle = _vehicle,
  VehicleData? telemetry = _telemetry,
}) {
  return MaterialApp(
    home: LearnScreen(
      vehicleStream: Stream.value(vehicle),
      telemetryStreamFor: (_) => Stream.value(telemetry),
      assistant: assistant,
    ),
  );
}

Future<void> _scrollToText(WidgetTester tester, String text) async {
  final target = find.text(text);
  for (var attempt = 0; attempt < 8; attempt++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.dragFrom(const Offset(400, 540), const Offset(0, -420));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll to "$text".');
}

void main() {
  testWidgets('dashboard shows all six learning categories and vehicle data', (
    tester,
  ) async {
    final assistant = _FakeAssistant();
    await tester.pumpWidget(_learnApp(assistant: assistant));
    await tester.pumpAndSettle();

    for (final category in const [
      'EV BASICS',
      'BATTERY & RANGE',
      'CHARGING',
      'SMART DRIVING',
      'VEHICLE HEALTH',
      'EV & ENVIRONMENT',
    ]) {
      await _scrollToText(tester, category);
      expect(find.text(category), findsOneWidget);
    }
    expect(find.text('54% · 153 km estimated'), findsOneWidget);
    expect(find.text('ASK YOUR EV ASSISTANT'), findsOneWidget);
  });

  testWidgets('category navigation opens a lesson and marks completion', (
    tester,
  ) async {
    await tester.pumpWidget(_learnApp(assistant: _FakeAssistant()));
    await tester.pumpAndSettle();
    await _scrollToText(tester, 'EV BASICS');
    await tester.tap(find.text('EV BASICS'));
    await tester.pumpAndSettle();

    expect(find.text('How an EV works'), findsOneWidget);
    await tester.tap(find.text('How an EV works'));
    await tester.pumpAndSettle();
    expect(
      find.text('The electric motor converts electrical energy'),
      findsNothing,
    );
    expect(
      find.textContaining('An electric vehicle turns stored electrical energy'),
      findsOneWidget,
    );
    await _scrollToText(tester, 'Mark as complete');
    await tester.tap(find.text('Mark as complete'));
    await tester.pumpAndSettle();
    expect(find.text('Lesson completed'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    expect(find.text('1/8 lessons complete'), findsOneWidget);
    await tester.tap(find.text('EV BASICS'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
  });

  testWidgets('assistant validates empty question and displays AI response', (
    tester,
  ) async {
    final assistant = _FakeAssistant(
      answer: 'Regeneration recovers some motion energy.',
    );
    await tester.pumpWidget(_learnApp(assistant: assistant));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Ask the EV assistant'));
    await tester.pumpAndSettle();

    expect(
      find.text('Enter a question before asking the EV assistant.'),
      findsOneWidget,
    );
    expect(assistant.questions, isEmpty);

    await tester.enterText(
      find.byType(TextField),
      'What is regenerative braking?',
    );
    await tester.tap(find.byTooltip('Ask the EV assistant'));
    await tester.pumpAndSettle();

    expect(assistant.questions, ['What is regenerative braking?']);
    expect(
      find.text('Regeneration recovers some motion energy.'),
      findsOneWidget,
    );
    expect(assistant.contexts.single.telemetry?.battery, 54);
  });

  testWidgets('assistant shows Thinking while the callable is pending', (
    tester,
  ) async {
    final assistant = _PendingAssistant();
    await tester.pumpWidget(_learnApp(assistant: assistant));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'What is regenerative braking?',
    );
    await tester.tap(find.byTooltip('Ask the EV assistant'));
    await tester.pump();

    expect(find.text('Thinking...'), findsOneWidget);
    assistant.response.complete('It recovers some energy while slowing.');
    await tester.pumpAndSettle();
    expect(find.text('Thinking...'), findsNothing);
    expect(
      find.text('It recovers some energy while slowing.'),
      findsOneWidget,
    );
  });

  testWidgets('handles assistant failure without exposing internals', (
    tester,
  ) async {
    final assistant = _FakeAssistant(
      failure: Exception('provider secret detail'),
    );
    await tester.pumpWidget(_learnApp(assistant: assistant));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Explain battery health');
    await tester.tap(find.byTooltip('Ask the EV assistant'));
    await tester.pumpAndSettle();

    expect(
      find.text('AI assistant is temporarily unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(find.textContaining('provider secret detail'), findsNothing);
  });

  testWidgets('allows general questions when vehicle data is unavailable', (
    tester,
  ) async {
    final assistant = _FakeAssistant(
      answer: 'AC is converted by the onboard charger.',
    );
    await tester.pumpWidget(
      _learnApp(assistant: assistant, vehicle: null, telemetry: null),
    );
    await tester.pumpAndSettle();

    await _scrollToText(
      tester,
      'Current vehicle information is unavailable. You can still explore lessons and ask general EV questions.',
    );
    expect(
      find.textContaining('Current vehicle information is unavailable'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byType(TextField));
    await tester.ensureVisible(find.byTooltip('Ask the EV assistant'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'How does AC charging work?',
    );
    await tester.tap(find.byTooltip('Ask the EV assistant'));
    await tester.pumpAndSettle();

    expect(assistant.questions, ['How does AC charging work?']);
    expect(assistant.contexts.single.hasData, isFalse);
    expect(
      find.text('AC is converted by the onboard charger.'),
      findsOneWidget,
    );
  });

  testWidgets('shows lesson next navigation and completed-state visual', (
    tester,
  ) async {
    await tester.pumpWidget(_learnApp(assistant: _FakeAssistant()));
    await tester.pumpAndSettle();
    await _scrollToText(tester, 'BATTERY & RANGE');
    await tester.tap(find.text('BATTERY & RANGE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Understanding battery percentage'));
    await tester.pumpAndSettle();

    expect(find.textContaining('The minimum safety reserve'), findsNothing);
    await _scrollToText(
      tester,
      'Next lesson: Understanding estimated driving range',
    );
    expect(
      find.textContaining('Next lesson: Understanding estimated driving range'),
      findsOneWidget,
    );
    await tester.tap(
      find.text('Next lesson: Understanding estimated driving range'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Understanding estimated driving range'), findsOneWidget);
  });
}
