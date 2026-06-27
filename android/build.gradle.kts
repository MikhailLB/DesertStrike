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

// IMPORTANT: register the compileSdk override BEFORE evaluationDependsOn(":app"),
// otherwise Gradle has already evaluated subprojects by the time afterEvaluate
// is attached and throws:
//
//   Cannot run Project.afterEvaluate(Action) when the project is already evaluated.
//
// Older plugin releases ship with compileSdk=34 (or 33). Some of their
// transitive dependencies require compileSdk=36 and AGP's CheckAarMetadata
// aborts the build. We force a floor of 36 on every Android library subproject.
subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        extensions
            .findByType(com.android.build.gradle.LibraryExtension::class.java)
            ?.apply {
                if ((compileSdk ?: 0) < 36) {
                    compileSdk = 36
                }
            }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
