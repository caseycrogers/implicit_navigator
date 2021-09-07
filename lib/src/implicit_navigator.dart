import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'implicit_navigator_page.dart';
import 'navigator_notification.dart';


/// Pushes and pops pages from an internal navigator in response to changing app
/// state.
///
/// When [value] and/or [depth] change, a new page is pushed onto the navigator
/// stack and [builder] is called with the latest [value]. When [popFromTree] is
/// called or the system back button is pressed, [ImplicitNavigator] attempts to
/// pop from any navigator in the tree, starting with deepest nested navigator
/// first and breaking ties between equally deep navigators with [popPriority].
///
/// Implicit Navigator can be used to produce two distinct navigation patterns:
///  - App-Style: the back button/pop goes "up" a developer defined navigation
///    hierarchy, potentially undoing multiple state changes at once.
///    App-style is typical for most modern smartphone apps.
///  - Browser-Style: the back button/pop reverts the last state change.
///    Browser-style is how most web pages behave.
///
/// For app-style navigation, specify non-null values for [depth] to set your
/// app's navigation hierarchy. Additionally, provide a `PageStorageKey` to any
/// [ImplicitNavigator] nested inside of another [ImplicitNavigator].
/// This ensures that the history of the inner navigator is maintained when the
/// user navigates away form it and then back to it.
///
/// For browser-style navigation, simply leave [depth] null and do not provide
/// a `PageStorageKey` to any nested [ImplicitNavigator]'s.
class ImplicitNavigator<T> extends StatefulWidget {
  const ImplicitNavigator({
    this.key,
    required this.value,
    this.depth,
    this.initialHistory,
    required this.builder,
    this.transitionsBuilder = defaultRouteTransitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.onPop,
    this.maintainState = true,
    this.opaque = true,
    this.popPriority,
  })  : _valueNotifier = null,
        _getDepth = null;

  /// Creates an [ImplicitNavigator] that pushes new pages when the
  /// [valueNotifier] changes and reverts [valueNotifier.value] when pages are
  /// popped.
  ImplicitNavigator.fromNotifier({
    this.key,
    required ValueNotifier<T> valueNotifier,
    int Function(T value)? getDepth,
    this.initialHistory,
    required this.builder,
    this.transitionsBuilder = defaultRouteTransitionsBuilder,
    this.transitionDuration = const Duration(milliseconds: 300),
    this.onPop,
    this.maintainState = true,
    this.opaque = true,
    this.popPriority,
  })  : value = valueNotifier.value,
        depth = getDepth?.call(valueNotifier.value),
        _valueNotifier = valueNotifier,
        _getDepth = getDepth;

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

  final ValueNotifier<T>? _valueNotifier;
  final int Function(T newValue)? _getDepth;

  /// See [Widget.key].
  ///
  /// If key is a [PageStorageKey], this widget will use page storage to
  /// save and (on reinitialization) restore it's history stack.
  @override
  final Key? key;

  /// The current value to build the navigator with.
  ///
  /// When this widget is rebuilt with a new value, a new page will be added to
  /// the history stack corresponding to the newest value.
  final T value;

  /// The depth of the current [value].
  ///
  /// Depth should be updated when value is updated.
  ///
  /// When pushing a new value to the history stack, the new value will be
  /// pushed as a replacement to all entries of equal or greater depth.
  /// If [ImplicitNavigator] is rebuilt with a new [depth] and unchanged
  /// [value], a page will still be pushed to the stack.
  ///
  /// Values with a depth of null are always appended to the end of the stack,
  /// including after any other values of null depth.
  final int? depth;

  /// A history stack to initialize this [ImplicitNavigator] with.
  ///
  /// If a `PageStorageKey` is provided and a cached history stack is available
  /// at initialization, the cached stack will be used and [initialHistory] will
  /// be ignored.
  final List<ValueHistoryEntry<T>>? initialHistory;

