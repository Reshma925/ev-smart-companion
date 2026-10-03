import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_2/models/road_route.dart';
import 'package:flutter_application_2/widgets/destination_autocomplete_field.dart';
import 'package:latlong2/latlong.dart';

const _chennaiStation = GeocodedDestination(
  name: 'Chennai Central Railway Station',
  displayName: 'Chennai Central Railway Station',
  address: 'Chennai Central Railway Station, Chennai, Tamil Nadu, India',
  placeId: 'N/12345',
  addressComponents: {
    'city': 'Chennai',
    'state': 'Tamil Nadu',
    'country': 'India',
  },
  location: LatLng(13.082, 80.275),
);

Widget _app({
  required PlaceSearch searchPlaces,
  ValueChanged<String>? onQueryChanged,
  ValueChanged<GeocodedDestination?>? onPlaceSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DestinationAutocompleteField(
          searchPlaces: searchPlaces,
          onQueryChanged: onQueryChanged ?? (_) {},
          onPlaceSelected: onPlaceSelected ?? (_) {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('debounces a typed destination before searching', (tester) async {
    final queries = <String>[];
    await tester.pumpWidget(
      _app(
        searchPlaces: (query) async {
          queries.add(query);
          return const [_chennaiStation];
        },
      ),
    );

    await tester.enterText(find.byType(TextField), 'Chennai');
    await tester.pump(const Duration(milliseconds: 399));
    expect(queries, isEmpty);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(queries, ['Chennai']);
  });

  testWidgets('rapid keystrokes produce only one debounced request', (
    tester,
  ) async {
    final queries = <String>[];
    await tester.pumpWidget(
      _app(
        searchPlaces: (query) async {
          queries.add(query);
          return const [_chennaiStation];
        },
      ),
    );

    for (final input in ['Ch', 'Che', 'Chen', 'Chenn', 'Chennai']) {
      await tester.enterText(find.byType(TextField), input);
      await tester.pump(const Duration(milliseconds: 90));
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(queries, ['Chennai']);
  });

  testWidgets('displays place suggestions with supplied location metadata', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(searchPlaces: (_) async => const [_chennaiStation]),
    );
    await tester.enterText(find.byType(TextField), 'Chennai Central');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(find.text(_chennaiStation.displayLabel), findsOneWidget);
    expect(find.text('Chennai, Tamil Nadu, India'), findsOneWidget);
    expect(find.textContaining('Photon'), findsOneWidget);
  });

  testWidgets(
    'selecting a suggestion stores its coordinates and stops search',
    (tester) async {
      final queries = <String>[];
      GeocodedDestination? selected;
      await tester.pumpWidget(
        _app(
          searchPlaces: (query) async {
            queries.add(query);
            return const [_chennaiStation];
          },
          onPlaceSelected: (place) => selected = place,
        ),
      );
      await tester.enterText(find.byType(TextField), 'Chennai Central');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      await tester.tap(
        find.widgetWithText(ListTile, _chennaiStation.displayLabel),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(selected?.location, const LatLng(13.082, 80.275));
      expect(selected?.placeId, 'N/12345');
      expect(queries, ['Chennai Central']);
      expect(find.byType(ListTile), findsNothing);
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, _chennaiStation.displayLabel);
    },
  );

  testWidgets('empty query makes no request and no-results has clear text', (
    tester,
  ) async {
    var requests = 0;
    await tester.pumpWidget(
      _app(
        searchPlaces: (_) async {
          requests++;
          return const [];
        },
      ),
    );

    await tester.enterText(find.byType(TextField), '  ');
    await tester.pump(const Duration(seconds: 1));
    expect(requests, 0);
    await tester.enterText(find.byType(TextField), 'Nowhere');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(requests, 1);
    expect(find.text('No places found'), findsOneWidget);
  });

  testWidgets('search failures do not crash and clear suggestions', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(searchPlaces: (_) async => throw Exception('network unavailable')),
    );
    await tester.enterText(find.byType(TextField), 'Chennai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    expect(
      find.text(
        'Could not search places. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ListTile), findsNothing);
  });

  testWidgets('leaving the field clears active suggestions', (tester) async {
    await tester.pumpWidget(
      _app(searchPlaces: (_) async => const [_chennaiStation]),
    );
    await tester.enterText(find.byType(TextField), 'Chennai');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tapAt(const Offset(20, 400));
    await tester.pump();
    expect(find.byType(ListTile), findsNothing);
  });
}
