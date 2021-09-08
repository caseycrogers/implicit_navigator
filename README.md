# implicit_navigator

An intuitive and highly flexible navigation system with an easy to use API.

The page stack is updated implicitly in response to data model changes and the system back button, just build your
widget tree and Implicit Navigator will handle the rest!

## Core Features

The following features set Implicit Navigator apart from the official Flutter solution(s):

1. The navigator stack is constructed and appended to implicitly as your app's data models and widget tree change.
2. "App-style" and "browser-style" navigation are both supported out of the box:
   * **App-Style** - back button goes "up" in a developer-defined navigation hierarchy, potentially undoing multiple
state changes
   * **Browser-Style** - back button reverts the last state change
3. Nesting navigators in the widget tree has first class support with the system back button always popping from the
inner most navigator first.

## How It Works

Implicit Navigator is built on top of the Flutter Navigator 2.0 API. Implicit Navigators operate similar to
`ValueListenableBuilder`: each one takes in a changing value and a builder. Whenever a new value is supplied, a new page
is added to the internal navigator's page stack. When pop is called (by the system or programmatically), the topmost
page is popped and the builder is called with the new topmost value. An `onPop` callback can be used to revert any state
used outside of the navigator.

As a convenience method, `ImplicitNavigator.fromNotifier` wraps a `ValueNotifier`. It pushes to the navigator stack when
the notifier changes and rolls the value of the notifier back when pop is called.

When the system back button is called (or pop is called programmatically), `ImplicitNavigator` attempts to pop from the
deepest navigator in the tree, working it's way up to the root navigator until it finds a navigator that can handle the
pop.

### App-Style Navigation

`ImplicitNavigator` takes an optional `depth` parameter which represents where the user currently is in the app's
navigation flow. When the back button is pressed, the app state is returned to the last value of lower depth. ie, the
user moves "up" the navigation flow to a shallower depth.

For example, for an app with two pages: **home** and **details**, **home** would be depth 0 and **details** depth 1. A
user navigates through the pages as follows:

    `depth_0:home > depth_1:details(item_a) > depth_1:details(item_b)`

If the user then presses back (eg in a UI provided back button or with the android system back button), they will go up
in the navigation flow and return to the home page, NOT to the details page for `item_a`.

If Implicit Navigators are nested within each other in the widget tree, you should build each inner navigator with a
distinct `PageStorageKey`. Implicit Navigator will then cache and restore the history stack using page storage so that,
if a user navigates away from it and then comes back, it'll retain it's history stack.

### Browser-Style Navigation

For browser-style navigation, simply leave `depth` null and **do not** provide a `PageStorageKey` to any nested
implicit navigators. Repeating our
navigation example from above:

    `depth_null:home > depth_null:details(item_a) > depth_null:details(item_b)`

If the user presses back, the last state change (navigate to `item_b`'s details page) will be undone and the app will go
back to `item_a`'s details page.

## Known Bugs/Limitations

* If you have implicit navigators nested inside each other in the widget tree, inner navigators will fail to rebuild on
hot reload. You have to forcibly rebuild the page by navigating away and back.
