import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:value_navigator/value_navigator.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: DefaultTabController(
        length: 3,
        child: MyHomePage(),
      ),
    );
  }
}

/// An example app that uses [ValueNavigator] to create a two-level nested
/// navigation flow.
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final ValueNotifier<int> _currAnimalIndex = ValueNotifier(0);
  final ValueNotifier<Color> _currColor =
      ValueNotifier(ColorWidget.colors.first.value);

  VoidCallback? _tabListener;

  void _increment() {
    if (_tabIndex == 0) {
      _currAnimalIndex.value = _currAnimalIndex.value + 1;
      return;
    } else if (_tabIndex == 1) {
      final int newIndex = (ColorWidget.colors
                  .indexWhere((entry) => entry.value == _currColor.value) +
              1) %
          ColorWidget.colors.length;
      _currColor.value = ColorWidget.colors[newIndex].value;
    }
  }

  @override
  void didChangeDependencies() {
    if (_tabListener == null) {
      _tabListener = () => setState(() {});
      DefaultTabController.of(context)!.addListener(_tabListener!);
    }
    super.didChangeDependencies();
  }

  // Manually construct the initial value.
  late String _navigatorStackString =
      '$_tabIndex > ${AnimalWidget.animals[_currAnimalIndex.value]}';

  late ValueNavigatorState _rootNavigator;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ValueNavigatorNotification>(
      onNotification: (notification) {
        // We can listen on notifications from Value Navigator. Here we
        // update a string representation of the current screen whenever a new
        // notification comes in.
        setState(() {
          _navigatorStackString = _navigatorTreeString;
        });
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          leading: ValueNavigatorBackButton(),
          title: Text(_navigatorStackString),
          bottom: TabBar(
            tabs: [
              Tab(icon: Icon(Icons.pets)),
              Tab(icon: Icon(Icons.color_lens)),
              Tab(icon: Icon(Icons.info)),
            ],
          ),
        ),
        body: ValueNavigator<int>(
          key: ValueKey('tab_navigator'),
          value: _tabIndex,
          // Back button should always return to index 0.
          depth: _tabIndex == 0 ? 0 : 1,
          onPop: (poppedIndex, newIndex) {
            _tabIndex = newIndex;
          },
          builder: (context, value, animation, secondaryAnimation) {
            // We can only get the root navigator from an interior context. Get
            // a reference here so that the notification listener can access it.
            _rootNavigator = ValueNavigator.of(context, root: true);
            if (value == 0) {
              return ValueNavigator<int>.fromNotifier(
                // If you pass in a PageStorageKey, ValueNavigator will share
                // value history across all instances with the same page
                // storage.
                // This means that the animal navigator will retain its history
                // when you navigate to another tab and then navigate back.
                // If each new instance should have new history, use a value key
                // or null here instead.
                key: PageStorageKey('animal_navigator'),
                valueNotifier: _currAnimalIndex,
                builder: (context, animalIndex, animation, secondaryAnimation) {
                  return AnimalWidget(
                    value: animalIndex,
                    animation: animation,
                    secondaryAnimation: secondaryAnimation,
                  );
                },
              );
            }
            if (value == 1) {
              return ValueNavigator<Color>.fromNotifier(
                  key: PageStorageKey('color_navigator'),
                  valueNotifier: _currColor,
                  builder: (
                    context,
                    color,
                    animation,
                    secondaryAnimation,
                  ) {
                    return ColorWidget(color: color);
                  },
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) {
                    return FadeTransition(opacity: animation, child: child);
                  });
            }
            return Center(
              child: Text(
                'This is a demo of `ValueNavigator`!',
                style: TextStyle(fontSize: 24),
              ),
            );
          },
        ),
        floatingActionButton: _tabIndex != 2
            ? FloatingActionButton(
                onPressed: _increment,
                tooltip: 'Increment',
                child: Icon(Icons.navigate_next),
              )
            : null,
      ),
    );
  }

  int get _tabIndex => DefaultTabController.of(context)!.index;

  set _tabIndex(int newValue) =>
      DefaultTabController.of(context)!.index = newValue;

  String get _navigatorTreeString {
    return _rootNavigator.navigatorTree
        .map((navigators) => navigators.single)
        .expand((navigator) {
      return navigator.history.map((value) {
        if ((navigator.widget.key as ValueKey).value == 'animal_navigator') {
          return AnimalWidget
              .animals[(value as int) % AnimalWidget.animals.length];
        }
        if ((navigator.widget.key as ValueKey).value == 'color_navigator') {
          return ColorWidget.colors
              .firstWhere((entry) => entry.value == value)
              .key;
        }
        return value;
      });
    }).join(' > ');
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
              style: TextStyle(fontSize: 36),
            ),
          ),
        ),
        SlideInOut(
          incoming: Offset(-1, 0),
          outgoing: Offset(1, 0),
          animation: animation,
          secondaryAnimation: secondaryAnimation,
          child: Center(
            child: Text(
              animal,
              style: TextStyle(fontSize: 36),
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