  /// An animated build function that builds a widget from the given [value].
  ///
  /// Use the `animation` and `secondaryAnimation` arguments to independently
  /// animate widgets within the builder.
  final AnimatedValueWidgetBuilder<T> builder;

  /// A function for animating the widget returned by [builder] in and out.
  final RouteTransitionsBuilder transitionsBuilder;

  /// See [TransitionRoute.transitionDuration].
  final Duration transitionDuration;

  /// See [ModalRoute.maintainState].
  final bool maintainState;

  /// See [TransitionRoute.opaque].
  final bool opaque;

  /// A callback that runs immediately after a page is popped.
  final void Function(T poppedValue, T newValue)? onPop;

  /// The priority of this widget when choosing which implicit navigator to pop
  /// from.
  ///
  /// A lower number corresponds to a higher priority.
  ///
  /// Implicit navigator always attempts to pop from the inner most navigators
  /// first, it'll only consider pop priority when deciding between two implicit
  /// navigators at the same depth in the [navigatorTree].
  final int? popPriority;

  /// Get the nearest ancestor [ImplicitNavigatorState] in the widget tree.
  static ImplicitNavigatorState<T> of<T>(
    BuildContext context, {
    bool root = false,
  }) {
    ImplicitNavigatorState<T>? navigator;
    if (context is StatefulElement &&
        context.state is ImplicitNavigatorState<T>) {
      navigator = context.state as ImplicitNavigatorState<T>;
    }
    if (root) {
      navigator =
          context.findRootAncestorStateOfType<ImplicitNavigatorState<T>>() ??
              navigator;
    } else {
      navigator ??=
          context.findAncestorStateOfType<ImplicitNavigatorState<T>>();
    }
    return navigator!;
  }

  @override
  ImplicitNavigatorState createState() => ImplicitNavigatorState<T>();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Key?>('key', key));
  }
}

class ImplicitNavigatorState<T> extends State<ImplicitNavigator<T>> {
  // This state is used by `ImplicitNavigatorBackButton` to tell if the back
  // button should be displayed.
  // It is static so that it can be accessed from any location in the widget
  // tree.
  static final ValueNotifier<bool> _displayBackButton = ValueNotifier(false);
  static late VoidCallback _backButtonOnPressed;

  ValueNotifier<T>? _valueNotifier;

  // Must be a reference and not a getter so that we can call it from `dispose`.
  late final ImplicitNavigatorState? _parent = isRoot
      ? null
      // Don't use `.of()` here as that'd just return `this`.
      : context.findAncestorStateOfType<ImplicitNavigatorState>();

  late final List<ValueHistoryEntry<T>> _stack;
  final Set<ImplicitNavigatorState> _children = {};

  /// The history of values and depths for this implicit navigator.
  List<ValueHistoryEntry<T>> get history => List.from(_stack);

  /// Whether or not this implciit navigator has seen any previous values that
  /// it can pop to.
  bool get canPop {
    return _stack.length > 1;
  }

  /// Whether or not this implicit navigator or any implicit navigators below it
  /// can pop.
  bool get treeCanPop {
    return navigatorTree
        .expand((navigators) => navigators)
        .any((navigator) => navigator.canPop);
  }

  /// Whether or not this value is below any other implicit navigators in the
  /// widget tree.
  bool get isRoot {
    return context.findAncestorStateOfType<ImplicitNavigatorState>() == null;
  }

  /// The nearest ancestor implicit navigator, if any.
  ImplicitNavigatorState<Object?>? get parent => _parent;

  /// All implicit navigators directly below this one in the widget tree.
  List<ImplicitNavigatorState<Object?>> get children =>
      _children.toList(growable: false);

  /// A tree of this implicit navigator and all active (see [isActive]) value
  /// navigators currently in the widget tree below it.
  List<List<ImplicitNavigatorState<Object?>>> get navigatorTree {
    if (!isActive) {
      // This navigator is currently disabled or in an inactive page route. It
      // is technically in the widget tree, but it's
      return [];
    }
    return [
      [this],
      ..._children.expand((child) => child.navigatorTree),
    ];
  }

