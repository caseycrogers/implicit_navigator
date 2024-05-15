import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'implicit_navigator_page.dart';
import 'navigator_notification.dart';

/// Pushes and pops pages from an internal navigator in response to changing app
/// state.
///
/// When [ImplicitNavigator] is rebuilt with a new [value] and/or [depth], a new
/// page is pushed onto the navigator stack and [builder] is called with the
/// latest [value]. When [popFromTree] is called or the system back button is
/// pressed, [ImplicitNavigator] attempts to pop from any navigator in the tree,
/// starting with deepest nested navigator first and breaking ties between
/// equally deep navigators with [popPriority].
///
/// Implicit Navigator can be used to produce two distinct navigation patterns:
///  - App-Style: the back button/pop goes "up" a developer defined navigation
///    hierarchy, potentially undoing multiple state changes at once.
///    App-style is typical for most modern smartphone apps.
///  - Browser-Style: the back button/pop reverts the last state change.
///    Browser-style is how most web pages behave.
///
/// For app-style navigation, specify non-null values for [depth] to set your
/// app's navigation hierarchy. Additionally, set [maintainHistory] to true and
/// provide a `PageStorageKey` to any [ImplicitNavigator] nested inside of
/// another [ImplicitNavigator].
/// This ensures that the history of the inner navigator is maintained when the
/// user navigates away form it and then back to it.
///
/// For browser-style navigation, simply leave [depth] null and do not provide
/// a `PageStorageKey` to any nested [ImplicitNavigator]'s.
///
/// The following code implements a trivial browser-style Implicit Navigator:
/// ```dart
/// int _index = 0;
///
/// @override
/// Widget build(BuildContext context) {
///   return ImplicitNavigator<int>(
///     value: _index,
///     builder: (context, index) {
///       return TextButton(
///         onPressed: () => setState(() {
///           _index += 1;
///         }),
///         onLongPress: () => ImplicitNavigator.of(context).popFromTree()
///         child: Text(index.toString()),
///       );
///     },
///     onPop: (poppedValue, valueAfterPop) => _index = valueAfterPop,
///   );
/// }
/// ```
class ImplicitNavigator<T> extends StatefulWidget {
  /// Create an implicit navigator directly from a value.
  ///
  /// Like many widgets in the Flutter framework, [ImplicitNavigator] expects
  /// that [value] will not be mutated after it has been passed in here.
  /// Directly modifying [value] will result in incorrect behaviors. Whenever
  /// you wish to modify the value, a new object should be provided.
  ///
  /// Generally, [ImplicitNavigator.fromValueNotifier] or
  /// [ImplicitNavigator.selectFromListenable] are simpler and should be used
  /// over this constructor.
  ///
  /// To ensue [value] is updated when a page is popped, update it in [onPop]:
  ///
  /// ```
  ///   value: myValue,
  ///   onPop: (poppedValue, valueAfterPop) {
  ///     myValue = valueAfterPop;
  ///   },
  /// ```
  const ImplicitNavigator({
    Key? key,
    this.maintainHistory = false,
    required this.value,
    this.depth,
    this.initialHistory,
    required this.builder,
    this.transitionsBuilder = defaultRouteTransitionsBuilder,
    this.transitionDuration = _kDefaultTransitionDuration,
    required this.onPop,
    this.takeFocus = false,
    this.maintainState = true,
    this.opaque = true,
    this.popPriority,
    this.observers = const [],
  }) : super(key: key);

