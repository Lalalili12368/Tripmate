# Tripmate

A Flutter travel planning application.

## Run the project in Chrome

### Requirements
- Flutter SDK installed and added to PATH
- Google Chrome installed
- VS Code (recommended)

### Setup

1. Open the project folder in VS Code.
2. Open the terminal in the project root (the folder containing `pubspec.yaml`).
3. Install the dependencies:

```bash
flutter pub get
```

4. If the project does not already contain a `web/` folder, generate the web platform files once:

```bash
flutter create --platforms=web .
```

5. Run Tripmate in Chrome:

```bash
flutter run -d chrome
```

## Useful Flutter commands

Check your Flutter installation:

```bash
flutter doctor
```

List available devices:

```bash
flutter devices
```

Check the project for Dart issues:

```bash
flutter analyze
```

Format Dart files:

```bash
dart format lib
```

## Project structure

```text
tripmate/
  lib/
    main.dart
    db.dart
    services.dart
    widgets.dart
    screens/
  pubspec.yaml
  README.md
```

## Notes

- Run Flutter commands from the project root, not from `C:\Windows\System32` or another unrelated folder.
- The provided ZIP contains the Dart source files and `pubspec.yaml`. It does not include generated platform folders such as `web/`, `android/`, or `ios/`, or separate asset files.
- This README documents the setup commands; it does not claim that the project has been tested or that every platform build is currently error-free.
