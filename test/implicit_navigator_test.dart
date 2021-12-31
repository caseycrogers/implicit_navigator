import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:implicit_navigator/implicit_navigator.dart';

enum Version {
  base,
  fromNotifier,
}

const Key incrementKey = Key('incrementKey');
const Key decrementKey = Key('decrementKey');
const Key popKey = Key('pop');

void main() {
  Widget _boilerPlate({
    Version version = Version.base,
    required ValueNotifier<int> notifier,
    int Function(int)? getDepth,
  }) {
    final pageStorage = PageStorageBucket();
    int value = notifier.value;
    return Material(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: PageStorage(
          bucket: pageStorage,
          child: StatefulBuilder(builder: (context, setState) {
            void updateValue(int delta) {
              switch (version) {
                case Version.base:
                  setState(() {
                    value += delta;
                    notifier.value = value;
                  });
                  break;
                case Version.fromNotifier:
                  notifier.value += delta;
                  break;
              }
            }
            return Stack(
              children: [
                if (version == Version.base)
                  ImplicitNavigator<int>(
                    value: value,
                    depth: getDepth?.call(value),
                    onPop: (poppedValue, currentValue) {
                      value = currentValue;
                      notifier.value = value;
                    },
                    builder: testPageBuilder,
                  ),
                if (version == Version.fromNotifier)
                  ImplicitNavigator.fromNotifier<int>(
                    valueNotifier: notifier,
                    getDepth: getDepth,
                    builder: testPageBuilder,
                  ),
                Center(
                  child: Row(
                    children: [
                      IconButton(
                        key: incrementKey,
                        icon: const Icon(Icons.exposure_minus_1),
                        onPressed: () => updateValue(1),
                      ),
                      IconButton(
                        key: decrementKey,
                        icon: const Icon(Icons.plus_one),
                        onPressed: () => updateValue(-1),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  for (final Version version in Version.values) {
    final String versionName = version.toString().split('.').last;
    group(versionName, () {
      testWidgets('Browser style can push and pop',
          (WidgetTester tester) async {
        final ValueNotifier<int> currValue = ValueNotifier(0);
        await tester.pumpWidget(_boilerPlate(
          version: version,
          notifier: currValue,
        ));
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);

        await tester.tap(find.byKey(incrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 2);
        expect(find.text('page2'), findsOneWidget);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 1);
        expect(find.text('page1'), findsOneWidget);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        // We're at depth 0 so pop won't do anything.
        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);

        await tester.tap(find.byKey(decrementKey));
        await tester.pumpAndSettle();
        expect(currValue.value, -1);
        expect(find.text('page-1'), findsOneWidget);

        await tester.tap(find.byKey(popKey));
        await tester.pumpAndSettle();
        expect(currValue.value, 0);
        expect(find.text('page0'), findsOneWidget);
      });

      testWidgets('App style can push and pop', (WidgetTester tester) async {
        final ValueNotifier<int> currValue = ValueNotifier(0);
        await tester.pumpWidget(_boilerPlate(
          notifier: currValue,
          // Make depth increment every other number.
          getDepth: (i) {
            return (i / 2.0).floor();
          },
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
        final ValueNotifier<int> currValue = ValueNotifier(0);
        await tester.pumpWidget(_boilerPlate(
          notifier: currValue,
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
    });
  }
}

Widget testPageBuilder(
  BuildContext context,
  int pageNumber,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
) {
  return Column(
    children: [
      IconButton(
        key: popKey,
        icon: const Icon(Icons.arrow_back),
        onPressed: () {
          ImplicitNavigator.of<int>(context).pop();
        },
      ),
      Container(child: Text('page$pageNumber')),
    ],
  );
}