  /// Creates an [ImplicitNavigator] that pushes new pages when a value selected
  /// from a [listenable] changes.
  ///
  /// A [selector] function is used to pick a value from [listenable]. If the
  /// listenable changes but [selector] returns the same value, no new
  /// pages are pushed.
  ///
  /// For example, the following creates a navigator that pushes and pops pages
  /// as a tab controller changes tabs:
  ///
  /// ```dart
  /// return ImplicitNavigator.selectFromListenable<ScrollController, double>(
  ///   listenable: myTabController,
  ///   selector: () => myTabController.index,
  ///   builder (context, tabIndex) {
  ///     return MyTabPage(index: tabIndex);
  ///   },
  ///   onPop: (poppedIndex, indexAfterPop) {
  ///     myTabController.index = indexAfterPop;
  ///   },
  /// );
  /// ```
  ///
  /// If non-null, [getDepth] will be called on each value and used to set
  /// [ImplicitNavigator.depth]. [getDepth] MUST return the same depth for a
  /// given value every time it's called on that value. If it returns
  /// inconsistent depths, [ImplicitNavigator] may push redundant pages and will
  /// not pop pages properly.
  static Widget selectFromListenable<U extends Listenable, T>({
    Key? key,
    bool maintainHistory = false,
    required U listenable,
    required T Function() selector,
    int? Function(T value)? getDepth,
    List<ValueHistoryEntry<T>>? initialHistory,
    required ImplicitPageBuilder<T> builder,
    RouteTransitionsBuilder transitionsBuilder = defaultRouteTransitionsBuilder,
    Duration transitionDuration = _kDefaultTransitionDuration,
    required void Function(T, T) onPop,
    bool takeFocus = false,
    bool maintainState = true,
    bool opaque = true,
    int? popPriority,
    final List<NavigatorObserver> observers = const [],
  }) {
    // Animated builder is actually just a misnamed `ListenableBuilder`.
    return AnimatedBuilder(
      key: key,
      animation: listenable,
      builder: (context, child) {
        return ImplicitNavigator<T>(
          maintainHistory: maintainHistory,
          value: selector(),
          depth: getDepth?.call(selector()),
          initialHistory: initialHistory,
          builder: builder,
          transitionsBuilder: transitionsBuilder,
          transitionDuration: transitionDuration,
          onPop: onPop,
          takeFocus: takeFocus,
          maintainState: maintainState,
          opaque: opaque,
          popPriority: popPriority,
          observers: observers,
        );
      },
    );
  }

  /// Creates an [ImplicitNavigator] that pushes new pages when the
  /// [valueListenable] changes and calls [onPop] when pages are popped.
  ///
  /// This is a convenience method on top of [selectFromListenable].
  ///
  /// If non-null, [getDepth] will be called on each value and used to set
  /// [ImplicitNavigator.depth]. [getDepth] MUST return the same depth for a
  /// given value every time it's called on that value. If it returns
  /// inconsistent depths, [ImplicitNavigator] may push redundant pages and will
  /// not pop pages properly.
  static Widget fromValueListenable<T>({
    Key? key,
    bool maintainHistory = false,
    required ValueListenable<T> valueListenable,
    int? Function(T value)? getDepth,
    List<ValueHistoryEntry<T>>? initialHistory,
    required ImplicitPageBuilder<T> builder,
    RouteTransitionsBuilder transitionsBuilder = defaultRouteTransitionsBuilder,
    Duration transitionDuration = _kDefaultTransitionDuration,
    required void Function(T, T) onPop,
    bool takeFocus = false,
    bool maintainState = true,
    bool opaque = true,
    int? popPriority,
    final List<NavigatorObserver> observers = const [],
  }) {
    return selectFromListenable<ValueListenable<T>, T>(
      key: key,
      maintainHistory: maintainHistory,
      listenable: valueListenable,
      selector: () => valueListenable.value,
      getDepth: getDepth,
      initialHistory: initialHistory,
      builder: builder,
      transitionsBuilder: transitionsBuilder,
      transitionDuration: transitionDuration,
      onPop: onPop,
      takeFocus: takeFocus,
      maintainState: maintainState,
      opaque: opaque,
      popPriority: popPriority,
      observers: observers,
    );
  }

  /// Creates an [ImplicitNavigator] that pushes new pages when the
  /// [valueNotifier] changes and reverts [valueNotifier.value] when pages are
  /// popped.
  ///
  /// If non-null, [getDepth] will be called on each value and used to set
  /// [ImplicitNavigator.depth]. [getDepth] MUST return the same depth for a
  /// given value every time it's called on that value. If it returns
  /// inconsistent depths, [ImplicitNavigator] may push redundant pages and will
  /// not pop pages properly.
  static Widget fromValueNotifier<T>({
    Key? key,
    bool maintainHistory = false,
    required ValueNotifier<T> valueNotifier,
    int? Function(T value)? getDepth,
    List<ValueHistoryEntry<T>>? initialHistory,
    required ImplicitPageBuilder<T> builder,
    RouteTransitionsBuilder transitionsBuilder = defaultRouteTransitionsBuilder,
    Duration transitionDuration = _kDefaultTransitionDuration,
    void Function(T, T)? onPop,
    bool takeFocus = false,
    bool maintainState = true,
    bool opaque = true,
    int? popPriority,
    final List<NavigatorObserver> observers = const [],
  }) {
    return ValueListenableBuilder<T>(
      key: key,
      valueListenable: valueNotifier,
      builder: (context, value, child) {
        return ImplicitNavigator<T>(
          maintainHistory: maintainHistory,
          value: valueNotifier.value,
          depth: getDepth?.call(value),
          initialHistory: initialHistory,
          builder: builder,
          transitionsBuilder: transitionsBuilder,
          transitionDuration: transitionDuration,
          onPop: (poppedValue, valueAfterPop) {
            valueNotifier.value = valueAfterPop;
            onPop?.call(poppedValue, valueAfterPop);
          },
          takeFocus: takeFocus,
          maintainState: maintainState,
          opaque: opaque,
          popPriority: popPriority,
          observers: observers,
        );
      },
    );
  }

