# TripMate (sage-green redesign)

## Run
1. Put this folder anywhere, open a terminal inside it.
2. `flutter create .`   (generates android/ios/web/windows folders; keeps lib/ and pubspec.yaml)
3. Delete the generated `test/` folder (it references the default counter app).
4. `flutter pub get`
5. `flutter run`

Android: make sure `android/app/src/main/AndroidManifest.xml` has
`<uses-permission android:name="android.permission.INTERNET"/>` (needed for maps, photos, weather).
