import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val localKeystorePropertiesFile = rootProject.file("key.properties")
val envKeystorePropertiesFile = System.getenv("BLOCKREELS_KEY_PROPERTIES")
    ?.takeIf { it.isNotBlank() }
    ?.let { file(it) }
val defaultExternalKeystorePropertiesFile = File(
    System.getProperty("user.home"),
    ".config/blockreels-signing/key.properties"
)
val keystorePropertiesFile = when {
    envKeystorePropertiesFile != null -> envKeystorePropertiesFile
    localKeystorePropertiesFile.exists() -> localKeystorePropertiesFile
    defaultExternalKeystorePropertiesFile.exists() -> defaultExternalKeystorePropertiesFile
    else -> null
}
val keystoreProperties = Properties().apply {
    if (keystorePropertiesFile != null) {
        FileInputStream(keystorePropertiesFile).use { load(it) }
    }
}

fun signingProperty(envName: String, propertyName: String): String? =
    System.getenv(envName)?.takeIf { it.isNotBlank() }
        ?: keystoreProperties.getProperty(propertyName)?.takeIf { it.isNotBlank() }

val signingStoreFilePath = signingProperty("BLOCKREELS_KEYSTORE_FILE", "storeFile")
val signingStorePassword = signingProperty("BLOCKREELS_STORE_PASSWORD", "storePassword")
val signingKeyAlias = signingProperty("BLOCKREELS_KEY_ALIAS", "keyAlias")
val signingKeyPassword = signingProperty("BLOCKREELS_KEY_PASSWORD", "keyPassword")
val resolvedStoreFile = signingStoreFilePath?.let { path ->
    val candidate = File(path)
    if (candidate.isAbsolute) {
        candidate
    } else {
        keystorePropertiesFile?.parentFile?.resolve(path) ?: candidate
    }
}
val hasReleaseSigning = resolvedStoreFile != null &&
    signingStorePassword != null &&
    signingKeyAlias != null &&
    signingKeyPassword != null

val isReleaseBuild = gradle.startParameter.taskNames.any {
    it.contains("Release", ignoreCase = true)
}
if (isReleaseBuild && !hasReleaseSigning) {
    throw GradleException(
        "Release signing is not configured. Set BLOCKREELS_KEY_PROPERTIES to a key.properties file, " +
            "place key.properties in android/, or use ~/.config/blockreels-signing/key.properties. " +
            "See android/key.properties.example."
    )
}

android {
    namespace = "com.blockreels.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.blockreels.app"
        minSdk = 24
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (hasReleaseSigning) {
                keyAlias = signingKeyAlias
                keyPassword = signingKeyPassword
                storeFile = resolvedStoreFile
                storePassword = signingStorePassword
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.datastore:datastore-preferences:1.0.0")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.8.1")

    testImplementation("junit:junit:4.13.2")
}
