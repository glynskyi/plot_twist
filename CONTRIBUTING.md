# Contributing to plot_twist

Thanks for helping. Issues, questions, demos and pull requests are all welcome.

- **A bug:** open an issue with the smallest code that shows it.
- **A missing feature:** open a feature request and say which of the 26 aspects
  comes closest. Many needs can be met by adding a child to a chart; the issue
  is a good place to find out together.
- **A question or something you built:** use
  [Discussions](https://github.com/glynskyi/plot_twist/discussions).

## Ground rules of the design

These are checked by tests, so a pull request that breaks them fails CI.

- Built-in series, layers and behaviors use only the public API, the same one
  an app uses (`test/core_test.dart`).
- The package depends on Flutter's widgets layer only: no Material, no
  Cupertino, no other packages.
- Panning and zooming lay out and paint; they do not rebuild widgets
  (`test/skeleton_test.dart`).
- Every Dart sample in the README is compiled and run by `test/readme_test.dart`.
  Change the README and that test together.

## Working on the code

The repository pins Flutter 3.50.0 in `.fvmrc`. The package supports
Flutter 3.41 and later.

```sh
flutter test                 # package tests
cd example && flutter test   # every demo runs, stays under 120 lines, uses only the public API
```

Format only the source folders, at the 100-column width set in
`analysis_options.yaml` (`dart format .` would also walk `build/`):

```sh
dart format lib test example/lib example/test example/test_driver
```

To check the oldest supported Flutter, resolve the package without the gallery,
which needs Flutter 3.47:

```sh
flutter pub get --no-example
flutter test --no-pub
```

## Demos

`example/lib/demos/` has one demo per aspect. A demo is proof that an aspect is
easy, so it follows three rules, enforced by `example/test/demos_test.dart`:

1. It is one file.
2. It imports only `package:plot_twist/plot_twist.dart`, Flutter and the
   example's shared helpers.
3. It has at most 120 lines that are neither blank nor comments, after
   `dart format` at 100 columns.

The test writes the line counts to `example/build/screenshots/line_counts.txt`.
The tables in the README and `doc/aspects.md` must match it.

## Performance numbers

The README's figures come from `example/test_driver/perf_test.dart` in profile
mode:

```sh
cd example
flutter drive --profile -d macos --driver=test_driver/perf_test.dart --target=test_driver/perf.dart
```

Keep the app window in front while it runs; a window in the background gets
fewer frames. Say which device you measured on.

## License

By contributing, you agree that your contributions are licensed under the MIT
license of this repository.
