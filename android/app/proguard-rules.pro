# Add project specific ProGuard rules here.
# You can control the set of applied configuration files using the
# proguardFiles setting in build.gradle.
#
# For more details, see
#   http://developer.android.com/guide/developing/tools/proguard.html

# If your project uses WebView with JS, uncomment the following
# and specify the fully qualified class name to the JavaScript interface
# class:
#-keepclassmembers class fqcn.of.javascript.interface.for.webview {
#   public *;
#}

# Uncomment this to preserve the line number information for
# debugging stack traces.
#-keepattributes SourceFile,LineNumberTable

# If you keep the line number information, uncomment this to
# hide the original source file name.
#-renamesourcefileattribute SourceFile

# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Firebase rules
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Keep your model classes
-keep class com.uricaryn.backgammon_score_tracker.** { *; }

# Play Core Library rules
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }

# R8 specific rules for missing classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# ===== GÜVENLİK KURALLARI =====
# Hassas bilgileri koruma
-assumenosideeffects class android.util.Log {
    public static *** d(...);
    public static *** v(...);
    public static *** i(...);
}

# Firebase config dosyalarını gizle
-keepclassmembers class * {
    private static final java.lang.String GOOGLE_APP_ID;
    private static final java.lang.String FIREBASE_URL;
    private static final java.lang.String DEFAULT_WEB_CLIENT_ID;
    private static final java.lang.String GCM_DEFAULT_SENDER_ID;
}

# Stack trace'leri temizle
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Reflection kullanılan class'ları koru ama obfuscate et
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# Native method'ları koru
-keepclasseswithmembernames class * {
    native <methods>;
}

# Enum'ları koru
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Serializable class'ları koru
-keepnames class * implements java.io.Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    !static !transient <fields>;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
} 