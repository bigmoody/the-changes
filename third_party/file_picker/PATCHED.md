# file_picker 8.3.7, patched

A copy of [file_picker](https://pub.dev/packages/file_picker) 8.3.7 (MIT,
see LICENSE), without its example and tests, used through
`dependency_overrides` in the app's pubspec.yaml.

The one change: on iOS, cancelling a picker could answer a request that was
already answered. Swiping the save sheet away answers it in
`presentationControllerDidDismiss:`, then `documentPickerWasCancelled:`
called the nil block left behind and the app crashed (EXC_BAD_ACCESS in
`documentPickerWasCancelled:`, FilePickerPlugin.m). Each cancel handler in
`ios/file_picker/Sources/file_picker/FilePickerPlugin.m` now answers only
if the request is still open; they are marked "Patched (The Changes)".

file_picker 10 and later moved iOS to file_picker_darwin, whose handler
finishes each request once. Moving to it changes the API the app calls, so
this copy holds until that is done.
