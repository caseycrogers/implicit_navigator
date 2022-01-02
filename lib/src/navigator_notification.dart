import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:implicit_navigator/implicit_navigator.dart';

/// A notification that is dispatched whenever a [ImplicitNavigator]'s stack
/// changes.
@immutable
abstract class ImplicitNavigatorNotification<T> extends Notification {
  const ImplicitNavigatorNotification({
    required this.valueAfterPop,
    required this.currentDepth,
    required this.previousValue,
    required this.previousDepth,
  });

  /// The current value of [ImplicitNavigator.value] for the navigator that
  /// dispatched this notification.
  ///
  /// This is the value **after** the action corresponding to this notification
  /// completed.
  final T valueAfterPop;

  /// The current value of [ImplicitNavigator.depth] for the navigator that
  /// dispatched this notification.
  ///
  /// This is the depth **after** the action corresponding to this notification
  /// completed.
  final int? currentDepth;

  /// The old value of [ImplicitNavigator.value] from **before** the action
  /// corresponding to this notification was executed.
  final T previousValue;

  /// The old value of [ImplicitNavigator.depth] from **before** the action
  /// corresponding to this notification was executed.
  final int? previousDepth;
}

/// A notification that is dispatched whenever an [ImplicitNavigator] pops a
/// value and depth from it's internal navigation stack.
///
/// Current depth/value correspond to the new depth and value after the pop is
/// complete.
/// Previous depth/value correspond to the depth and value that were popped from
/// the stack.
class PopNotification<T> extends ImplicitNavigatorNotification<T> {
  const PopNotification({
    required T valueAfterPop,
    required int? currentDepth,
    required T previousValue,
    required int? previousDepth,
  }) : super(
          valueAfterPop: valueAfterPop,
          currentDepth: currentDepth,
          previousValue: previousValue,
          previousDepth: previousDepth,
        );
}

/// A notification that is dispatched whenever an [ImplicitNavigator] pushes a
/// new value and/or depth to it's internal navigation stack.
///
/// Current depth/value correspond to the new depth and value that were pushed
/// onto the stack.
/// Previous depth/value correspond to the depth and value that were on top of
/// the stack before the push was executed.
class PushNotification<T> extends ImplicitNavigatorNotification<T> {
  const PushNotification({
    required T valueAfterPop,
    required int? currentDepth,
    required T previousValue,
    required int? previousDepth,
  }) : super(
          valueAfterPop: valueAfterPop,
          currentDepth: currentDepth,
          previousValue: previousValue,
          previousDepth: previousDepth,
        );
}
