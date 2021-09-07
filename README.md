# value_navigator


Provides an intuitive and highly flexible navigation with an easy to use API. Value Navigator was created as
substitute for the existing Navigator 1.0 and 2.0 APIs.

## Core Features

Value Navigator has three core features that set it apart from the official
Flutter solutions:

- The navigator stack is constructed and appended to implicitly as the app's data models and widget tree change.
- Web browser (back button undoes last change) and app (back button goes "up" in a developer-defined navigation
hierarchy) style navigation are both supported out of the box.
- Nesting navigators in the widget tree has first class support with the system back button always popping from the
inner most navigator first.

## How It Works

Value Navigator is built on top of the Flutter Navigator 2.0 API. Value Navigators operate similar to
`ValueListenableBuilder`: each one has a value and a builder. Whenever a new value is supplied, a new page is added to
the internal navigator's page stack. When pop is called (by the system or programmatically), the top most page is popped
and the builder is called with the previous value. An `onPop` callback can be used to revert any state used outside of
the navigator.

When the system back button is called, `ValueNavigator` attempts to pop from the deepest navigator in the tree, working
it's way up to the root navigator until it finds a navigator that can handle the pop.

`ValueNavigator` takes an optional `depth` parameter which represents where the user currently is in the
app's navigation flow. When a non-null depth is specified, the navigator stack is rebuilt with all
entries of greater depth removed. eg a value of depth 2 will replace any existing stack entries of depth 2 or greater.
When pop is called, the navigator state will return to the last seen value with a lower depth. This emulates "app style"
navigation where popping takes the user "up" in the navigation flow.
For browser style navigation (pop always undoes the last change), leave depth null.

As a convenience, `ValueNavigator.fromNotifier` wraps a `ValueNotifier`. It updates the navigator stack when the
notifier changes and rolls changes back when pop is called.
