import 'package:flutter/widgets.dart';
import 'package:implicit_navigator/implicit_navigator.dart';

/// A notification that is dispatched whenever a [ImplicitNavigator]'s stack
/// changes.
@immutable
abstract class ImplicitNavigatorNotification<T> extends Notification {
  const ImplicitNavigatorNotification({
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

/// A notification that is dispatched whenever an [ImplicitNavigator]'s
/// finishing popping from it's internal navigation stack.
class PopNotification<T> extends ImplicitNavigatorNotification<T> {
  const PopNotification({
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

/// A notification that is dispatched whenever an [ImplicitNavigator]'s
/// pushes a new value to it's internal navigation stack.
class PushNotification<T> extends ImplicitNavigatorNotification<T> {
  const PushNotification({
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
