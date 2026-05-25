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

  /// Returns an open Db. Reconnects if dropped. Throws on persistent failure.
  Future<Db> getDb() async {
    final existing = _db;
    if (existing != null && existing.isConnected) return existing;

    if (_connecting != null) return _connecting!.future;

    final completer = Completer<Db>();
    _connecting = completer;
    try {
      final uri = dotenv.maybeGet('MONGODB_URI') ?? '';
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

      if (!_indexesEnsured) {
        try {
          await _ensureIndexes(db);
          _indexesEnsured = true;
        } catch (e) {
          developer.log('[mongo] ensureIndexes warning: $e', name: 'mongo');
        }
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
  }
}
