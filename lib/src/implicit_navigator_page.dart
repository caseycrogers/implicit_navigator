import 'package:flutter/material.dart';

import 'implicit_navigator.dart';

class ImplicitNavigatorPage<T> extends Page<T> {
  const ImplicitNavigatorPage({
    required this.bucket,
    required this.value,
    required this.builder,
    this.transitionsBuilder,
    required this.transitionDuration,
    required this.maintainState,
    required this.opaque,
    required this.takeFocus,
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
  final ImplicitPageBuilder<T> builder;
  final RouteTransitionsBuilder? transitionsBuilder;

  final Duration transitionDuration;
  final bool takeFocus;
  final bool maintainState;
  final bool opaque;

  final PageStorageBucket bucket;

  @override
  Route<T> createRoute(BuildContext context) {
    return _ImplicitNavigatorRoute(this);
  }
}

class _ImplicitNavigatorRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T> {
  _ImplicitNavigatorRoute(this._page);

  final ImplicitNavigatorPage<T> _page;

  @override
  RouteSettings get settings => _page;

  @override
  Widget buildContent(BuildContext context) {
    // We intentionally pass the parent bucket through here so that separate
    // implicit navigator pages can share page storage state.
    return PageStorage(
      bucket: _page.bucket,
      child: _page.builder(context, _page.value),
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
  bool get barrierDismissible => false;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get opaque => _page.opaque;

  @override
  Duration get transitionDuration => _page.transitionDuration;

  // These are garbage workarounds to try to prevent the route from taking
  // focus when takeFocus is false.
  // See: https://github.com/flutter/flutter/issues/53441.
  @override
  TickerFuture didPush() {
    navigator!.focusNode.canRequestFocus = false;
    final ret = super.didPush();
    // Could have a race condition because ret is just waiting on ticker future,
    // NOT waiting on it's callback on top of ticker future.
    // This code assumes that callbacks are called in FIFO order, this may not
    // be a valid assumption.
    ret.whenComplete(() {
      navigator!.focusNode.canRequestFocus = true;
    }); // focusNode.requestFocus());
    return ret;
  }

  @override
  void didAdd() {
    navigator!.focusNode.canRequestFocus = false;
    super.didAdd();
    // This probably has a race condition with `TransitionRoute.didAdd`. I don't
    // think there's a way around it because the former is waiting on an
    // internal future that I have no access to.
    TickerFuture.complete().then((value) {
      return navigator!.focusNode.canRequestFocus = true;
    });
  }
}

/// Builds the pages for [ImplicitNavigator].
typedef ImplicitPageBuilder<T> = Widget Function(BuildContext context, T value);
