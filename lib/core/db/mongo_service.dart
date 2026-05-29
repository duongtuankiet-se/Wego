import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mongo_dart/mongo_dart.dart';

import 'collections.dart';

class MongoServiceException implements Exception {
  final String message;
  final Object? cause;
  MongoServiceException(this.message, [this.cause]);
  @override
  String toString() => 'MongoServiceException: $message';
}

class MongoService {
  MongoService._internal();
  static final MongoService _instance = MongoService._internal();
  factory MongoService() => _instance;

  Db? _db;
  Completer<Db>? _connecting;
  bool _indexesEnsured = false;

  /// Phase 5Q hotfix: append Atlas-friendly pool + timeout params to
  /// the URI loaded from .env so the driver keeps a small pool, drops
  /// idle sockets before Atlas Free-tier evicts them, and falls back
  /// fast instead of hanging on a TCP RST. `safeAtlas=true` is the
  /// mongo_dart-specific flag for tolerating the SNI/TLS hiccups
  /// Atlas Free intermittently inflicts on long-lived connections.
  String _buildUri() {
    final base = (dotenv.maybeGet('MONGODB_URI') ?? '').trim();
    if (base.isEmpty) return '';
    final extras = <String>[
      'safeAtlas=true',
      'maxIdleTimeMS=30000',
      'maxPoolSize=10',
      'connectTimeoutMS=10000',
      'socketTimeoutMS=30000',
    ];
    final connector = base.contains('?') ? '&' : '?';
    return '$base$connector${extras.join('&')}';
  }

