plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
}

// This single 'allprojects' block will configure repositories and enforce the compileSdkVersion for all modules.
allprojects {
    // 1. Set up repositories for all modules (app and plugins).
    repositories {
        google()
        mavenCentral()
    }

    // 2. 🔥 Force every Android module (like :video_thumbnail) to use the correct compileSdkVersion.
    // This runs after the project has been configured, ensuring it overrides any defaults.
    afterEvaluate {
        // Check if it's an Android library project.
        if (project.plugins.hasPlugin("com.android.library")) {
            // Safely access the 'android' extension.
            project.extensions.findByType<com.android.build.gradle.LibraryExtension>()?.let {
                // Set the compileSdk. It reads from gradle.properties (e.g., flutter.compileSdkVersion=36)
                it.compileSdk = (rootProject.property("flutter.compileSdkVersion") as String).toInt()
                it.buildFeatures.buildConfig = true
                if (it.namespace == null) {
                    val manifestFile = it.sourceSets.getByName("main").manifest.srcFile
                    if (manifestFile.exists()) {
                        val manifestText = manifestFile.readText()
                        // Using a regex to find the package name.
                        "package=\"([^\"]+)\"".toRegex().find(manifestText)?.let { matchResult ->
                             val packageName = matchResult.groupValues[1]
                             it.namespace = packageName
                        }
                    }
                }
            }
        }
    }
}

// The following blocks are standard Flutter configurations.
val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