  bool _disabled = false;

  /// Set this implicit navigator and all those below it to ignore attempts to
  /// pop (including from the system back button).
  ///
  /// Disable a implicit navigator if you wish to take it off stage and as such
  /// do not want it intercepting calls to pop. eg if you have an implicit
  /// navigator inside of a [PageView], you would not want it popping while it
  /// is not on screen.
  void disablePop() {
    if (!_disabled) {
      _disabled = true;
      _updateDisplayBackButton();
    }
  }

  /// If this implicit navigator is currently disabled, enable it.
  void enablePop() {
    if (_disabled) {
      _disabled = false;
      _updateDisplayBackButton();
    }
  }

  /// Whether or not this implicit navigator is enabled AND is currently at the
  /// top of all parent implicit navigator's history stacks.
  bool get isActive {
    return !_disabled &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        (isRoot || parent!.isActive);
  }

  /// Attempt to pop from any implicit navigators in this navigator's
  /// [navigatorTree].
  ///
  /// Navigators are tested in reverse level order-the most nested navigators
  /// attempt to pop first. Returns true if popping is successful.
  /// If two or more navigators are at the same level, they are tested in order
  /// of their [popPriority]: least to greatest followed by null.
  bool popFromTree() {
    return navigatorTree.reversed
        .expand(_prioritySorted)
        // `any` short circuits when it finds a true element so this will stop
        // calling pop if any call to pop succeeds.
        .any((navigator) => navigator.pop());
  }

  /// Attempt to pop from this navigator.
  ///
  /// Returns true if the pop was successful. Usually this function should not
  /// be called directly and [popFromTree] should be used instead.
  bool pop() {
    if (_stack.length == 1 || !isActive) {
      return false;
    }
    setState(() {
      final T poppedValue = _popEntry();
      if (_valueNotifier != null) {
        // Roll back the value notifier's value. This will trigger `_onChanged`,
        // but it won't do anything because `_latestEntry` and `_stack.last`
        // will be in sync.
        _valueNotifier!.value = _stack.last.value;
      }
      widget.onPop?.call(poppedValue, _stack.last.value);
    });
    return true;
  }

  @override
  void initState() {
    _maybeInitNotifier();
    final ValueHistoryEntry<T> newEntry = _latestEntry;
    if (isRoot) {
      _backButtonOnPressed = popFromTree;
    }
    _parent?._registerChild(this);
    final dynamic cachedStack = PageStorage.of(context)!.readState(context);
    if (widget.key is PageStorageKey &&
        cachedStack is List<ValueHistoryEntry<T>>) {
      _stack = cachedStack;
    } else if (widget.initialHistory != null) {
      _stack = widget.initialHistory!;
      // Ensure initial history gets cached.
      PageStorage.of(context)!.writeState(context, _stack);
    } else {
      _stack = [newEntry];
    }
    // We need to check if the current value is distinct from the last
    // cached value.
    _addIfNew(newEntry);
    // Ensure this is called even if `addIfNew` did not call it.
    WidgetsBinding.instance!.addPostFrameCallback((_) {
      _updateDisplayBackButton();
    });
    super.initState();
  }

  @override
  void didUpdateWidget(covariant ImplicitNavigator<T> oldWidget) {
    if (_valueNotifier != oldWidget._valueNotifier) {
      _maybeDisposeNotifier();
      _maybeInitNotifier();
    }
    _onChanged();
    super.didUpdateWidget(oldWidget);
  }

  void _maybeInitNotifier() {
    _valueNotifier = widget._valueNotifier;
    _valueNotifier?.addListener(_onChanged);
  }

  void _maybeDisposeNotifier() {
    _valueNotifier?.removeListener(_onChanged);
  }

