import 'dart:math';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:value_navigator/main.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
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

class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

final Random _rng = Random(0);

Color _randomColor() {
  return Colors.primaries[_rng.nextInt(Colors.primaries.length)];
}

class _MyHomePageState extends State<MyHomePage> {
  final ValueNotifier<int> _currAnimalIndex = ValueNotifier(0);
  final ValueNotifier<Color> _currColor = ValueNotifier(_randomColor());

  VoidCallback? _tabListener;

  void _incrementIndex() {
    if (_tabIndex == 0) {
      _currAnimalIndex.value = _currAnimalIndex.value + 1;
      return;
    } else if (_tabIndex == 1) {
      _currColor.value = _randomColor();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('test'),
        bottom: TabBar(
          tabs: [
            Tab(icon: Icon(Icons.pets)),
            Tab(icon: Icon(Icons.people)),
            Tab(icon: Icon(Icons.info)),
          ],
        ),
      ),
      body: ImplicitNavigator<int>(
        value: _tabIndex,
        // Back button should always return to index 0.
        depth: _tabIndex == 0 ? 0 : 1,
        onPop: (poppedIndex, newIndex) {
          _tabIndex = newIndex;
        },
        builder: (context, value, animation, secondaryAnimation) {
          if (value == 0) {
            return ImplicitNavigator.fromNotifier<int>(
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
            return ImplicitNavigator.fromNotifier<Color>(
              valueNotifier: _currColor,
              builder: (
                context,
                color,
                animation,
                secondaryAnimation,
              ) {
                return Container(color: color);
              },
            );
          }
          return Center(
            child: Text(
              'This is a demo of `ImplicitNavigator`!',
              style: TextStyle(fontSize: 24),
            ),
          );
        },
      ),
      floatingActionButton: _tabIndex != 2
          ? FloatingActionButton(
              onPressed: _incrementIndex,
              tooltip: 'Increment',
              child: Icon(Icons.navigate_next),
            )
          : null,
    );
  }

  int get _tabIndex => DefaultTabController.of(context)!.index;

  set _tabIndex(int newValue) =>
      DefaultTabController.of(context)!.index = newValue;
}

class AnimalWidget extends StatelessWidget {
  const AnimalWidget({
    Key? key,
    required this.value,
    required this.animation,
    required this.secondaryAnimation,
  }) : super(key: key);

  static const List<String> _animals = [
    'purple goat',
    'blue octopus',
    'red cat',
    'orange monkey',
    'yellow lemur',
    'purple fish',
    'brown dodo',
    'grey sparrow',
  ];

  final int value;
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;

  @override
  Widget build(BuildContext context) {
    final String color = _animals[value % _animals.length].split(' ').first;
    final String animal = _animals[value % _animals.length].split(' ').last;
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
