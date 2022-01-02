import 'package:flutter/material.dart';

import 'implicit_navigator_test.dart';
import 'test_listenable.dart';

void main() {
  const Version version = Version.selectFromListenable;
  final ValueNotifier<int> notifierA = ValueNotifier(0);
  final ValueNotifier<int> notifierB = ValueNotifier(0);
  final ValueNotifier<int> notifierC = ValueNotifier(0);
  final TestListenable listenableA = TestListenable(notifierA);
  final TestListenable listenableB = TestListenable(notifierB);
  final TestListenable listenableC = TestListenable(notifierC);
  runApp(
    boilerPlate(
      version,
      suffix: 'a',
      notifier: notifierA,
      listenable: listenableA,
      builder: (context, value) {
        if (value == 0) {
          return boilerPlate(
            version,
            root: false,
            suffix: 'b',
            notifier: notifierB,
            listenable: listenableB,
          );
        }
        return boilerPlate(
          version,
          root: false,
          suffix: 'c',
          notifier: notifierC,
          listenable: listenableC,
        );
      },
    ),
  );
}