  void _onChanged() {
    final bool didAdd = _addIfNew(_latestEntry);
    if (didAdd) {
      setState(() {});
    }
  }

  bool _addIfNew(ValueHistoryEntry<T> newEntry) {
    if (newEntry.value != _stack.last.value ||
        newEntry.depth != _stack.last.depth) {
      _pushEntry(newEntry);
      return true;
    }
    return false;
  }

  @override
  void dispose() {
    _maybeDisposeNotifier();
    _parent?._removeChild(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PageStorageBucket parentBucket = PageStorage.of(context)!;
    final Widget internalNavigator = Navigator(
      pages: _stack.map((stackEntry) {
        return ImplicitNavigatorPage<T>(
          // Bypass the page route's internal bucket so that we share state
          // across pages.
          bucket: parentBucket,
          key: ValueKey(stackEntry),
          value: stackEntry.value,
          builder: widget.builder,
          transitionsBuilder: widget.transitionsBuilder,
          transitionDuration: widget.transitionDuration,
          maintainState: widget.maintainState,
          opaque: widget.opaque,
        );
      }).toList(),
      onPopPage: (route, dynamic result) {
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

  ValueHistoryEntry<T> get _latestEntry {
    if (_valueNotifier != null) {
      return ValueHistoryEntry(
        widget._getDepth?.call(_valueNotifier!.value),
        _valueNotifier!.value,
      );
    }
    return ValueHistoryEntry(widget.depth, widget.value);
  }

  void _registerChild(ImplicitNavigatorState child) => _children.add(child);

  void _removeChild(ImplicitNavigatorState child) => _children.remove(child);

  void _pushEntry(ValueHistoryEntry<T> newEntry) {
    final ValueHistoryEntry<T> prevEntry = _stack.last;
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
      _updateDisplayBackButton();
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
      _updateDisplayBackButton();
      PopNotification<T>(
        currentValue: _stack.last.value,
        currentDepth: _stack.last.depth,
        previousValue: poppedEntry.value,
        previousDepth: poppedEntry.depth,
      ).dispatch(context);
    });
    return poppedEntry.value;
  }

  void _updateDisplayBackButton() {
    ImplicitNavigatorState._displayBackButton.value =
        ImplicitNavigator.of<dynamic>(context, root: true).treeCanPop;
  }

  List<ImplicitNavigatorState> _prioritySorted(
    List<ImplicitNavigatorState> navigators,
  ) {
    return List.from(navigators)
      ..sort((ImplicitNavigatorState a, ImplicitNavigatorState b) {
        if (a.widget.popPriority == null) {
          return 1;
        }
        if (b.widget.popPriority == null) {
          return -1;
        }
        return a.widget.popPriority!.compareTo(b.widget.popPriority!);
      });
  }
}

/// A function that builds a widget from a value and two animations.
///
/// It's arguments are a union of [ValueWidgetBuilder] and
/// [ModalRoute.buildPage].
///
/// Use the animation arguments if you want to animate sub-widgets within the
/// builder independently. To animate the entire builder in and out together,
/// use [routeTransitionsBuilder].
typedef AnimatedValueWidgetBuilder<T> = Widget Function(
  BuildContext context,
  T value,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
);

class ImplicitNavigatorBackButton extends StatelessWidget {
  const ImplicitNavigatorBackButton({
    this.transitionDuration = const Duration(milliseconds: 100),
    Key? key,
  }) : super(key: key);

  final Duration transitionDuration;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ImplicitNavigatorState._displayBackButton,
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
        onPressed: () => ImplicitNavigatorState._backButtonOnPressed(),
      ),
    );
  }
}

@immutable
class ValueHistoryEntry<T> {
  const ValueHistoryEntry(this.depth, this.value);

  final int? depth;
  final T value;

  @override
  String toString() {
    return '{\'depth\': $depth, \'value:\': $value}';
  }
}
