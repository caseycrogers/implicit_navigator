import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:implicit_navigator/implicit_navigator.dart';

void main() {
  runApp(MyApp());
}

// Global state is bad. Don't do this. I'm only doing it because this is a demo
// app.
bool _appStyleNavigation = true;
int _lastAppStyleIndex = 0;
int _lastBrowserStyleIndex = 0;
// These string are displayed as the app bar title. We have to manually
// construct the initial values because the app bar will be built before the
// implicit navigators.
late String _appStackString = 'home > null';
late String _browserStackString = 'home > null';

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StatefulBuilder(
      builder: (context, setState) {
        return MaterialApp(
          title: 'Implicit Navigator Demo',
          theme: ThemeData(
            primarySwatch: _appStyleNavigation ? Colors.blue : Colors.red,
          ),
          home: DefaultTabController(
            // This is here to force independent builds of this part of the
            // widget tree when the navigation style is toggled.
            key: PageStorageKey('$_appStyleNavigation'),
            // Default tab controller won't restore itself from page storage so
            // we manually restore it here.
            initialIndex: _appStyleNavigation
                ? _lastAppStyleIndex
                : _lastBrowserStyleIndex,
            length: 3,
            child: MyHomePage(
              rebuildParent: () => setState(() {}),
            ),
          ),
        );
      },
    );
  }
}

/// An example app that uses [ImplicitNavigator] to create a two-level nested
/// navigation flow.
class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.rebuildParent}) : super(key: key);

  final VoidCallback rebuildParent;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ValueNotifier<int?> _currAnimalIndex = ValueNotifier(null);
  final ValueNotifier<Color?> _currColor = ValueNotifier(null);

  bool _isInitialized = false;
  late final TabController _tabController = DefaultTabController.of(context)!;

  void _increment() {
    if (_tabIndex == 0) {
      _currAnimalIndex.value = (_currAnimalIndex.value ?? -1) + 1;
      return;
    } else if (_tabIndex == 1) {
      final int newIndex = (ColorWidget.colors.indexWhere(
                  (entry) => entry.value == (_currColor.value ?? 0)) +
              1) %
          ColorWidget.colors.length;
      _currColor.value = ColorWidget.colors[newIndex].value;
    }
  }

  @override
  void didChangeDependencies() {
    if (!_isInitialized) {
      _isInitialized = true;
      _tabController.addListener(_onTabChanged);
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    super.dispose();
  }

  late ImplicitNavigatorState _rootNavigator;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ImplicitNavigatorNotification>(
      onNotification: (notification) {
        // We can listen on notifications from Implicit Navigator. Here we
        // update a string representation of the current screen whenever a new
        // notification comes in.
        setState(() {
          if (_appStyleNavigation) {
            _appStackString = _navigatorTreeString;
          } else {
            _browserStackString = _navigatorTreeString;
          }
        });
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const ImplicitNavigatorBackButton(),
          title: Text(
            _appStyleNavigation ? _appStackString : _browserStackString,
          ),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pets)),
              Tab(icon: Icon(Icons.color_lens)),
              Tab(icon: Icon(Icons.info)),
            ],
          ),
        ),
        body: Column(
          children: [
            _navigationStyleSelector,
            Expanded(
              child: ImplicitNavigator<int>(
                key: _appStyleNavigation
                    ? const PageStorageKey('tab_navigator')
                    : const ValueKey('tab_navigator'),
                value: _tabIndex,
                // Always set depth to null for browser style navigation.
                depth: _appStyleNavigation ? _tabIndexDepth(_tabIndex) : null,
                onPop: (poppedIndex, newIndex) {
                  _tabIndex = newIndex;
                },
                builder: (context, value, animation, secondaryAnimation) {
                  // We can only get the root navigator from an interior
                  // context. Get a reference here so that the notification
                  // listener can access it.
                  _rootNavigator =
                      ImplicitNavigator.of<dynamic>(context, root: true);
                  if (value == 0) {
                    return ImplicitNavigator<int?>.fromNotifier(
                      // If you pass in a PageStorageKey, implicit navigator
                      // will share value history across all instances with the
                      // same page storage.
                      // This means that the animal navigator will retain its
                      // history when you navigate to another tab and then
                      // navigate back. This is usually desired for app style
                      // navigation.
                      key: _appStyleNavigation
                          ? const PageStorageKey('animal_navigator')
                          : const ValueKey('animal_navigator'),
                      valueNotifier: _currAnimalIndex,
                      getDepth: _appStyleNavigation ? _animalIndexDepth : null,
                      builder: (context, animalIndex, animation,
                          secondaryAnimation) {
                        if (animalIndex == null) {
                          return const Text(
                            'Press the floating action button to select an'
                            ' animal!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 36),
                          );
                        }
                        return AnimalWidget(
                          value: animalIndex,
                          animation: animation,
                          secondaryAnimation: secondaryAnimation,
                        );
                      },
                    );
                  }
                  if (value == 1) {
                    return ImplicitNavigator<Color?>.fromNotifier(
                        key: _appStyleNavigation
                            ? const PageStorageKey('color_navigator')
                            : const ValueKey('color_navigator'),
                        valueNotifier: _currColor,
                        getDepth: _appStyleNavigation ? _colorDepth : null,
                        builder: (
                          context,
                          color,
                          animation,
                          secondaryAnimation,
                        ) {
                          if (color == null) {
                            return const Text(
                              'Press the floating action button to select a '
                              'color!',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 36),
                            );
                          }
                          return ColorWidget(color: color);
                        },
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                              opacity: animation, child: child);
                        });
                  }
                  return const Center(
                    child: Text(
                      'This is a demo of `ImplicitNavigator`!',
                      style: TextStyle(fontSize: 24),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: _tabIndex != 2
            ? FloatingActionButton(
                onPressed: _increment,
                tooltip: 'Increment',
                child: const Icon(Icons.navigate_next),
              )
            : null,
      ),
    );
  }

  int get _tabIndex => _tabController.index;

  set _tabIndex(int newValue) => _tabController.index = newValue;

  String get _navigatorTreeString {
    return _rootNavigator.navigatorTree
        .map((navigators) => navigators.single)
        .expand((navigator) {
      return navigator.history.map((entry) {
        if (entry.value == null) {
          return 'null';
        }
        if ((navigator.widget.key as ValueKey).value == 'animal_navigator') {
          // Display the text for the current animal.
          return AnimalWidget
              .animals[(entry.value as int) % AnimalWidget.animals.length]
              .split(' ')
              .last;
        }
        if ((navigator.widget.key as ValueKey).value == 'color_navigator') {
          // Display the text for the current color.
          return ColorWidget.colors
              .firstWhere((colorEntry) => colorEntry.value == entry.value)
              .key;
        }
        if ((navigator.widget.key as ValueKey).value == 'tab_navigator') {
          // Display the text for the current tab index.
          return ['animals', 'colors', 'info'][entry.value as int];
        }
        throw AssertionError(
          'Navigator with an unrecognized key ${navigator.widget.key}.',
        );
      });
    }).join(' > ');
  }

  // The 0th tab is the home tab so it has a depth of 0. In app style
  // navigation, the back button goes to the home tab, not the previous tab so
  // we return a depth of 1 if this index isn't the home tab.
  int? _tabIndexDepth(int index) {
    return index == 0 ? 0 : 1;
  }

  int _animalIndexDepth(int? animalIndex) {
    return animalIndex == null ? 0 : 1;
  }

  int _colorDepth(Color? color) {
    return color == null ? 0 : 1;
  }

  void _onTabChanged() {
    if (_appStyleNavigation) {
      _lastAppStyleIndex = _tabIndex;
    } else {
      _lastBrowserStyleIndex = _tabIndex;
    }
    setState(() {});
  }

  Widget get _navigationStyleSelector {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      color: Theme.of(context).accentColor.withAlpha(150),
      child: InkWell(
        onTap: _onStyleToggled,
        child: Row(
          children: [
            const Text(
              'Navigation Style: ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text('App', style: TextStyle(fontSize: 18)),
            Switch(
              value: !_appStyleNavigation,
              onChanged: (_) {
                _onStyleToggled();
              },
              activeColor: Colors.white30,
              activeTrackColor: Colors.black38,
              inactiveThumbColor: Colors.white30,
              inactiveTrackColor: Colors.black38,
            ),
            const Text('Browser', style: TextStyle(fontSize: 18)),
          ],
        ),
      ),
    );
  }

  void _onStyleToggled() {
    // Change the style and rebuild the widget tree.
    _appStyleNavigation = !_appStyleNavigation;
    widget.rebuildParent();
  }
}

