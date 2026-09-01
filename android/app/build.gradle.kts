import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 업로드 키는 저장소에 넣지 않는다. android/key.properties(=gitignore 대상)에서 읽는다.
// 파일이 없으면 release 빌드도 디버그 키로 서명된다 — 기기에서 릴리즈 실행은 되지만
// Play Console 업로드는 거부된다. android/key.properties.template 참고.
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile.exists()) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}
val hasUploadKeystore = keystorePropertiesFile.exists()

if (!hasUploadKeystore) {
    logger.warn(
        "[catmap] android/key.properties 가 없다. release 도 디버그 키로 서명되며 " +
            "Play Console 업로드는 거부된다. android/key.properties.template 참고."
    )
}

android {
    namespace = "com.bumjun.catmap"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // iOS 번들 ID 와 같은 값. Play 등록 후에는 바꿀 수 없다.
        applicationId = "com.bumjun.catmap"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // pubspec.yaml 의 version 에서 온다 (0.1.0+1 → versionName 0.1.0 / versionCode 1).
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (hasUploadKeystore) {
            create("release") {
                storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
                storePassword = keystoreProperties.getProperty("storePassword")
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 키가 없어도 기기에서 릴리즈 실행은 되도록 디버그 키로 떨어뜨린다.
            // 그 상태로 만든 AAB 는 build_android.sh 가 업로드 전에 막는다.
            signingConfig = signingConfigs.getByName(if (hasUploadKeystore) "release" else "debug")
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
