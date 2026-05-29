import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'core/db/mongo_service.dart';
import 'core/db/seed_routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  // Firebase Phone Auth — reads google-services.json on Android.
  await Firebase.initializeApp();
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing is fatal at first connect; Splash will show retry UI.
  }
  await initializeDateFormatting('vi_VN');

  // Phase 5Q: seed the 7 default Miền Trung routes the first time the
  // collection is empty. Fire-and-forget — failures (no .env, no
  // network) are logged inside the seed and we still let the app boot
  // so Splash can drive the existing retry UI.
  RouteSeed.seedIfEmpty(MongoService()).ignore();

  runApp(const ProviderScope(child: WeGoApp()));
}
