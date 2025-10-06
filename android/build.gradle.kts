// android/build.gradle.kts (PROJECT-level) - safe evaluation-time compileSdk settings
import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension
import org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension

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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}

// --- Ensure consistent connect-client and safe per-module compileSdk / JVM toolchain ---
subprojects {
    // Force a single connect-client version project-wide to avoid ABI mismatches.
    configurations.all {
        resolutionStrategy.force("androidx.health.connect:connect-client:1.1.0-alpha11")
    }

    // Configure application modules at evaluation time
    plugins.withId("com.android.application") {
        extensions.findByType(ApplicationExtension::class.java)?.let { ext ->
            // Set compileSdk for app modules (evaluation-time, safe)
            @Suppress("UnstableApiUsage")
            ext.compileSdk = 36
        }
    }

    // Configure library modules (plugins) at evaluation time
    plugins.withId("com.android.library") {
        extensions.findByType(LibraryExtension::class.java)?.let { ext ->
            // Set compileSdk for library modules (evaluation-time, safe)
            @Suppress("UnstableApiUsage")
            ext.compileSdk = 36

            // Fallback namespace for libs that forgot to set it (helps with AGP 8+)
            if (ext.namespace.isNullOrBlank()) {
                val manifest = file("src/main/AndroidManifest.xml")
                val pkg: String? = if (manifest.exists()) {
                    Regex("""package="([^"]+)"""").find(manifest.readText())?.groupValues?.get(1)
                } else null
                ext.namespace = pkg ?: "dev.flutter.plugins.${project.name.replace("-", "_")}"
                println("Applied fallback namespace '${ext.namespace}' to module '${project.path}'")
            }
        }
    }

    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.findByType(org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension::class.java)
            ?.jvmToolchain(17)
    }
    plugins.withId("org.jetbrains.kotlin.jvm") {
        extensions.findByType(org.jetbrains.kotlin.gradle.dsl.KotlinJvmProjectExtension::class.java)
            ?.jvmToolchain(17)
    }
}
