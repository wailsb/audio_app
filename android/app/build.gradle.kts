plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.audioapp.audio_app"
    compileSdk = 36
    ndkVersion = "28.2.13676358"

    defaultConfig {
        applicationId = "com.audioapp.audio_app"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }
}

flutter {
    source = "../.."
}

val flutterRootDir = rootProject.projectDir.parentFile

tasks.register<Copy>("copyFlutterApkDebug") {
    val apkDir = File(buildDir, "outputs/flutter-apk")
    from(File(apkDir, "app-debug.apk"))
    into(File(flutterRootDir, "build/app/outputs/flutter-apk"))
}

tasks.matching { it.name == "assembleDebug" }.configureEach {
    finalizedBy("copyFlutterApkDebug")
}

dependencies {
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:2.1.0")
}