  /// Returns an open Db. Reconnects if dropped. Throws on persistent failure.
  Future<Db> getDb() async {
    final existing = _db;
    if (existing != null && existing.isConnected) return existing;

    if (_connecting != null) return _connecting!.future;

    final completer = Completer<Db>();
    _connecting = completer;
    try {
      final uri = _buildUri();
      if (uri.isEmpty) {
        throw MongoServiceException('Thiếu MONGODB_URI trong .env');
      }

      final db = await Db.create(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw MongoServiceException(
          'Quá thời gian phân giải DNS Atlas (15s). Kiểm tra mạng/connection string.',
        ),
      );

      await db.open().timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw MongoServiceException(
          'Quá thời gian kết nối MongoDB (15s). Kiểm tra Atlas Network Access và mạng.',
        ),
      );

      _db = db;
      developer.log(
        '[mongo] connected to ${db.databaseName ?? "(default)"}',
        name: 'mongo',
      );

      // Hotfix: hand the open Db back to callers immediately and run
      // index creation in the background. The 13 createIndex round-
      // trips used to run serially before we returned, and on Atlas
      // Free that holds the socket long enough for Atlas to reset it
      // mid-stream — the very symptom we're fixing.
      if (!_indexesEnsured) {
        unawaited(_ensureIndexesInBackground(db));
      }

      completer.complete(db);
      return db;
    } catch (e, st) {
      developer.log(
        '[mongo] connection error: $e',
        name: 'mongo',
        error: e,
        stackTrace: st,
      );
      _db = null;
      final err = e is MongoServiceException
          ? e
          : MongoServiceException('Lỗi kết nối MongoDB: $e', e);
      completer.completeError(err, st);
      rethrow;
    } finally {
      _connecting = null;
    }
  }

  Future<void> _ensureIndexesInBackground(Db db) async {
    try {
      await _ensureIndexes(db);
      _indexesEnsured = true;
      developer.log('[mongo] indexes ensured', name: 'mongo');
    } catch (e) {
      // Re-arm so the next reconnect retries — but never crash the
      // app: the indexes are perf, not correctness.
      developer.log('[mongo] ensureIndexes warning: $e', name: 'mongo');
    }
  }

  Future<DbCollection> users() async =>
      (await getDb()).collection(Collections.users);
  Future<DbCollection> drivers() async =>
      (await getDb()).collection(Collections.drivers);
  Future<DbCollection> vehicles() async =>
      (await getDb()).collection(Collections.vehicles);
  Future<DbCollection> trips() async =>
      (await getDb()).collection(Collections.trips);
  Future<DbCollection> ratings() async =>
      (await getDb()).collection(Collections.ratings);
  Future<DbCollection> scheduledTrips() async =>
      (await getDb()).collection(Collections.scheduledTrips);
  Future<DbCollection> driverVehicles() async =>
      (await getDb()).collection(Collections.driverVehicles);
  Future<DbCollection> tripPools() async =>
      (await getDb()).collection(Collections.tripPools);
  Future<DbCollection> routes() async =>
      (await getDb()).collection(Collections.routes);
  Future<DbCollection> wallets() async =>
      (await getDb()).collection(Collections.wallets);
  Future<DbCollection> walletTransactions() async =>
      (await getDb()).collection(Collections.walletTransactions);

  Future<void> close() async {
    try {
      await _db?.close();
    } catch (_) {}
    _db = null;
    _indexesEnsured = false;
  }

  Future<void> _ensureIndexes(Db db) async {
    await db
        .collection(Collections.users)
        .createIndex(
          keys: {'phone': 1},
          unique: true,
          name: 'idx_users_phone_unique',
        );
    await db
        .collection(Collections.drivers)
        .createIndex(
          keys: {'user_id': 1},
          unique: true,
          name: 'idx_drivers_user_id_unique',
        );
    await db
        .collection(Collections.trips)
        .createIndex(
          keys: {'pickup_geohash': 1, 'status': 1, 'created_at': -1},
          name: 'idx_trips_pickup_status_created',
        );
    await db
        .collection(Collections.trips)
        .createIndex(
          keys: {'passenger_id': 1, 'created_at': -1},
          name: 'idx_trips_passenger_created',
        );
    await db
        .collection(Collections.trips)
        .createIndex(
          keys: {'driver_id': 1, 'created_at': -1},
          name: 'idx_trips_driver_created',
        );
    // ── Phase 5I scheduled trips ──────────────────────────────────
    await db
        .collection(Collections.scheduledTrips)
        .createIndex(
          keys: {'passenger_id': 1, 'scheduled_at': -1},
          name: 'idx_sched_passenger_time',
        );
    await db
        .collection(Collections.scheduledTrips)
        .createIndex(
          keys: {'status': 1, 'scheduled_at': 1},
          name: 'idx_sched_status_time',
        );
    await db
        .collection(Collections.scheduledTrips)
        .createIndex(
          keys: {'driver_id': 1, 'status': 1},
          name: 'idx_sched_driver_status',
        );
    // ── Phase 5N carpool ─────────────────────────────────────────
    await db
        .collection(Collections.driverVehicles)
        .createIndex(
          keys: {'driver_id': 1, 'is_active': 1},
          name: 'idx_driver_vehicles_driver_active',
        );
    await db
        .collection(Collections.driverVehicles)
        .createIndex(
          keys: {'driver_id': 1, 'vehicle_plate': 1},
          unique: true,
          name: 'idx_driver_vehicles_plate_unique',
        );
    await db
        .collection(Collections.tripPools)
        .createIndex(
          keys: {
            'status': 1,
            'dropoff_city': 1,
            'dropoff_district': 1,
            'scheduled_at': 1,
          },
          name: 'idx_pools_status_route_time',
        );
    await db
        .collection(Collections.tripPools)
        .createIndex(
          keys: {'cancel_deadline': 1, 'status': 1},
          name: 'idx_pools_cancel_deadline',
        );
    await db
        .collection(Collections.tripPools)
        .createIndex(
          keys: {'driver_id': 1, 'status': 1},
          name: 'idx_pools_driver_status',
        );
    // ── Phase 5Q routes + wallet ────────────────────────────────
    await db
        .collection(Collections.routes)
        .createIndex(
          keys: {'route_code': 1},
          unique: true,
          name: 'idx_routes_code_unique',
        );
    await db
        .collection(Collections.routes)
        .createIndex(
          keys: {'is_active': 1, 'display_order': 1},
          name: 'idx_routes_active_order',
        );
    await db
        .collection(Collections.routes)
        .createIndex(
          keys: {'pickup_city': 1, 'dropoff_city': 1},
          name: 'idx_routes_endpoints',
        );
    await db
        .collection(Collections.wallets)
        .createIndex(
          keys: {'user_id': 1},
          unique: true,
          name: 'idx_wallets_user_unique',
        );
    await db
        .collection(Collections.walletTransactions)
        .createIndex(
          keys: {'user_id': 1, 'created_at': -1},
          name: 'idx_wallet_txns_user_time',
        );
  }
}