  /// The default [RouteTransitionsBuilder] used by [ImplicitNavigator] to
  /// animate content in and out.
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

  // This state is used by `ImplicitNavigatorBackButton` to tell if the back
  // button should be displayed.
  // It is static so that it can be accessed from any location in the widget
  // tree.
  static final ValueNotifier<bool> displayBackButton = ValueNotifier(false);

  /// A [RouteTransitionsBuilder] that uses the default transitions for the
  /// current platform.
  ///
  /// See [PageTransitionsTheme.buildTransitions].
  static Widget materialRouteTransitionsBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return Theme.of(context).pageTransitionsTheme.buildTransitions<dynamic>(
          ModalRoute.of(context) as PageRoute,
          context,
          animation,
          secondaryAnimation,
          child,
        );
  }

  static const Duration _kDefaultTransitionDuration =
      Duration(milliseconds: 100);

  /// Whether or not this widget should save and restore it's value history to
  /// page storage.
  ///
  /// If this is true, the page history of an inner nested navigator will be
  /// retained if the user navigates away from it and then back to it.
  ///
  /// This should typically be false for all browser style navigators and true
  /// for nested app style navigators.
  ///
  /// If [maintainHistory] is true, [key] should be set to a [PageStorageKey] to
  /// ensure that different nested implicit navigators don't overwrite each
  /// other's page storage.
  ///
  /// Also see [maintainState], which keeps pages in memory so that they aren't
  /// rebuilt when a page above is popped.
  final bool maintainHistory;

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
  /// If [maintainHistory] is true and a cached history stack is available at
  /// initialization, the cached stack will be used and [initialHistory] will
  /// be ignored.
  final List<ValueHistoryEntry<T>>? initialHistory;

  /// An animated build function that builds a widget from the given [value].
  ///
  /// Use the `animation` and `secondaryAnimation` arguments to independently
  /// animate widgets within the builder.
  final ImplicitPageBuilder<T> builder;

  /// A function for animating the widget returned by [builder] in and out.
  final RouteTransitionsBuilder transitionsBuilder;

  /// See [TransitionRoute.transitionDuration].
  final Duration transitionDuration;

  /// Whether or not new routes pushed to `ImplicitNavigator` should request
  /// focus as they're pushed.
  ///
  /// Unless your pages are fullscreen, you probably want to leave this false.
  final bool takeFocus;

  /// Whether or not a page should be restored with its original state or
  /// rebuilt when a page on top of it is popped.
  ///
  /// If an implicit navigator is nested within another navigator, setting this
  /// to false will mean the inner navigator loses its page history if the user
  /// navigates away from it and then presses back and returns to it.
  ///
  /// If [maintainHistory] is true, then an inner nested navigator will restore
  /// it's state even if [maintainState] is false.
  ///
  /// This should almost always be left as its the default value `true`.
  ///
  /// See [ModalRoute.maintainState].
  final bool maintainState;

  /// See [TransitionRoute.opaque].
  final bool opaque;

  /// A callback that runs immediately after a page is popped.
  ///
  /// The popped value is passed in as [poppedValue]. The new page value after
  /// popping is passed in as [valueAfterPop].
  ///
  /// Unless using [ImplicitNavigator.fromValueNotifier] which manages state for
  /// you, this function should be used to revert external state to
  /// [valueAfterPop]:
  ///
  /// ```dart
  ///   value: myValue,
  ///   onPop: (poppedValue, valueAfterPop) => myValue = valueAfterPop,
  /// ```
  final void Function(T poppedValue, T valueAfterPop) onPop;

  /// The priority of this widget when choosing which implicit navigator to pop
  /// from.
  ///
  /// A lower number corresponds to a higher priority.
  ///
  /// Implicit navigator always attempts to pop from the inner most navigators
  /// first, it'll only consider pop priority when deciding between two implicit
  /// navigators at the same depth in the [navigatorTree]-eg if two navigators
  /// are side by side in a [Row].
  final int? popPriority;

  /// See [Navigator.observers].
  final List<NavigatorObserver> observers;

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

/// The state object of an [ImplicitNavigatorState].
///
/// You can access this object by calling [ImplicitNavigator.of] from a
/// build context below the navigator you want to access.
///
/// The state object allows you to read and manipulate [ImplicitNavigator]'s
/// internal stack using [navigatorTree]/[history] and [popFromTree].
class ImplicitNavigatorState<T> extends State<ImplicitNavigator<T>> {
  static late VoidCallback _backButtonOnPressed;

