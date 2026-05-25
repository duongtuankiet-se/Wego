import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/trip_service.dart';
import 'mongo_provider.dart';

part 'trip_service_provider.g.dart';

@Riverpod(keepAlive: true)
TripService tripService(Ref ref) =>
    TripService(ref.watch(mongoServiceProvider));
