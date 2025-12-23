plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
import java.util.Properties
import java.io.FileInputStream
import java.io.File as JavaFile
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

val env = Properties()
val envFile = JavaFile(rootProject.projectDir.parentFile, ".env")
if (envFile.exists()) {
    env.load(FileInputStream(envFile))
}

android {
    namespace = "com.example.reelary"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    // Kotlin compiler options are configured below using tasks.withType<KotlinCompile>()

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.reelary"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["googleMapsApiKey"] = env.getProperty("GOOGLE_MAPS_API_KEY") ?: ""
    }


    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

// Configure Kotlin JVM toolchain and compiler options using the newer compilerOptions DSL
kotlin {
    jvmToolchain(17)
    compilerOptions {
        freeCompilerArgs.addAll(listOf("-Xjvm-default=all-compatibility"))
        jvmTarget.set(JvmTarget.JVM_17)
    }
}

// Ensure KotlinCompile tasks also pick up the options (for compatibility with older Gradle versions)
tasks.withType<KotlinCompile>().configureEach {
    compilerOptions {
        freeCompilerArgs.addAll(listOf("-Xjvm-default=all-compatibility"))
        jvmTarget.set(JvmTarget.JVM_17)
    }
}
