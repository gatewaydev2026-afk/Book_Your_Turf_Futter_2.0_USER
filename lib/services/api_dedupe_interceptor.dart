// lib/services/api_dedupe_interceptor.dart
// ============================================================
// ✅ GLOBAL DUPLICATE-GET PROTECTION (Sep 2026)
// If the same GET (same method + full URL incl. query) is already on the
// wire, a second caller does NOT hit the server again – it waits for the
// first response and gets the same data.
//
// • Only GET requests (POST/PUT/PATCH/DELETE are never merged – payments,
//   bookings etc. always go through exactly as called).
// • Opt out per request with: Options(extra: {'no_dedupe': true})
// ============================================================

import 'dart:async';
import 'package:dio/dio.dart';

class ApiDedupeInterceptor extends Interceptor {
  static const String optOutKey = 'no_dedupe';
  static const String _ownerKey = '_dedupe_owner_key';

  final Map<String, Completer<Response<dynamic>>> _inFlight = {};

  String _keyOf(RequestOptions o) => '${o.method.toUpperCase()} ${o.uri}';

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (options.method.toUpperCase() != 'GET' || options.extra[optOutKey] == true) {
      return handler.next(options);
    }

    final key = _keyOf(options);
    final running = _inFlight[key];

    if (running != null) {
      print('🔁 [API] duplicate GET merged: ${options.uri.path}');
      try {
        final first = await running.future;
        return handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            data: first.data,
            statusCode: first.statusCode,
            statusMessage: first.statusMessage,
            headers: first.headers,
            extra: Map<String, dynamic>.from(first.extra),
          ),
        );
      } on DioException catch (e) {
        return handler.reject(
          DioException(
            requestOptions: options,
            response: e.response,
            type: e.type,
            error: e.error,
            message: e.message,
          ),
        );
      } catch (e) {
        return handler.reject(DioException(requestOptions: options, error: e));
      }
    }

    final completer = Completer<Response<dynamic>>();
    // nobody may be waiting – don't report an unhandled error in that case
    completer.future.catchError((_) => Response<dynamic>(requestOptions: options));
    _inFlight[key] = completer;
    options.extra[_ownerKey] = key;
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    final key = response.requestOptions.extra[_ownerKey];
    if (key is String) {
      final c = _inFlight.remove(key);
      if (c != null && !c.isCompleted) c.complete(response);
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final key = err.requestOptions.extra[_ownerKey];
    if (key is String) {
      final c = _inFlight.remove(key);
      if (c != null && !c.isCompleted) c.completeError(err);
    }
    handler.next(err);
  }
}