  ValueNotifier<T>? _valueNotifier;

  // Must be a reference and not a getter so that we can call it from `dispose`.
  late final ImplicitNavigatorState? _parent = isRoot
      ? null
      // Don't use `.of()` here as that'd just return `this`.
      : context.findAncestorStateOfType<ImplicitNavigatorState>();

  late final List<ValueHistoryEntry<T>> _stack;
  final Set<ImplicitNavigatorState> _children = {};

  /// Whether or not this implicit navigator has seen any previous values that
  /// it can pop to.
  bool get shallowCanPop {
    return _stack.length > 1;
  }

  /// Whether or not this implicit navigator or any implicit navigators below it
  /// can pop.
  bool get canPop {
    return navigatorTree
        .expand((navigators) => navigators)
        .any((navigator) => navigator.shallowCanPop);
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

  /// A tree containing all active (see [isActive]) implicit navigators
  /// currently in the widget tree at or below this navigator.
  ///
  /// See [isActive].
  List<List<ImplicitNavigatorState<Object?>>> get navigatorTree {
    if (!isActive) {
      // This navigator is currently disabled or in an inactive page route.
      return [];
    }
    return [
      [this],
      ..._children.expand((child) => child.navigatorTree),
    ];
  }

  bool _isEnabled = true;

  /// Whether or not this implicit navigator and all those below it should
  /// ignore attempts to pop.
  bool get isEnabled => _isEnabled;

  /// Set whether or not this implicit navigator and all those below it should
  /// ignore attempts to pop (including from the system back button).
  ///
  /// Set [isEnabled] to false if you are taking this navigator off stage and do
  /// not want it intercepting calls to pop.
  set isEnabled(bool newValue) {
    if (_isEnabled != newValue) {
      _isEnabled = newValue;
      _onStackChanged();
    }
  }

  /// Whether or not this implicit navigator is enabled AND is currently at the
  /// top of all parent implicit navigator's history stacks.
  bool get isActive {
    return _isEnabled &&
        (ModalRoute.of(context)?.isCurrent ?? true) &&
        (isRoot || parent!.isActive);
  }

  /// Attempt to pop from any implicit navigators in this navigator's
  /// [navigatorTree].
  ///
  /// Navigators are tested in reverse level order-the most nested navigators
  /// attempt to pop first. Returns true if popping is successful.
  /// If two or more navigators are at the same level, they are tested in order
  /// of their pop priority: least to greatest followed by null.
  ///
  /// If [searchTree] is set to false, only this navigator will attempt to
  /// handle the pop.
  bool pop({bool searchTree = true}) {
    if (!searchTree) {
      return _pop();
    }
    return navigatorTree.reversed
        .expand(_prioritySorted)
        .any((navigator) => navigator._pop());
  }

  bool _pop() {
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
      widget.onPop(poppedValue, _stack.last.value);
    });
    return true;
  }

  @override
  void initState() {
    super.initState();
    final ValueHistoryEntry<T> newEntry = _latestEntry;
    if (isRoot) {
      _backButtonOnPressed = pop;
    }
    _parent?._registerChild(this);
    final PageStorageBucket? pageStorage = PageStorage.of(context);
    if (widget.maintainHistory) {
      assert(
        pageStorage != null,
        'Could not find a page storage bucket above this ImplicitNavigator.'
        ' Try wrapping this widget in a `MaterialApp` or `PageStorage` widget.',
      );
    }
    final dynamic cachedStack = pageStorage?.readState(context);
    if (cachedStack is List<ValueHistoryEntry<T>>) {
      _stack = cachedStack;
    } else if (widget.initialHistory != null &&
        widget.initialHistory!.isNotEmpty) {
      _stack = List.from(widget.initialHistory!);
      // Ensure initial history gets cached.
      pageStorage?.writeState(context, _stack);
    } else {
      _stack = [newEntry];
    }
    // We need to check if the current value is distinct from the last
    // cached value.
    _addIfNew(newEntry);
    // Ensure this is called even if `addIfNew` did not call it.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onStackChanged();
    });
  }

  @override
  void didUpdateWidget(covariant ImplicitNavigator<T> oldWidget) {
    _addIfNew(_latestEntry);
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _parent?._removeChild(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final PageStorageBucket parentBucket = PageStorage.of(context);
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
          takeFocus: widget.takeFocus,
          maintainState: widget.maintainState,
          opaque: widget.opaque,
        );
      }).toList(),
      onPopPage: (route, dynamic result) {
        if (!route.didPop(result)) {
          // Route handled the pop internally (eg via a will pop scope or
          // local history entry).
          return false;
        }
        final RouteSettings page = route.settings;
        if (page is ImplicitNavigatorPage<T>) {
          return _pop();
        }
        return true;
      },
      observers: widget.observers,
    );
    if (isRoot) {
      return WillPopScope(
        onWillPop: () async {
          return !pop();
        },
        child: internalNavigator,
      );
    }
    return internalNavigator;
  }

  ValueHistoryEntry<T> get _latestEntry {
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
    if (widget.maintainHistory) {
      PageStorage.of(context).writeState(context, _stack);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onStackChanged();
    });
    PushNotification<T>(
      valueAfterPop: newEntry.value,
      currentDepth: newEntry.depth,
      previousValue: prevEntry.value,
      previousDepth: prevEntry.depth,
    ).dispatch(context);
  }

  bool _addIfNew(ValueHistoryEntry<T> newEntry) {
    if (newEntry.value != _stack.last.value ||
        newEntry.depth != _stack.last.depth) {
      _pushEntry(newEntry);
      return true;
    }
    return false;
  }

  T _popEntry() {
    final ValueHistoryEntry<T> poppedEntry = _stack.removeLast();
    if (widget.maintainHistory) {
      PageStorage.of(context).writeState(context, _stack);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _onStackChanged();
    });
    PopNotification<T>(
      valueAfterPop: _stack.last.value,
      currentDepth: _stack.last.depth,
      previousValue: poppedEntry.value,
      previousDepth: poppedEntry.depth,
    ).dispatch(context);
    return poppedEntry.value;
  }

  void _onStackChanged() {
    if (!mounted) {
      // Don't update the back button if this navigator is disposed.
      // We need this check as `_onStackChanged` is called from a post frame
      // callback.
      return;
    }
    ImplicitNavigator.displayBackButton.value =
        ImplicitNavigator.of<dynamic>(context, root: true).canPop;
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

/// A back button that is only visible when an [ImplicitNavigator] has pages it
/// can pop.
///
/// Intended for use with [AppBar] to replace the default back button which is
/// only visible if the top most navigator can pop:
///
/// ```dart
/// int index = 0;
///
/// @override
/// Widget build(BuildContext context) {
///   return Scaffold(
///     appBar: AppBar(
///       leading: const ImplicitNavigatorBackButton(),
///     ),
///     body: ImplicitNavigator<int>(
///       value: index,
///       builder: (context, index, animation, secondaryAnimation) {
///         return Text(index.toString());
///       },
///     ),
///     floatingActionButton: FloatingActionButton(
///       child: const Icon(Icons.add),
///       onPressed: () {
///         setState(() {
///           index += 1;
///         });
///       },
///     ),
///   );
/// }
/// ```
class ImplicitNavigatorBackButton extends StatelessWidget {
  const ImplicitNavigatorBackButton({
    this.transitionDuration = const Duration(milliseconds: 100),
    Key? key,
  }) : super(key: key);

  /// How fast to animate the back button in and out.
  ///
  /// If the duration is zero, the back button will always be visible.
  final Duration transitionDuration;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      child: ValueListenableBuilder<bool>(
        valueListenable: ImplicitNavigator.displayBackButton,
        builder: (context, shouldDisplay, backButton) {
          if (transitionDuration == Duration.zero) {
            // Don't animate in and out if the transition duration is zero.
            return shouldDisplay ? backButton! : Container();
          }
          return AnimatedOpacity(
            duration: transitionDuration,
            opacity: shouldDisplay ?  1 : 0,
            child: AnimatedContainer(
              duration: transitionDuration,
              width: shouldDisplay ? kToolbarHeight : 0,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Transform.translate(
                    offset: Offset(
                      constraints.maxWidth - kToolbarHeight,
                      0,
                    ),
                    child: backButton!,
                  );
                },
              ),
            ),
          );
        },
        child: SizedBox(
          width: kToolbarHeight,
          child: BackButton(
            // Nested function call to avoid late initialization error.
            onPressed: () => ImplicitNavigatorState._backButtonOnPressed(),
          ),
        ),
      ),
    );
  }
}

/// An entry that stores [ImplicitNavigator.depth] and
/// [ImplicitNavigator.value].
///
/// History entries are used to restore [value] when a page is popped.
class ValueHistoryEntry<T> {
  const ValueHistoryEntry(this.depth, this.value);

  final int? depth;
  final T value;

  @override
  String toString() {
    return '{\'depth\': $depth, \'value:\': $value}';
  }
}
