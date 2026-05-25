import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    // .env missing is fatal at first connect; Splash will show retry UI.
  }
  await initializeDateFormatting('vi_VN');
  runApp(const ProviderScope(child: WeGoApp()));
}
