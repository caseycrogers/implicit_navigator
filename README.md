An easy and intuitive navigator that updates the page stack in response to app state changes and the system back button.
Just build your widget tree and Implicit Navigator will handle the rest!

## Core Features

The following features set Implicit Navigator apart from the official Flutter solution(s):

1. The navigator stack is constructed and appended to implicitly as your app's data models and widget tree change.
2. "App-style" and "browser-style" navigation are both supported out of the box:
   * **App-Style** - back button goes "up" in a developer-defined navigation hierarchy, potentially undoing multiple
state changes
   * **Browser-Style** - back button reverts the last state change
3. Nesting navigators in the widget tree has first class support with the system back button always popping from the
inner most navigator first.

## Getting Started

First decide if you want to use app or browser style navigation. Below are samples for each style, but this is just a
starting off point! You can set the navigation style based on the current platform or mix and match styles in different
navigators within the same app.

### App-Style Navigation

The following implements app-style navigation:

```dart
class _AppStyleState extends State<AppStyle> {
  int? _index;

  @override
  Widget build(BuildContext context) {
    return ImplicitNavigator<int?>(
      value: _index,
      depth: _index == null ? 0 : 1,
      builder: (context, index, animation, secondaryAnimation) {
        return TextButton(
          onPressed: () => setState(() {
            _index = (index ?? -1) + 1;
          }),
          onLongPress: () => ImplicitNavigator.of<int?>(context).pop(),
          child: Text((index ?? 'Tap To Increment').toString()),
        );
      },
      onPop: (poppedValue, currentValue) => _index = currentValue,
    );
  }
}
```

`ImplicitNavigator` takes an optional `depth` parameter which represents where the user currently is in the app's
navigation flow. When the back button is pressed, the app state is returned to the last value of less depth. ie, the
user moves "up" the navigation flow.

Using the above example code, imagine a user navigates through the pages as follows:

`depth_0:_index=null > depth_1:_index=0 > depth_1:_index=1`

If the user then presses back, they will go **up** in the navigation flow to depth 0: `depth_0:_index=null`, **not**
`depth_1:_index=0`.

If Implicit Navigators are nested within each other in the widget tree, you should build each inner navigator with a
distinct `PageStorageKey`. Implicit Navigator will then cache and restore the history stack using page storage so that,
if a user navigates away from it and then comes back, it'll retain it's history stack.

### Browser-Style Navigation

The following implements browser-style navigation:

```dart
class _BrowserStyleState extends State<BrowserStyle> {
  int? _index;

  @override
  Widget build(BuildContext context) {
    return ImplicitNavigator<int?>(
      value: _index,
      builder: (context, index, animation, secondaryAnimation) {
        return TextButton(
          onPressed: () => setState(() {
            _index = (_index ?? -1) + 1;
          }),
          onLongPress: () => ImplicitNavigator.of<int?>(context).pop(),
          child: Text((index ?? 'Tap To Increment').toString()),
        );
      },
      onPop: (poppedValue, currentValue) => _index = currentValue,
    );
  }
}
```

For browser-style navigation, simply leave `depth` null and **do not** provide a `PageStorageKey` to any nested implicit
navigators.

Repeating the example from above, but with browser style navigation:

`depth_null:_index=null > depth_null:_index=0 > depth_null:_index=1`

If the user then presses back, they will go back to the previous page/app state: `depth_null:_index=0`.

## How It Works

Implicit Navigator is built on top of the Flutter Navigator 2.0 API. Implicit Navigators operate similar to
`ValueListenableBuilder`: each one takes in a changing value and a builder. Whenever a new value and/or depth is
supplied, a new page is added to the internal navigator's page stack. When pop is called (by the system or
programmatically), the topmost page is popped and the builder is called with the new topmost value. An `onPop` callback
can be used to revert any state outside of the navigator.

As a convenience method, `ImplicitNavigator.fromNotifier` wraps a `ValueNotifier`. It pushes to the navigator stack when
the notifier changes and automatically rolls the value of the notifier back when pop is called.

When the system back button is called (or pop is called programmatically), `ImplicitNavigator` attempts to pop from the
deepest active navigator in the tree, working it's way up to the root navigator until it finds an active navigator that
can handle the pop. A navigator is active if it is in the topmost route of the root navigator and it has not been
manually disabled via `ImplicitNavigator.of(context).canPop = false`.

`ImplicitNavigatorBackButton` is also provided as a convenience widget. Use it in your app bar's `leading` argument to
display a back button that is visible whenever **any** Implicit Navigator in the widget tree can pop.

## Limitations

* Implicit Navigator **does not** provide any out of the box tools for routing (eg parsing URLs pushed by the browser or
handling deep links). This is intentional-routing is highly complex and, in my opinion, well outside of any reasonable
separation of concerns for a navigator package. To handle routing, use the router of your choice to parse incoming
routes and rebuild the widget tree with the new app state according to the incoming routes. `Implicit Navigator` will
see any relevant state changes and push the appropriate pages in response.

## Contributing

I highly appreciate any support on this project! If you find an issue or have a feature request feel free to
[file a bug](https://github.com/caseycrogers/implicit_navigator/issues/new) or
[fork the repo](https://github.com/caseycrogers/implicit_navigator) and submit a PR.
