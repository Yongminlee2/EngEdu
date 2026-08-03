plugins {
    alias(libs.plugins.android.application)
}

android {
    namespace = "com.piyak.english"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.piyak.english"
        minSdk = 26
        targetSdk = 36
        versionCode = 48
        versionName = "3.29"
    }

    buildTypes {
        release {
            isMinifyEnabled = false
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    buildFeatures {
        viewBinding = true
    }
}

dependencies {
    implementation(libs.androidx.core.ktx)
    implementation(libs.androidx.appcompat)
    implementation(libs.material)
    implementation(libs.androidx.activity.ktx)
    implementation(libs.androidx.constraintlayout)
    testImplementation(libs.junit)
    testImplementation(libs.json)
}
