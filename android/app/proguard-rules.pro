# Flutter Wrapper Keep Rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep classes from Google services
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Keep MethodChannel classes used in Dart <-> Platform communication
-keepclassmembers class * {
    @io.flutter.embedding.engine.plugins.FlutterPlugin;
    <methods>;
}

# Keep classes needed for reflection
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

# Optional: keep models used in JSON serialization (if needed)
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