class AnimalWidget extends StatelessWidget {
  const AnimalWidget({
    Key? key,
    required this.value,
    required this.animation,
    required this.secondaryAnimation,
  }) : super(key: key);

  static const List<String> animals = [
    'gregarious goat',
    'optimistic octopus',
    'crazy cat',
    'mean monkey',
    'lecherous lemur',
    'fast fish',
    'dead dodo',
    'small sparrow',
  ];

  final int value;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;

  @override
  Widget build(BuildContext context) {
    final String color = animals[value % animals.length].split(' ').first;
    final String animal = animals[value % animals.length].split(' ').last;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SlideInOut(
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: Center(
            child: Text(
              color,
              style: const TextStyle(fontSize: 36),
            ),
          ),
        ),
        SlideInOut(
          incoming: const Offset(-1, 0),
          outgoing: const Offset(1, 0),
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: Center(
            child: Text(
              animal,
              style: const TextStyle(fontSize: 36),
            ),
          ),
        ),
      ],
    );
  }
}

class ColorWidget extends StatelessWidget {
  const ColorWidget({Key? key, required this.color}) : super(key: key);

  static final List<MapEntry<String, Color>> colors = {
    'red': Colors.red,
    'purple': Colors.purple,
    'blue': Colors.blue,
    'green': Colors.green,
    'yellow': Colors.yellow,
    'orange': Colors.orange,
  }.entries.toList(growable: false);

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(color: color);
  }
}

class SlideInOut extends StatelessWidget {
  const SlideInOut({
    Key? key,
    required this.child,
    required this.animation,
    required this.secondaryAnimation,
    this.incoming = const Offset(1, 0),
    this.outgoing = const Offset(-1, 0),
  }) : super(key: key);

  final Widget child;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Offset incoming;
  final Offset outgoing;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: Offset.zero,
        end: outgoing,
      ).animate(secondaryAnimation),
      child: SlideTransition(
        position: Tween<Offset>(
          begin: incoming,
          end: Offset.zero,
        ).animate(animation),
        child: child,
      ),
    );
  }
}
