/*import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround: set missing namespace for third-party plugins that haven't migrated yet (e.g., msal_flutter)
subprojects {
    if (name == "msal_flutter") {
        plugins.withId("com.android.library") {
            // Ensure the Android namespace is present for AGP 8+
            extensions.configure<LibraryExtension>("android") {
                namespace = "uk.co.moodio.msal_flutter"
            }
            // Align Kotlin JVM target with Java (fixes: Kotlin=21 vs Java=1.8)
            tasks.withType<KotlinCompile>().configureEach {
                kotlinOptions {
                    jvmTarget = "1.8"
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}


 */

import com.android.build.gradle.LibraryExtension
import org.jetbrains.kotlin.gradle.tasks.KotlinCompile





//adding the block below fo rfirebase


/*plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}


 */
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Workaround: set missing namespace for third-party plugins that haven't migrated yet (e.g., msal_flutter)
subprojects {
    if (name == "msal_flutter") {
        plugins.withId("com.android.library") {
            extensions.configure<LibraryExtension>("android") {
                namespace = "uk.co.moodio.msal_flutter"
                compileOptions {
                    sourceCompatibility = JavaVersion.VERSION_1_8
                    targetCompatibility = JavaVersion.VERSION_1_8
                }
            }
        }
        // Force Kotlin JVM target to match Java
        tasks.withType<KotlinCompile> {
            kotlinOptions {

                jvmTarget = "1.8"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}