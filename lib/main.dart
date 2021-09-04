import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class ImplicitNavigator<T> extends StatefulWidget {
  const ImplicitNavigator({
    Key? key,
    required this.value,
    this.depth,
    required this.builder,
    this.routeTransitionsBuilder = defaultRouteTransitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.onPop,
    this.maintainState = false,
    this.opaque = true,
  }) : super(key: key);

  static Widget fromNotifier<T>({
    Key? key,
    required ValueNotifier<T> valueNotifier,
    int Function(T value)? getDepth,
    required AnimatedWidgetBuilder<T> builder,
    RouteTransitionsBuilder transitionsBuilder = defaultRouteTransitionsBuilder,
    Duration transitionDuration = const Duration(milliseconds: 300),
    void Function(T poppedValule, T newValue)? onPop,
    bool maintainState = false,
    bool opaque = true,
  }) {
    return ValueListenableBuilder<T>(
      valueListenable: valueNotifier,
      builder: (context, value, _) {
        return ImplicitNavigator<T>(
          key: key,
          value: value,
          depth: getDepth?.call(value),
          builder: builder,
          routeTransitionsBuilder: transitionsBuilder,
          transitionDuration: transitionDuration,
          onPop: (poppedValue, newValue) {
            onPop?.call(poppedValue, newValue);
            valueNotifier.value = newValue;
          },
          maintainState: maintainState,
          opaque: opaque,
        );
      },
    );
  }

  static Widget defaultRouteTransitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: ReverseAnimation(secondaryAnimation),
      child: FadeTransition(
        opacity: animation,
        child: child,
      ),
    );
  }

  final T value;

  final int? depth;

  /// TODO().
  final AnimatedWidgetBuilder<T> builder;

  /// TODO().
  final RouteTransitionsBuilder routeTransitionsBuilder;

  /// See [TransitionRoute.transitionDuration].
  final Duration transitionDuration;

  /// See [ModalRoute.maintainState].
  final bool maintainState;

  /// See [TransitionRoute.opaque].
  final bool opaque;

  final void Function(T poppedValue, T newValue)? onPop;

  static ImplicitNavigatorState of<T>(
    BuildContext context, {
    bool root = false,
  }) {
    if (root) {
      return context.findRootAncestorStateOfType<ImplicitNavigatorState<T>>()!;
    }
    return context.findAncestorStateOfType<ImplicitNavigatorState<T>>()!;
  }

  @override
  ImplicitNavigatorState createState() => ImplicitNavigatorState<T>();
}

class ImplicitNavigatorState<T> extends State<ImplicitNavigator<T>> {
  late final ImplicitNavigatorState? parent =
      isRoot ? null : ImplicitNavigator.of(context);

  late final List<_StackEntry<T>> _stack;
  final Set<ImplicitNavigatorState> _children = {};

  bool _initialized = false;

  T get value => _stack.last.value;

  int? get depth => _stack.last.depth;

  bool get isRoot {
    return context.findAncestorStateOfType<ImplicitNavigatorState<dynamic>>() ==
        null;
  }

  bool get canPop {
    return _stack.length > 1;
  }

  bool get treeCanPop {
    return canPop || _children.any((child) => child.treeCanPop);
  }

  List<ImplicitNavigatorState> get children =>
      _children.toList(growable: false);

  List<List<ImplicitNavigatorState>> get navigatorTree {
    return [
      [this],
      ..._children.expand((child) => child.navigatorTree),
    ];
  }

