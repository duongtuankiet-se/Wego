import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../models/route.dart';
import '../services/route_service.dart';
import 'mongo_provider.dart';

part 'routes_provider.g.dart';

@Riverpod(keepAlive: true)
RouteService routeService(Ref ref) =>
    RouteService(ref.watch(mongoServiceProvider));

@riverpod
Future<List<RoutePreset>> activeRoutes(Ref ref) =>
    ref.watch(routeServiceProvider).getActiveRoutes();
