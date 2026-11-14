# flutter_local_notifications (scheduled notifications use Gson reflection)
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Flutter deferred components (not used)
-dontwarn com.google.android.play.core.**
