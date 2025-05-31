plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}


android {
    namespace = "com.example.lol_custom_game_manager"
    compileSdk = 34
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.lol_custom_game_manager"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 21
        targetSdk = 34
        versionCode = 1
        versionName = "1.0.0"
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}
dependencies {
    // 3-1. Firebase BoM(Bill of Materials) 선언.
    //      BoM을 사용하면, 개별 Firebase 라이브러리의 버전을 명시하지 않아도
    //      동일한 버전 집합이 적용됩니다. (여기서는 예시 BoM 버전 33.14.0 사용)
    implementation(platform("com.google.firebase:firebase-bom:33.14.0"))

    // 3-2. 이제 Firebase 제품 모듈들을 BoM 방식으로 추가합니다.
    //      버전은 BoM에 의해 자동으로 관리되므로, 버전을 적지 않습니다.

    // Firebase Analytics(KTX)
    implementation("com.google.firebase:firebase-analytics-ktx")
    // Firebase Authentication(KTX)
    implementation("com.google.firebase:firebase-auth-ktx")
    // Firebase Firestore(KTX)
    implementation("com.google.firebase:firebase-firestore-ktx")
    // 필요하다면 추가적으로 Messaging, Storage, Functions 등을 넣을 수 있습니다.
    // 예시:
    // implementation("com.google.firebase:firebase-messaging-ktx")
    // implementation("com.google.firebase:firebase-storage-ktx")
    // implementation("com.google.firebase:firebase-functions-ktx")
}

apply(plugin = "com.google.gms.google-services")

flutter {
    source = "../.."
}
