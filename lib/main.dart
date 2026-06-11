import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/diary_provider.dart';
import 'providers/nav_provider.dart';
import 'providers/settings_provider.dart';
import 'repositories/food_log_repository.dart';
import 'screens/main_scaffold.dart';
import 'services/database_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // .env yoksa uygulama yine de çalışsın (anahtar Ayarlar'dan girilebilir).
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    dotenv.testLoad(fileInput: '');
  }

  await initializeDateFormatting('tr');
  final prefs = await SharedPreferences.getInstance();

  final repository = LocalFoodLogRepository(DatabaseService());

  runApp(KaloriTakipApp(prefs: prefs, repository: repository));
}

class KaloriTakipApp extends StatelessWidget {
  final SharedPreferences prefs;
  final FoodLogRepository repository;

  const KaloriTakipApp({
    super.key,
    required this.prefs,
    required this.repository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FoodLogRepository>.value(value: repository),
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => DiaryProvider(repository)),
        ChangeNotifierProvider(create: (_) => NavProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'NutriTrack',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const MainScaffold(),
        ),
      ),
    );
  }
}
