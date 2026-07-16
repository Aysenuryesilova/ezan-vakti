plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.aysenuryesilova.ezanvakti"
    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.aysenuryesilova.ezanvakti"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = 1
        versionName = "1.0"
    }

    // İmzalandırma ayarları buraya!
    signingConfigs {
        create("release") {
            keyAlias = "upload"
            keyPassword = "0649.44a58"
            storeFile = file("upload-keystore.jks")
            storePassword = "0649.44a58"
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            // Kod küçültmeyi (minify) ve kaynak küçültmeyi (shrink) aktif ediyoruz
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}