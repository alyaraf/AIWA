import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Release signing (FE-2): android/key.properties (git-ignored) points at the
// upload keystore. See docs/release.md.
val keystoreProperties = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}

// --dart-define values arrive base64-encoded and comma-separated in "dart-defines".
val dartDefines: Map<String, String> =
    (project.findProperty("dart-defines") as String? ?: "")
        .split(",").filter { it.isNotBlank() }
        .map { String(Base64.getDecoder().decode(it)) }
        .mapNotNull { d -> d.indexOf('=').takeIf { it > 0 }?.let { d.substring(0, it) to d.substring(it + 1) } }
        .toMap()

android {
    namespace = "com.aiwa.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Required by flutter_local_notifications
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // FE-28: final ID, registered in Firebase and the stores. Never change it after publishing.
        applicationId = "com.aiwa.app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // FE-13: App Links host, from --dart-define=APP_LINK_BASE=https://<domain>.
        // Without one the filter points at a reserved name that never verifies.
        manifestPlaceholders["appLinkHost"] = dartDefines["APP_LINK_BASE"]
            ?.takeIf { it.startsWith("https://") }
            ?.removePrefix("https://")?.substringBefore("/")
            ?: "app-links.invalid"
    }

    signingConfigs {
        if (keystoreProperties.containsKey("storeFile")) {
            create("release") {
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // Never ship with the debug key: without key.properties a release
            // build fails in checkReleaseConfig below instead.
            signingConfig = signingConfigs.findByName("release")
        }
    }
}

// FE-1 / FE-2: a release build must point at a real HTTPS API and be signed
// with the upload key. Fails fast instead of shipping the emulator loopback.
val checkReleaseConfig by tasks.registering {
    doLast {
        val problems = mutableListOf<String>()
        val api = dartDefines["API_BASE_URL"].orEmpty()
        if (!Regex("^https://[^/\\s]+").containsMatchIn(api)) {
            problems += "API_BASE_URL must be an https:// URL (pass --dart-define=API_BASE_URL=https://api.<domain>/api)."
        }
        if (!keystoreProperties.containsKey("storeFile")) {
            problems += "android/key.properties is missing, so the release would be unsigned (see docs/release.md)."
        }
        if (problems.isNotEmpty()) throw GradleException("Release build blocked:\n - " + problems.joinToString("\n - "))
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach { dependsOn(checkReleaseConfig) }

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
