import 'package:flutter/widgets.dart';

class TestListenable extends ChangeNotifier {
  TestListenable(this._notifier);

  final ValueNotifier<int> _notifier;
  String _otherValue = 'a';

  int get value => _notifier.value;

  String get otherValue => _otherValue;

  set value(int newValue) {
    if (_notifier.value == newValue) {
      return;
    }
    _notifier.value = newValue;
    notifyListeners();
  }

  set otherValue(String newValue) {
    if (_otherValue == newValue) {
      return;
    }
    _otherValue = newValue;
    notifyListeners();
  }
}
