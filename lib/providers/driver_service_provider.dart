import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../services/driver_service.dart';
import 'mongo_provider.dart';

part 'driver_service_provider.g.dart';

@Riverpod(keepAlive: true)
DriverService driverService(Ref ref) =>
    DriverService(ref.watch(mongoServiceProvider));
