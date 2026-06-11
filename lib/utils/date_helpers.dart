import 'package:intl/intl.dart';

/// Tarihleri veritabanı anahtarı (YYYY-MM-DD) ve görünen biçim arasında çevirir.
class DateHelpers {
  static final _key = DateFormat('yyyy-MM-dd');
  static final _display = DateFormat('d MMMM EEEE', 'tr');
  static final _short = DateFormat('d MMM', 'tr');

  static String keyOf(DateTime d) => _key.format(d);

  static DateTime parseKey(String key) => _key.parse(key);

  static String displayOf(DateTime d) => _display.format(d);

  static String displayOfKey(String key) => _display.format(parseKey(key));

  static String shortOfKey(String key) => _short.format(parseKey(key));

  static String today() => keyOf(DateTime.now());

  /// İki tarih anahtarının aynı güne ait olup olmadığını kontrol eder.
  static bool isToday(String key) => key == today();
}
