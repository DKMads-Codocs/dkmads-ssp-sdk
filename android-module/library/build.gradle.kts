plugins {
  id("com.android.library")
  id("org.jetbrains.kotlin.android")
  id("maven-publish")
  id("signing")
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
  implementation("androidx.media3:media3-exoplayer:1.4.1")
  implementation("androidx.media3:media3-exoplayer-hls:1.4.1")
  implementation("androidx.media3:media3-ui:1.4.1")
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
          developers {
            developer {
              id.set("dkmads")
              name.set("DKMads")
              email.set("sdk@dkmads.com")
            }
          }
          scm {
            connection.set("scm:git:https://github.com/DKMads-Codocs/dkmads-ssp-sdk.git")
            developerConnection.set("scm:git:ssh://git@github.com/DKMads-Codocs/dkmads-ssp-sdk.git")
            url.set("https://github.com/DKMads-Codocs/dkmads-ssp-sdk")
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
      // Maven Central via Sonatype OSSRH staging. Set OSSRH_USERNAME / OSSRH_PASSWORD
      // (user token) to enable; otherwise this repository is skipped for local builds.
      val ossrhUser = System.getenv("OSSRH_USERNAME")
      val ossrhPassword = System.getenv("OSSRH_PASSWORD")
      if (!ossrhUser.isNullOrBlank() && !ossrhPassword.isNullOrBlank()) {
        maven {
          name = "mavenCentral"
          url = uri("https://s01.oss.sonatype.org/service/local/staging/deploy/maven2/")
          credentials {
            username = ossrhUser
            password = ossrhPassword
          }
        }
      }
    }
  }

  // Artifact signing is required by Maven Central. Provide an ASCII-armored key
  // and passphrase via env (in-memory keys avoid a keyring on CI).
  signing {
    val signingKey = System.getenv("SIGNING_KEY")
    val signingPassword = System.getenv("SIGNING_PASSWORD")
    if (!signingKey.isNullOrBlank()) {
      useInMemoryPgpKeys(signingKey, signingPassword)
      sign(publishing.publications)
    }
  }
}
