# flutter_local_notifications persists scheduled notifications with Gson and
# rebuilds them reflectively (e.g. after reboot), so its classes and models
# must survive R8.
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.models.** { *; }

# Gson (bundled by flutter_local_notifications) relies on generic signatures
# and annotations for reflective (de)serialization.
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }

# workmanager dispatches the background reschedule task reflectively.
-keep class dev.fluttercommunity.workmanager.** { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

# Keep enum values used via valueOf() reflection.
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}
