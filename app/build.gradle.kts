import java.util.Properties

plugins {
    alias(libs.plugins.android.application)
}

// 업로드 키. keystore.properties 와 upload.jks 는 **git 에 없다**(.gitignore).
// 없으면 디버그 키로 서명해 빌드만 되게 두고, 있으면 릴리스 키로 서명한다 —
// 다른 사람이 저장소만 받아도 빌드가 깨지지 않게.
val keystoreProps = Properties().apply {
    val f = rootProject.file("keystore.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = keystoreProps.getProperty("storeFile") != null &&
    rootProject.file(keystoreProps.getProperty("storeFile")).exists()

android {
    namespace = "com.piyak.english"
    compileSdk = 36

    defaultConfig {
        applicationId = "com.peep.english"
        minSdk = 26
        targetSdk = 36
        versionCode = 83
        versionName = "3.64"
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(keystoreProps.getProperty("storeFile"))
                storePassword = keystoreProps.getProperty("storePassword")
                keyAlias = keystoreProps.getProperty("keyAlias")
                keyPassword = keystoreProps.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // 코드·리소스를 줄인다. **이름으로 찾아 쓰는** 그림(word_*, ck_* …)은
            // res/raw/keep.xml 이 지켜 준다 — 없으면 릴리스에서만 조용히 사라져서
            // 디버그로는 절대 재현 안 되는 사고가 난다.
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
            // 업로드 키가 있으면 그걸로, 없으면 디버그 키로 (빌드는 항상 되게)
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
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
