allprojects {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

val newBuildDir = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Switch off ALL lint tasks for the app and every plugin module:
// the failing task was :image_picker_android:lintVitalAnalyzeRelease.
// AGP 9's bundled lint needs JDK 21 but this build runs on JDK 17,
// so the lint tool itself crashes while parsing a plugin's Java file
// (NoSuchMethodError: List.removeLast). Lint only checks code
// quality — it does not change the APK. (The plugin modules' own
// build.gradle files live in the Pub cache and cannot be edited,
// so lint is switched off centrally here for all modules.)
// NOTE: checkReleaseBuilds cannot be set from here — AGP reads it
// before this runs ("It is too late to set checkReleaseBuilds").
// Disabling the lint tasks themselves works at any point during
// configuration, and is the in-script equivalent of building
// with -x lintVitalAnalyzeRelease.
subprojects {
    tasks.configureEach {
        if (name.startsWith("lint")) {
            enabled = false
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
