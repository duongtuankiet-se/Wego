import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/db/mongo_service.dart';

part 'mongo_provider.g.dart';

@Riverpod(keepAlive: true)
MongoService mongoService(Ref ref) => MongoService();
