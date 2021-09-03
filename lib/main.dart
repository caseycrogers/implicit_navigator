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

  @override
  ImplicitNavigatorState createState() => ImplicitNavigatorState<T>();
}

class ImplicitNavigatorState<T> extends State<ImplicitNavigator<T>> {
  late final ImplicitNavigatorState? parent =
      _isRoot ? null : ImplicitNavigatorState.of(context);

  late final List<_StackEntry<T>> _stack;
  final Set<ImplicitNavigatorState> _children = {};

  bool initialized = false;

  bool get _isRoot {
    return context.findAncestorStateOfType<ImplicitNavigatorState<dynamic>>() ==
        null;
  }

  static ImplicitNavigatorState of<T>(BuildContext context) {
    return context.findAncestorStateOfType<ImplicitNavigatorState<T>>()!;
  }

  @override
  void didChangeDependencies() {
    if (!initialized) {
      dynamic cachedStack = PageStorage.of(context)!.readState(context);
      if (cachedStack is List<_StackEntry<T>>) {
        _stack = cachedStack;
      } else {
        _stack = [
          _StackEntry(widget.depth, widget.value),
        ];
      }
      initialized = true;
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
        if (widget.depth != null) {
          _stack.removeWhere(
            (entry) => entry.depth == null || entry.depth! >= widget.depth!,
          );
        }
        _stack.add(newEntry);
        PageStorage.of(context)!.writeState(context, _stack);
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
    if (!_isRoot) {
      if (_BackButtonStatus.of(context).isPopEnabled) {
        parent!.registerChild(this);
      } else {
        parent!.removeChild(this);
      }
    }
    return WillPopScope(
      onWillPop: _isRoot
          ? () async {
              return !(await _levelOrderPop());
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
          return _pop();
        },
      ),
    );
  }

  bool _pop() {
    if (_stack.length == 1) {
      return false;
    }
    setState(() {
      final T poppedValue = _stack.removeLast().value;
      PageStorage.of(context)!.writeState(context, _stack);
      widget.onPop?.call(poppedValue, _stack.last.value);
    });
    return true;
  }

  /// Attempt to pop from any of the Value Navigators in the widget tree.
  ///
  /// Navigators are tested in reverse level order-the most nested navigators
  /// attempt to pop first. Returns true if popping is successful.
  Future<bool> _levelOrderPop() async {
    final List<MapEntry<int, ImplicitNavigatorState>> queue = [
      MapEntry(0, this),
    ];
    final List<MapEntry<int, ImplicitNavigatorState>> states = [];

    while (queue.isNotEmpty) {
      final MapEntry<int, ImplicitNavigatorState> entry = queue.removeLast();
      states.add(entry);
      queue.addAll(
        entry.value._children.map((navigator) {
          return MapEntry(entry.key + 1, navigator);
        }),
      );
    }

    states.sort((a, b) {
      return -a.key.compareTo(b.key);
    });
    print(states);
    return states
            .map<ImplicitNavigatorState?>((entry) => entry.value)
            .firstWhere((state) => state!._pop(), orElse: () => null) !=
        null;
  }
}

typedef AnimatedWidgetBuilder<T> = Widget Function(
  BuildContext context,
  T value,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
);

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
