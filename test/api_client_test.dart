import 'dart:async';
import 'dart:convert';

import 'package:flutter_application_2/services/api/api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'support/fake_api.dart';

void main() {
  group('ApiClient', () {
    test('attaches the Firebase ID token and JSON headers', () async {
      final api = FakeApi()..on('POST /v1/things', (_) => {'ok': true});

      final result = await api.client().post('/v1/things', {'name': 'x'});

      expect(result, {'ok': true});
      final request = api.requests.single;
      expect(request.headers['Authorization'], 'Bearer test-token');
      expect(request.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(request.body), {'name': 'x'});
    });

    test('refreshes the token once after a 401 and retries', () async {
      var calls = 0;
      final api = FakeApi()
        ..on('GET /v1/me', (_) {
          calls++;
          return calls == 1
              ? const FakeReply(401, {
                  'error': {'code': 'unauthenticated', 'message': 'expired'},
                })
              : {'uid': 'alice'};
        });

      final result = await api.client().get('/v1/me');

      expect(result, {'uid': 'alice'});
      expect(api.tokensRequested, [false, true]);
    });

    test('a timeout explains that the server is waking up', () async {
      var attempts = 0;
      final client = ApiClient(
        baseUrl: 'http://api.test',
        timeout: const Duration(milliseconds: 20),
        tokenProvider: ({bool forceRefresh = false}) async => 't',
        httpClient: MockClient((_) async {
          attempts++;
          await Future<void>.delayed(const Duration(milliseconds: 200));
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        client.get('/v1/me'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'timeout')
              .having((e) => e.message, 'message', contains('waking up')),
        ),
      );
      // GET is retried once; POST is never repeated automatically.
      expect(attempts, 2);
      attempts = 0;
      await expectLater(client.post('/v1/x', {}), throwsA(isA<ApiException>()));
      expect(attempts, 1);
    });

    test('maps server errors to friendly messages', () async {
      final api = FakeApi()
        ..on(
          'GET /v1/vehicles/EV002',
          (_) => const FakeReply(404, {
            'error': {
              'code': 'vehicle_not_found',
              'message': 'Vehicle not found.',
            },
          }),
        )
        ..on(
          'POST /v1/debit',
          (_) => const FakeReply(409, {
            'error': {
              'code': 'insufficient_balance',
              'message': 'Insufficient charging card balance.',
            },
          }),
        )
        ..on('GET /v1/broken', (_) => const FakeReply(503));
      final client = api.client();

      await expectLater(
        client.get('/v1/vehicles/EV002'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'status', 404)
              .having(
                (e) => e.message,
                'message',
                "You don't have access to this vehicle.",
              ),
        ),
      );
      await expectLater(
        client.post('/v1/debit'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'insufficient_balance')
              .having((e) => e.toString(), 'text', contains('Insufficient')),
        ),
      );
      await expectLater(
        client.get('/v1/broken'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('waking up'),
          ),
        ),
      );
    });

    test('reports no internet connection without leaking details', () async {
      final client = ApiClient(
        baseUrl: 'http://api.test',
        tokenProvider: ({bool forceRefresh = false}) async => 'secret-token',
        httpClient: MockClient(
          (_) async => throw http.ClientException('XMLHttpRequest error'),
        ),
      );
      await expectLater(
        client.get('/v1/me'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.code, 'code', 'network')
              .having((e) => e.message, 'message', contains('No internet'))
              .having(
                (e) => e.toString(),
                'text',
                isNot(contains('secret-token')),
              ),
        ),
      );
    });
  });

  group('DataService watch streams', () {
    test(
      'emit, refetch after a write, skip duplicates and stop on cancel',
      () async {
        var reads = 0;
        var city = 'Chennai';
        final api = FakeApi()
          ..on('GET /v1/me', (_) {
            reads++;
            return {
              'uid': 'alice',
              'name': 'Alice',
              'email': 'a@x.com',
              'city': city,
            };
          })
          ..on('PATCH /v1/me', (request) {
            city = (jsonDecode(request.body) as Map)['city'] as String;
            return {'uid': 'alice'};
          });
        final service = api.dataService();
        final cities = <String>[];
        final firstEmission = Completer<void>();
        final secondEmission = Completer<void>();
        final subscription = service.watchUserProfile('alice').listen((
          profile,
        ) {
          cities.add(profile!.city);
          if (!firstEmission.isCompleted) {
            firstEmission.complete();
          } else if (!secondEmission.isCompleted) {
            secondEmission.complete();
          }
        });

        await firstEmission.future;
        expect(cities, ['Chennai']);

        await service.updateUserProfile(uid: 'alice', city: 'Coimbatore');
        await secondEmission.future;
        expect(cities, ['Chennai', 'Coimbatore']);

        // Another app write that changes nothing refetches but emits no duplicate.
        final readsBefore = reads;
        await service.updateUserProfile(uid: 'alice', city: 'Coimbatore');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(reads, greaterThan(readsBefore));
        expect(cities, ['Chennai', 'Coimbatore']);

        await subscription.cancel();
        final readsAtCancel = reads;
        await service.updateUserProfile(uid: 'alice', city: 'Madurai');
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(reads, readsAtCancel);
      },
    );

    test('a missing profile is null, and errors reach the stream', () async {
      final api = FakeApi()
        ..on(
          'GET /v1/me',
          (_) => const FakeReply(404, {
            'error': {'code': 'profile_not_found', 'message': 'No profile'},
          }),
        );
      expect(await api.dataService().getUserProfile('alice'), isNull);

      api.on('GET /v1/me', (_) => const FakeReply(500));
      await expectLater(
        api.dataService().watchUserProfile('alice').first,
        throwsA(isA<ApiException>()),
      );
    });
  });
}
