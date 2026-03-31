plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.broastaky_full"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // استخدم 1.8 للتوافق مع desugaring
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        // تفعيل core-library desugaring
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.example.broastaky_full"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Core library desugaring
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")

    // ملفات Facebook SDK من مجلد libs (Kotlin DSL)
    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))

    // Facebook Login SDK (اختياري لو هتعمل تسجيل دخول)
    implementation("com.facebook.android:facebook-login:17.0.0")
}

flutter {
    source = "../.."
}

/*
  استخدم compilerOptions DSL بدلاً من kotlinOptions (المهاجر المطلوب من Kotlin Gradle Plugin).
  هذا يحدد jvmTarget = 1.8 بدون استدعاء kotlin.jvmToolchain(...) وبالتالي نتجنّب طلب auto-provisioning.
*/
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile>().configureEach {
    // استخدم compilerOptions DSL (يتطلب Kotlin Gradle Plugin حديث)
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
    }
}