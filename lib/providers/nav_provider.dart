import 'package:flutter/foundation.dart';

/// Alt menüde seçili sekmeyi tutar.
/// 0=Ana Sayfa, 1=Geçmiş, 2=Ekle, 3=AI Kam, 4=Ayarlar
class NavProvider extends ChangeNotifier {
  int _index = 0;
  int get index => _index;

  void go(int i) {
    if (i == _index) return;
    _index = i;
    notifyListeners();
  }
}
