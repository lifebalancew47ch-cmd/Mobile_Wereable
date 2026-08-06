import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firebase (google-services) se aplica SOLO si existe google-services.json.
// Así el build funciona sin configurar el proyecto Firebase (CI, dev) y se
// activa automáticamente cuando se añade el archivo. El plugin ya está
// declarado en settings.gradle.kts con `apply false`.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

android {
    namespace = "com.example.lifebalance"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    @Suppress("DEPRECATION")
    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        // applicationId debe coincidir con el package_name registrado en
        // google-services.json (com.example.lifebalance). Para publicar en
        // Play Store con un ID distinto, primero actualiza el proyecto
        // Firebase en la consola y descarga un nuevo google-services.json.
        applicationId = "com.example.lifebalance"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // Auditoria 6/08/2026 (C-03): keystore de release propia, leída desde
    // android/key.properties (NO versionado — ver .gitignore y
    // key.properties.example). Deliberadamente NO se lanza una excepción en
    // tiempo de configuración si el archivo falta: eso rompería `flutter run`
    // en debug y el sync de Android Studio para cualquiera que aún no haya
    // generado su keystore. En su lugar, sin key.properties el signingConfig
    // "release" queda con storeFile/contraseñas nulas — AGP falla la firma
    // (y por lo tanto assembleRelease/bundleRelease) recién en tiempo de
    // ejecución de esa tarea concreta. Lo importante es que YA NO existe el
    // fallback a `signingConfigs.getByName("debug")` de antes: un release
    // nunca puede quedar firmado con la keystore de debug, ni por accidente.
    val keystorePropertiesFile = rootProject.file("key.properties")
    val keystoreProperties = Properties()
    if (keystorePropertiesFile.exists()) {
        keystoreProperties.load(FileInputStream(keystorePropertiesFile))
    }

    signingConfigs {
        create("release") {
            val storeFilePath = keystoreProperties.getProperty("storeFile")
            if (storeFilePath != null) {
                storeFile = file(storeFilePath)
            }
            storePassword = keystoreProperties.getProperty("storePassword")
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
        }
    }

    buildTypes {
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"))
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation("com.google.android.gms:play-services-wearable:18.1.0")
    wearApp(project(":wear"))
}
