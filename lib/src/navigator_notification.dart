import 'package:flutter/widgets.dart';

@immutable
abstract class ValueNavigatorNotification<T> extends Notification {
  ValueNavigatorNotification({
    required this.currentValue,
    required this.currentDepth,
    required this.previousValue,
    required this.previousDepth,
  });

  final T currentValue;
  final int? currentDepth;

  final T previousValue;
  final int? previousDepth;
}

class PopNotification<T> extends ValueNavigatorNotification<T> {
  PopNotification({
    required T currentValue,
    required int? currentDepth,
    required T previousValue,
    required int? previousDepth,
  }) : super(
    currentValue: currentValue,
    currentDepth: currentDepth,
    previousValue: previousValue,
    previousDepth: previousDepth,
  );
}

class PushNotification<T> extends ValueNavigatorNotification<T> {
  PushNotification({
    required T currentValue,
    required int? currentDepth,
    required T previousValue,
    required int? previousDepth,
  }) : super(
    currentValue: currentValue,
    currentDepth: currentDepth,
    previousValue: previousValue,
    previousDepth: previousDepth,
  );
}