import 'package:flutter/widgets.dart';

import 'implicit_navigator.dart';

class ImplicitNavigatorPage<T> extends Page<T> {
  ImplicitNavigatorPage({
    required this.bucket,
    required this.value,
    required this.builder,
    this.transitionsBuilder,
    required this.transitionDuration,
    required this.maintainState,
    required this.opaque,
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
  final AnimatedValueWidgetBuilder<T> builder;
  final RouteTransitionsBuilder? transitionsBuilder;

  final Duration transitionDuration;
  final bool maintainState;
  final bool opaque;

  final PageStorageBucket bucket;

  @override
  Route<T> createRoute(BuildContext context) {
    return _ImplicitNavigatorRoute(this);
  }
}

class _ImplicitNavigatorRoute<T> extends ModalRoute<T> {
  _ImplicitNavigatorRoute(this._page);

  ImplicitNavigatorPage<T> _page;

  @override
  RouteSettings get settings => _page;

  @override
  Widget buildPage(
      BuildContext context,
      Animation<double> animation,
      Animation<double> secondaryAnimation,
      ) {
    // We intentionally pass the parent bucket through here so that separate
    // implicit navigator pages can share page storage state.
    return PageStorage(
      bucket: _page.bucket,
      child: _page.builder(context, _page.value, animation, secondaryAnimation),
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