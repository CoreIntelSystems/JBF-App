plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.coreintel.jbf_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Needed by flutter_local_notifications for scheduled reminders.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.coreintel.jbf_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Shared key for TEST builds only, so every CI build can install over
        // the previous one. Store releases need their own key kept in secrets.
        create("testBuilds") {
            storeFile = file("test-builds.jks")
            storePassword = "jbftest123"
            keyAlias = "jbftest"
            keyPassword = "jbftest123"
        }
        // Upload key for Google Play. The file and passwords come from the
        // build environment (GitHub secrets), never from the repository.
        System.getenv("PLAY_KEYSTORE_PATH")?.let { path ->
            create("playUpload") {
                storeFile = file(path)
                storePassword = System.getenv("PLAY_KEYSTORE_PASSWORD")
                keyAlias = System.getenv("PLAY_KEY_ALIAS")
                keyPassword = System.getenv("PLAY_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("testBuilds")
        }
        release {
            // The shared test key is used only when a test build asks for it
            // (JBF_TEST_BUILD=true, set in android.yml). A store build with
            // no upload key stays unsigned and fails loudly instead.
            signingConfig = signingConfigs.findByName("playUpload")
                ?: if (System.getenv("JBF_TEST_BUILD") == "true") {
                    signingConfigs.getByName("testBuilds")
                } else {
                    null
                }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    // AppCompat launch themes, required by local_auth on Android 8 and below.
    implementation("androidx.appcompat:appcompat:1.7.1")
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
