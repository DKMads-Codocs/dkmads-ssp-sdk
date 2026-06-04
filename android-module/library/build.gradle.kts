plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
  id("maven-publish")
}

group = providers.gradleProperty("GROUP").get()
version = providers.gradleProperty("VERSION_NAME").get()

android {
  namespace = "com.dkmads.ssp"
  compileSdk = 35

  defaultConfig {
    minSdk = 23
    consumerProguardFiles("consumer-rules.pro")
  }

  compileOptions {
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
  }
  kotlinOptions {
    jvmTarget = "17"
  }

  sourceSets {
    getByName("main") {
      manifest.srcFile("src/main/AndroidManifest.xml")
      java.srcDirs("../../android")
    }
  }

  publishing {
    singleVariant("release") {
      withSourcesJar()
    }
  }
}

dependencies {
  implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.1")
}

// sdk/android/sample is reference-only; not part of the published AAR.
tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
  exclude("**/sample/**")
}

afterEvaluate {
  publishing {
    publications {
      create<MavenPublication>("release") {
        from(components["release"])
        groupId = providers.gradleProperty("GROUP").get()
        artifactId = providers.gradleProperty("POM_ARTIFACT_ID").get()
        version = providers.gradleProperty("VERSION_NAME").get()

        pom {
          name.set("DKMads SSP Android SDK")
          description.set("Android SDK for DKMads SSP ad loading, telemetry, and video lifecycle tracking.")
          url.set("https://github.com/DKMads-Codocs/dkmads-ssp-sdk")
          licenses {
            license {
              name.set("MIT")
              url.set("https://opensource.org/licenses/MIT")
            }
          }
        }
      }
    }
    repositories {
      maven {
        name = "localSdk"
        url = uri(layout.buildDirectory.dir("repo"))
      }
      val ghUser = System.getenv("GITHUB_ACTOR")
      val ghToken = System.getenv("GITHUB_TOKEN")
      if (!ghUser.isNullOrBlank() && !ghToken.isNullOrBlank()) {
        maven {
          name = "githubPackages"
          url = uri("https://maven.pkg.github.com/DKMads-Codocs/dkmads-ssp-sdk")
          credentials {
            username = ghUser
            password = ghToken
          }
        }
      }
    }
  }
}
