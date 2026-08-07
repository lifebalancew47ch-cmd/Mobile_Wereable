plugins {
    id("com.android.application")
    id("kotlin-android")
}

android {
    namespace = "com.example.lifebalance"
    compileSdk = 34

    defaultConfig {
        // Auditoria 6/08/2026 (C-03): debe coincidir con el applicationId del
        // módulo :app — el mecanismo `wearApp(project(":wear"))` de Gradle
        // exige el mismo package name para empaquetar el Wear OS app dentro
        // del APK del teléfono.
        applicationId = "com.lifebalance.app"
        minSdk = 30
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    buildFeatures {
        // WearLog.kt y el código dependen de BuildConfig.DEBUG en tiempo de
        // compilación (no-op de logs fuera de debug).
        buildConfig = true
    }
    @Suppress("DEPRECATION")
    kotlinOptions {
        jvmTarget = "11"
    }
}

dependencies {
    implementation("androidx.core:core-ktx:1.12.0")
    implementation("com.google.android.gms:play-services-wearable:18.1.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-play-services:1.7.3")
    implementation("androidx.wear:wear:1.3.0")
    implementation("androidx.health:health-services-client:1.1.0-rc02")
}
