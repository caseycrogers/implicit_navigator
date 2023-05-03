import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:implicit_navigator/src/implicit_navigator.dart';

import 'test_listenable.dart';

enum Version {
  base,
  fromValueNotifier,
  selectFromListenable,
}

Key getIncrementKey(String suffix) => Key('increment$suffix');

Key getDecrementKey(String suffix) => Key('decrement$suffix');

Key getPopKey(String suffix) => Key('pop$suffix');

Key getNativePopKey(String suffix) => Key('nativePop$suffix');

Key getContextKey(String suffix) => Key('context$suffix');

Widget boilerPlate(
  Version version, {
  bool root = true,
  bool maintainHistory = false,
  required ValueNotifier<int> notifier,
  required TestListenable listenable,
  int Function(int)? getDepth,
  final String suffix = '',
  Widget Function(BuildContext, int)? builder,
}) {
  int value = notifier.value;
  final Widget baseWidget = StatefulBuilder(
    builder: (context, setState) {
      void updateValue(int delta) {
        switch (version) {
          case Version.base:
            setState(() {
              value += delta;
              notifier.value = value;
            });
            break;
          case Version.fromValueNotifier:
            notifier.value += delta;
            break;
          case Version.selectFromListenable:
            listenable.value += delta;
            break;
        }
      }

      final Key navigatorKey =
          maintainHistory ? PageStorageKey(suffix) : Key(suffix);
      return Stack(
        children: [
          if (version == Version.base)
            ImplicitNavigator<int>(
              key: navigatorKey,
              maintainHistory: maintainHistory,
              value: value,
              depth: getDepth?.call(value),
              onPop: (poppedValue, valueAfterPop) {
                value = valueAfterPop;
                notifier.value = value;
              },
              builder: (context, value, _, __) => TestPage(
                suffix,
                child: builder?.call(context, value),
                pageNumber: value,
              ),
            ),
          if (version == Version.fromValueNotifier)
            ImplicitNavigator.fromValueNotifier<int>(
              key: navigatorKey,
              maintainHistory: maintainHistory,
              valueNotifier: notifier,
              getDepth: getDepth,
              builder: (context, value, _, __) => TestPage(
                suffix,
                child: builder?.call(context, value),
                pageNumber: value,
              ),
            ),
          if (version == Version.selectFromListenable)
            ImplicitNavigator.selectFromListenable<TestListenable, int>(
              key: navigatorKey,
              maintainHistory: maintainHistory,
              listenable: listenable,
              selector: () => listenable.value,
              onPop: (poppedValue, valueAfterPop) {
                listenable.value = valueAfterPop;
              },
              getDepth: getDepth,
              builder: (context, value, _, __) => TestPage(
                suffix,
                child: builder?.call(context, value),
                pageNumber: value,
              ),
            ),
          Center(
            child: Row(
              children: [
                IconButton(
                  key: getDecrementKey(suffix),
                  icon: const Icon(Icons.exposure_minus_1),
                  onPressed: () => updateValue(-1),
                ),
                IconButton(
                  key: getIncrementKey(suffix),
                  icon: const Icon(Icons.plus_one),
                  onPressed: () => updateValue(1),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
  if (root) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(leading: const BackButton()),
        body: baseWidget,
      ),
    );
  }
  return baseWidget;
}

void main() {
  for (final Version version in Version.values) {
    final String versionName = version.toString().split('.').last;
    group(versionName, () {
      testWidgets('Browser style can push and pop',
          (WidgetTester tester) async {
        final Key incrementKey = getIncrementKey('');
        final Key decrementKey = getDecrementKey('');
        final Key popKey = getPopKey('');
        final ValueNotifier<int> currValue = ValueNotifier(0);
        final TestListenable testListenable = TestListenable(currValue);

        await tester.pumpWidget(boilerPlate(
          version,
          notifier: currValue,
          listenable: testListenable,
        ));
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page0'), findsNothing);
        expect(find.text('page1'), findsOneWidget);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page1'), findsNothing);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page0'), findsNothing);
        expect(find.text('page1'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 2);
        expect(find.text('page1'), findsNothing);
        expect(find.text('page2'), findsOneWidget);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page2'), findsNothing);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page1'), findsNothing);

        // We're at depth 0 so pop won't do anything.
        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        await tester.tap(find.byKey(decrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, -1);
        expect(find.text('page-1'), findsOneWidget);
      });

      testWidgets('App style can push and pop', (WidgetTester tester) async {
        final Key incrementKey = getIncrementKey('');
        final Key popKey = getPopKey('');
        final ValueNotifier<int> currValue = ValueNotifier(0);
        final TestListenable testListenable = TestListenable(currValue);
        await tester.pumpWidget(boilerPlate(
          version,
          notifier: currValue,
          // Make depth increment every other number.
          getDepth: (i) {
            return (i / 2.0).floor();
          },
          listenable: testListenable,
        ));
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);

        // We're still at depth 0 so pop won't do anything.
        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);

        // Reach depth one and pop will return to depth 0.
        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 2);
        expect(find.text('page2'), findsOneWidget);
        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);
      });

      testWidgets('App style push replaces stack', (WidgetTester tester) async {
        final Key incrementKey = getIncrementKey('');
        final Key decrementKey = getDecrementKey('');
        final Key popKey = getPopKey('');
        final ValueNotifier<int> currValue = ValueNotifier(0);
        final TestListenable testListenable = TestListenable(currValue);
        await tester.pumpWidget(boilerPlate(
          version,
          notifier: currValue,
          listenable: testListenable,
          // Make depth increment every other number.
          getDepth: (i) {
            return (i / 2.0).floor();
          },
        ));
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 3);
        expect(find.text('page3'), findsOneWidget);

        await tester.tap(find.byKey(decrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 2);
        expect(find.text('page2'), findsOneWidget);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);
      });

      testWidgets('Nested browser style can push and pop',
          (WidgetTester tester) async {
        final Key incrementKey = getIncrementKey('');
        final Key incrementKeyB = getIncrementKey('b');
        final Key incrementKeyC = getIncrementKey('c');
        final Key popKey = getPopKey('');
        final ValueNotifier<int> currValue = ValueNotifier(0);
        final TestListenable testListenable = TestListenable(currValue);
        final ValueNotifier<int> currValueB = ValueNotifier(0);
        final TestListenable testListenableB = TestListenable(currValueB);
        final ValueNotifier<int> currValueC = ValueNotifier(0);
        final TestListenable testListenableC = TestListenable(currValueC);
        await tester.pumpWidget(boilerPlate(
          version,
          notifier: currValue,
          listenable: testListenable,
          builder: (context, value) => value == 0
              ? boilerPlate(
                  version,
                  root: false,
                  suffix: 'b',
                  notifier: currValueB,
                  listenable: testListenableB,
                )
              : boilerPlate(
                  version,
                  root: false,
                  suffix: 'c',
                  notifier: currValueC,
                  listenable: testListenableC,
                ),
        ));
        expect(currValue.value, 0);
        expect(currValueB.value, 0);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page0b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);

        await tester.tap(find.byKey(incrementKeyB));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(currValueB.value, 1);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page1b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(currValueB.value, 1);
        expect(currValueC.value, 0);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page1b'), findsNothing);
        expect(find.text('page0c'), findsOneWidget);

        await tester.tap(find.byKey(incrementKeyC));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(currValueB.value, 1);
        expect(currValueC.value, 1);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page1b'), findsNothing);
        expect(find.text('page1c'), findsOneWidget);

        // Pops from the bottom of the tree.
        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(currValueB.value, 1);
        expect(currValueC.value, 0);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page1b'), findsNothing);
        expect(find.text('page0c'), findsOneWidget);

        // Travels up the tree and pops from the top.
        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(currValueB.value, 1);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page1b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);

        // Pops from the final non-empty tree.
        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(currValueB.value, 0);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page0b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);
      });

      testWidgets('Nested app style recovers history',
          (WidgetTester tester) async {
        final Key incrementKey = getIncrementKey('');
        final Key incrementKeyB = getIncrementKey('b');
        final Key decrementKey = getDecrementKey('');
        final Key popKey = getPopKey('');
        final ValueNotifier<int> currValue = ValueNotifier(0);
        final TestListenable testListenable = TestListenable(currValue);
        final ValueNotifier<int> currValueB = ValueNotifier(0);
        final TestListenable testListenableB = TestListenable(currValueB);
        final ValueNotifier<int> currValueC = ValueNotifier(0);
        final TestListenable testListenableC = TestListenable(currValueC);
        await tester.pumpWidget(boilerPlate(
          version,
          maintainHistory: true,
          notifier: currValue,
          listenable: testListenable,
          builder: (context, value) => value == 0
              ? boilerPlate(
                  version,
                  root: false,
                  maintainHistory: true,
                  suffix: 'b',
                  notifier: currValueB,
                  listenable: testListenableB,
                )
              : boilerPlate(
                  version,
                  root: false,
                  suffix: 'c',
                  maintainHistory: true,
                  notifier: currValueC,
                  listenable: testListenableC,
                ),
        ));
        expect(currValue.value, 0);
        expect(currValueB.value, 0);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page0b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);

        await tester.tap(find.byKey(incrementKeyB));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(currValueB.value, 1);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page1b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(currValueB.value, 1);
        expect(currValueC.value, 0);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page1b'), findsNothing);
        expect(find.text('page0c'), findsOneWidget);

        await tester.tap(find.byKey(decrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(currValueB.value, 1);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page1b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(currValueB.value, 0);
        expect(currValueC.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page0b'), findsOneWidget);
        expect(find.text('page0c'), findsNothing);
      });

      testWidgets('Nested browser style pops on back button',
          (WidgetTester tester) async {
        final Key incrementKey = getIncrementKey('');
        final Key incrementKeyB = getIncrementKey('b');
        final ValueNotifier<int> currValue = ValueNotifier(0);
        final TestListenable testListenable = TestListenable(currValue);
        final ValueNotifier<int> currValueB = ValueNotifier(0);
        final TestListenable testListenableB = TestListenable(currValueB);
        await tester.pumpWidget(boilerPlate(
          version,
          notifier: currValue,
          listenable: testListenable,
          builder: (context, value) => boilerPlate(
            version,
            root: false,
            suffix: 'b',
            notifier: currValueB,
            listenable: testListenableB,
          ),
        ));
        expect(currValue.value, 0);
        expect(currValueB.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page0b'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(currValueB.value, 0);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page0b'), findsOneWidget);

        await tester.tap(find.byKey(incrementKeyB));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(incrementKeyB));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(currValueB.value, 2);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page2b'), findsOneWidget);

        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(currValueB.value, 1);
        expect(find.text('page1'), findsOneWidget);
        expect(find.text('page1b'), findsOneWidget);
      });

      testWidgets('Legacy Nav pop and push work', (WidgetTester tester) async {
        final Key contextKey = getContextKey('');
        final Key incrementKey = getIncrementKey('');
        final Key decrementKey = getDecrementKey('');
        final Key popKey = getPopKey('');
        final ValueNotifier<int> currValue = ValueNotifier(0);
        final TestListenable testListenable = TestListenable(currValue);

        await tester.pumpWidget(boilerPlate(
          version,
          notifier: currValue,
          listenable: testListenable,
        ));
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        unawaited(
          Navigator.of(tester.state(find.byKey(contextKey)).context).push(
            TestPageRoute('', pageNumber: 1),
          ),
        );
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsNothing);
        expect(find.text('imperativePage1'), findsOneWidget);

        Navigator.of(tester.state(find.byKey(contextKey)).context).pop();
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('imperativePage1'), findsNothing);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page0'), findsNothing);
        expect(find.text('page1'), findsOneWidget);

        Navigator.of(tester.state(find.byKey(contextKey)).context).pop();
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);
        expect(find.text('page1'), findsNothing);
      });
    });
  }
}

class TestPageRoute extends MaterialPageRoute<void> {
  TestPageRoute(
    this.suffix, {
    this.child,
    required this.pageNumber,
  }) : super(builder: (context) {
          return StatefulBuilder(
            key: getContextKey(suffix),
            builder: (context, setState) {
              return Column(
                children: [
                  Text('imperativePage$pageNumber$suffix'),
                  if (child != null) child,
                ],
              );
            },
          );
        });

  final String suffix;
  final Widget? child;
  final int pageNumber;
}

class TestPage extends StatelessWidget {
  const TestPage(
    this.suffix, {
    this.child,
    required this.pageNumber,
  });

  final String suffix;
  final Widget? child;
  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // A dummy stateful widget to give us access to a context below the
        // navigator.
        StatefulBuilder(
          key: getContextKey(suffix),
          builder: (context, setState) {
            return Container();
          },
        ),
        IconButton(
          key: getPopKey(suffix),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ImplicitNavigator.of<int>(context).pop();
          },
        ),
        IconButton(
          key: getNativePopKey(suffix),
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        Text('page$pageNumber$suffix'),
        if (child != null) Expanded(child: child!),
      ],
    );
  }
}