  @override
  void didChangeDependencies() {
    if (!_initialized) {
      dynamic cachedStack = PageStorage.of(context)!.readState(context);
      if (cachedStack is List<_StackEntry<T>>) {
        _stack = cachedStack;
      } else {
        _stack = [
          _StackEntry(widget.depth, widget.value),
        ];
      }
      _initialized = true;
    }
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(covariant ImplicitNavigator<T> oldWidget) {
    // Only update the stack if the new value is distinct.
    if (widget.value != _stack.last.value ||
        widget.depth != _stack.last.depth) {
      setState(() {
        final _StackEntry<T> newEntry = _StackEntry(widget.depth, widget.value);
        _pushEntry(newEntry);
      });
    }
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    parent?.removeChild(this);
    super.dispose();
  }

  void registerChild(ImplicitNavigatorState child) => _children.add(child);

  void removeChild(ImplicitNavigatorState child) => _children.remove(child);

  @override
  Widget build(BuildContext context) {
    final PageStorageBucket parentBucket = PageStorage.of(context)!;
    if (!isRoot) {
      if (_BackButtonStatus.of(context).isPopEnabled) {
        parent!.registerChild(this);
      } else {
        parent!.removeChild(this);
      }
    }
    return WillPopScope(
      onWillPop: isRoot
          ? () async {
              return !popFromTree();
            }
          : null,
      child: Navigator(
        pages: _stack.map((stackEntry) {
          return _ImplicitNavigatorPage<T>(
            // Bypass the page route's internal bucket so that we share state
            // across pages.
            bucket: parentBucket,
            key: ValueKey(stackEntry),
            value: stackEntry.value,
            builder: widget.builder,
            transitionsBuilder: widget.routeTransitionsBuilder,
            transitionDuration: widget.transitionDuration,
            maintainState: widget.maintainState,
            opaque: widget.opaque,
            // Only the top entry in the stack is allows to pop.
            isPopEnabled: stackEntry == _stack.last,
          );
        }).toList(),
        onPopPage: (route, result) {
          return pop();
        },
      ),
    );
  }

  /// Attempt to pop from this navigator.
  bool pop() {
    if (_stack.length == 1) {
      return false;
    }
    setState(() {
      final T poppedValue = _popEntry();
      widget.onPop?.call(poppedValue, _stack.last.value);
    });
    return true;
  }

  /// Attempt to pop from any implicit navigators in this navigator's
  /// [navigatorTree].
  ///
  /// Navigators are tested in reverse level order-the most nested navigators
  /// attempt to pop first. Returns true if popping is successful.
  bool popFromTree() {
    return navigatorTree.reversed
        .expand((navigators) => navigators)
        // `any` short circuits when it finds a true element so this will stop
        // calling pop if any call to pop succeeds.
        .any((navigator) => navigator.pop());
  }

  void _pushEntry(_StackEntry<T> newEntry) {
    _StackEntry<T> prevEntry = _stack.last;
    if (newEntry.depth != null) {
      _stack.removeWhere(
        (entry) => entry.depth == null || entry.depth! >= newEntry.depth!,
      );
    }
    _stack.add(newEntry);
    PageStorage.of(context)!.writeState(context, _stack);
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      PushNotification<T>(
        currentValue: newEntry.value,
        currentDepth: newEntry.depth,
        previousValue: prevEntry.value,
        previousDepth: prevEntry.depth,
      ).dispatch(context);
    });
  }

  T _popEntry() {
    final _StackEntry<T> poppedEntry = _stack.removeLast();
    PageStorage.of(context)!.writeState(context, _stack);
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      PopNotification<T>(
        currentValue: _stack.last.value,
        currentDepth: _stack.last.depth,
        previousValue: poppedEntry.value,
        previousDepth: poppedEntry.depth,
      ).dispatch(context);
    });
    return poppedEntry.value;
  }
}

typedef AnimatedWidgetBuilder<T> = Widget Function(
  BuildContext context,
  T value,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
);

abstract class ImplicitNavigatorNotification<T> extends Notification {
  ImplicitNavigatorNotification({
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

class PopNotification<T> extends ImplicitNavigatorNotification<T> {
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

class PushNotification<T> extends ImplicitNavigatorNotification<T> {
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

@immutable
class _StackEntry<T> {
  _StackEntry(this.depth, this.value);

  final int? depth;
  final T value;

  @override
  String toString() {
    return '{\'depth\': $depth, \'value:\': $value}';
  }
}

class _ImplicitNavigatorPage<T> extends Page<T> {
  _ImplicitNavigatorPage({
    required this.bucket,
    required this.value,
    required this.builder,
    this.transitionsBuilder,
    required this.transitionDuration,
    required this.maintainState,
    required this.opaque,
    required this.isPopEnabled,
    LocalKey? key,
    String? name,
    Object? arguments,
    String? restorationId,
  }) : super(
          key: key,
          name: name,
          arguments: arguments,
          restorationId: restorationId,
        );

  final T value;
  final AnimatedWidgetBuilder<T> builder;
  final RouteTransitionsBuilder? transitionsBuilder;

  final Duration transitionDuration;
  final bool maintainState;
  final bool opaque;

  final bool isPopEnabled;

  final PageStorageBucket bucket;

  @override
  Route<T> createRoute(BuildContext context) {
    return _ImplicitNavigatorRoute(this);
  }
}

class _ImplicitNavigatorRoute<T> extends ModalRoute<T> {
  _ImplicitNavigatorRoute(this._page);

  _ImplicitNavigatorPage<T> _page;

  @override
  RouteSettings get settings => _page;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return PageStorage(
      bucket: _page.bucket,
      child: _BackButtonStatus(
        isPopEnabled: _page.isPopEnabled,
        child:
            _page.builder(context, _page.value, animation, secondaryAnimation),
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return (_page.transitionsBuilder ?? super.buildTransitions)(
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get opaque => _page.opaque;

  @override
  Duration get transitionDuration => _page.transitionDuration;
}

class _BackButtonStatus extends InheritedWidget {
  const _BackButtonStatus({
    Key? key,
    required this.isPopEnabled,
    required this.child,
  }) : super(key: key, child: child);

  final bool isPopEnabled;
  final Widget child;

  @override
  bool updateShouldNotify(covariant _BackButtonStatus oldWidget) {
    return oldWidget.isPopEnabled == isPopEnabled;
  }

  static _BackButtonStatus of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_BackButtonStatus>()!;
}
