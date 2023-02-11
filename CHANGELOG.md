## [0.0.1] - 09/07/2021

* Initial release.

## [0.0.2] - 09/07/2021

* Formatting changes to chase those sweet sweet pub points.

## [0.0.3] - 09/07/2021

* Readme and documentation changes.

## [0.0.4] - 09/07/2021

* Added example code to documentation.

## [0.0.5] - 09/08/2021

* Replaced the overly complex example with a rendition of the book app example from the Flutter Navigation tutorial.
* Overhauled the readme with simple example snippets.

## [0.0.6] - 09/09/2021

* Fixed bug where exception is thrown if the user passes in an ungrowable list for `initialHistory`.

## [0.1.0] - 09/09/2021

* Allow `getDepth` to return null for mixed-style navigation.

## [0.2.0] - 09/18/2021

* Replaced `popFromTree` and `pop` with a single function with optional bool input.
* Used route workaround to prevent routes from stealing focus (see https://github.com/flutter/flutter/issues/53441).
* Renamed `canPopFromTree` and `canPop` to `canPop` and `shallowCanPop`, respectively.
* Fixed example's scaffold placement to match official flutter example.


## [0.3.0] - 09/18/2021

* Replace enablePop/disablePop with a `canPop` setter.
* Added type parameter back to `ImplicitNavigator.of()`
* Fixed readme examples.
* Improved notification documentation.


## [1.0.0] - 01/01/2022

* Added `SelectFromListenable` by request of @clragon.
* Added `maintainHistory` to determine if page history should be written and restored instead of using `key`.
* Renamed `fromNotifier` to `fromValueNotifier`
* Made `onPop` required for relevant constructors/static methods.
* Renamed `currentValue` to `valueAfterPop`.
* Replaced alternate constructors with static methods and moved logic into wrapping widgets.
* Added basic unit tests.

## [1.0.1] - 01/01/2022

* Added banner image

## [1.0.2] - 01/31/2022

* Use Navigator's `requestFocus` argument

## [1.0.3] - 01/31/2022

* Temporary rollback of 1.0.2 because of a bug in navigator: https://github.com/flutter/flutter/issues/97682

## [1.1.0] - 03/16/2022

* Expose `displayBackButton`
* Rename `set canPop` to `set isEnabled`

## [1.2.0] - 03/16/2022

* Added local history entries
* Upgraded dependencies
* Fixed analysis warnings

## [1.2.1] - 03/16/2022

* Fix bug where back button transition duration was ignored
* Always display the back button if the transition duration is zero

## [1.3.0] - 09/26/2022

* Added `fromValueListenable` for convenience
* Appeased the almighty linter, fickle be thy nature


## [1.3.1] - 09/26/2022

* Removed no-op selector from `fromValueListenable`

## [1.3.1] - 09/26/2022

* Upgraded flutter version
