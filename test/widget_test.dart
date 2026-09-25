import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/login.dart';

void main() {
	testWidgets('renders the EV Smart Companion login screen', (tester) async {
		await tester.pumpWidget(
			const MaterialApp(home: LoginPage()),
		);

		expect(find.text('Welcome Back'), findsOneWidget);
		expect(find.text('Email or Mobile Number'), findsOneWidget);
		expect(find.text('LOG IN'), findsOneWidget);
	});
}
