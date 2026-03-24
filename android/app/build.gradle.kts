plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.zxc.vpn"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    repositories {
        flatDir {
            dirs("libs")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.zxc.vpn"
        minSdk = flutter.minSdkVersion
        targetSdk = 34
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    // libXray.aar (и любой другой gomobile .aar) содержит Go runtime в пакете go.*
    // Если в проекте есть ДРУГОЙ gomobile .aar (напр. libv2ray), классы go.Seq
    // дублируются → ошибка Duplicate class.
    // Решение: оставляем только libXray; для .so-файлов используем legacyPackaging.
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
        // На случай если в транзитивных зависимостях окажется второй go-рантайм —
        // выбираем первый найденный и подавляем ошибку дублей для go.*
        resources {
            pickFirsts += setOf(
                "**/*.so",
                "META-INF/MANIFEST.MF",
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Единственный gomobile .aar — libXray.
    // НЕ добавляй сюда libv2ray.aar или любой другой gomobile-собранный .aar:
    // у каждого из них внутри свой go runtime (go.Seq и т.д.), два рантайма
    // в одном apk — это Duplicate class и краш при старте.
    implementation(files("libs/libXray.aar"))

    implementation("androidx.localbroadcastmanager:localbroadcastmanager:1.1.0")
    implementation("androidx.core:core-ktx:1.12.0")
}
