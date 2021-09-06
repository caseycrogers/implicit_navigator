import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'navigator_notification.dart';
import 'value_navigator_page.dart';

class ValueNavigator<T> extends StatefulWidget {
  const ValueNavigator({
    Key? key,
    required this.value,
    this.depth,
    this.initialHistory,
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
    List<ValueHistoryEntry<T>>? initialHistory,
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
        return ValueNavigator<T>(
          key: key,
          value: value,
          depth: getDepth?.call(value),
          initialHistory: initialHistory,
          builder: builder,
          routeTransitionsBuilder: transitionsBuilder,
          transitionDuration: transitionDuration,
          onPop: (poppedValue, newValue) {
            valueNotifier.value = newValue;
            onPop?.call(poppedValue, newValue);
          },
          maintainState: maintainState,
          opaque: opaque,
        );
      },
    );
  }

  static Widget defaultRouteTransitionsBuilder(BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      Widget child,) {
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

  final List<ValueHistoryEntry<T>>? initialHistory;

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

  static ValueNavigatorState of<T>(BuildContext context, {
    bool root = false,
  }) {
    ValueNavigatorState? navigator;
    if (context is StatefulElement && context.state is ValueNavigatorState) {
      navigator = context.state as ValueNavigatorState;
    }
    if (root) {
      navigator =
          context.findRootAncestorStateOfType<ValueNavigatorState<T>>() ??
              navigator;
    } else {
      navigator ??= context.findAncestorStateOfType<ValueNavigatorState<T>>();
    }
    return navigator!;
  }

  @override
  ValueNavigatorState createState() => ValueNavigatorState<T>();
}

class ValueNavigatorState<T> extends State<ValueNavigator<T>> {
  static final ValueNotifier<bool> _displayBackButton = ValueNotifier(false);
  static late VoidCallback _backButtonOnPressed;

  late final ValueNavigatorState? parent = isRoot
      ? null
  // Don't use `.of()` here as that'd just return this.
      : context.findAncestorStateOfType<ValueNavigatorState>();

  late final List<ValueHistoryEntry<T>> _stack;
  final Set<ValueNavigatorState> _children = {};

  List<T> get history => _stack.map((entry) => entry.value).toList();

  T get value => _stack.last.value;

  int? get depth => _stack.last.depth;

  bool get isRoot {
    return context.findAncestorStateOfType<ValueNavigatorState>() == null;
  }

  bool get canPop {
    return _stack.length > 1;
  }

  bool get treeCanPop {
    return navigatorTree
        .expand((navigators) => navigators)
        .any((navigator) => navigator.canPop);
  }

  List<ValueNavigatorState> get children => _children.toList(growable: false);

  List<List<ValueNavigatorState>> get navigatorTree {
    if (!isActive) {
      // This navigator is not at the top of it's parent navigator so it's tree
      // should be treated as empty.
      return [];
    }
    return [
      [this],
      ..._children.expand((child) => child.navigatorTree),
    ];
  }

  bool _disabled = false;

  void enable() {
    if (_disabled) {
      _disabled = false;
      _onTreeChanged();
    }
  }

  void disable() {
    if (!_disabled) {
      _disabled = true;
      _onTreeChanged();
    }
  }

  bool get isActive {
    return !_disabled && ModalRoute.of(context)!.isCurrent;
  }

  @override
  void initState() {
    if (isRoot) {
      _backButtonOnPressed = popFromTree;
    }
    parent?._registerChild(this);
    final ValueHistoryEntry<T> entry =
    ValueHistoryEntry(widget.depth, widget.value);
    dynamic cachedStack = PageStorage.of(context)!.readState(context);
    if (widget.key is PageStorageKey &&
        cachedStack is List<ValueHistoryEntry<T>>) {
      _stack = cachedStack;
    } else if (widget.initialHistory != null) {
      _stack = widget.initialHistory!;
      // Ensure initial history gets cached.
      PageStorage.of(context)!.writeState(context, _stack);
    } else {
      _stack = [entry];
    }
    // We need to check if the current value is distinct from the last
    // cached value.
    _addIfNew(entry);
    // Ensure this is called even if `addIfNew` did not call it.
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _onTreeChanged();
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ValueNavigator<T> oldWidget) {
    setState(() {
      _addIfNew(ValueHistoryEntry(widget.depth, widget.value));
    });
    super.didUpdateWidget(oldWidget);
  }

  void _addIfNew(ValueHistoryEntry<T> newEntry) {
    if (widget.value != _stack.last.value ||
        widget.depth != _stack.last.depth) {
      _pushEntry(newEntry);
    }
  }

  @override
  void dispose() {
    parent?._removeChild(this);
    super.dispose();
  }

  void _onTreeChanged() {
    ValueNavigatorState._displayBackButton.value =
        ValueNavigator
            .of(context, root: true)
            .treeCanPop;
  }

  void _registerChild(ValueNavigatorState child) => _children.add(child);

  void _removeChild(ValueNavigatorState child) => _children.remove(child);

  @override
  Widget build(BuildContext context) {
    final PageStorageBucket parentBucket = PageStorage.of(context)!;
    Widget internalNavigator = Navigator(
      pages: _stack.map((stackEntry) {
        return ValueNavigatorPage<T>(
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
        );
      }).toList(),
      onPopPage: (route, result) {
        return pop();
      },
    );
    if (isRoot) {
      return WillPopScope(
        onWillPop: () async {
          return !popFromTree();
        },
        child: internalNavigator,
      );
    }
    return internalNavigator;
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

  /// Attempt to pop from any value navigators in this navigator's
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

  void _pushEntry(ValueHistoryEntry<T> newEntry) {
    ValueHistoryEntry<T> prevEntry = _stack.last;
    if (newEntry.depth != null) {
      _stack.removeWhere(
            (entry) => entry.depth == null || entry.depth! >= newEntry.depth!,
      );
    }
    _stack.add(newEntry);
    if (widget.key is PageStorageKey) {
      PageStorage.of(context)!.writeState(context, _stack);
    }
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _onTreeChanged();
      PushNotification<T>(
        currentValue: newEntry.value,
        currentDepth: newEntry.depth,
        previousValue: prevEntry.value,
        previousDepth: prevEntry.depth,
      ).dispatch(context);
    });
  }

  T _popEntry() {
    final ValueHistoryEntry<T> poppedEntry = _stack.removeLast();
    if (widget.key is PageStorageKey) {
      PageStorage.of(context)!.writeState(context, _stack);
    }
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _onTreeChanged();
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

class ValueNavigatorBackButton extends StatelessWidget {
  const ValueNavigatorBackButton({
    this.transitionDuration = const Duration(milliseconds: 100),
    Key? key,
  }) : super(key: key);

  final Duration transitionDuration;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ValueNavigatorState._displayBackButton,
      builder: (context, shouldDisplay, backButton) {
        return AnimatedSwitcher(
          duration: transitionDuration,
          child: Visibility(
            key: ValueKey(shouldDisplay),
            visible: shouldDisplay,
            child: backButton!,
          ),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(-1, 0),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            );
          },
        );
      },
      child: BackButton(
        // Nested function call to avoid late initialization error.
        onPressed: () => ValueNavigatorState._backButtonOnPressed(),
      ),
    );
  }
}

@immutable
class ValueHistoryEntry<T> {
  ValueHistoryEntry(this.depth, this.value);

  final int? depth;
  final T value;

  @override
  String toString() {
    return '{\'depth\': $depth, \'value:\': $value}';
  }
}
