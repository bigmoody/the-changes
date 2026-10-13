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
// Every plugin compiled against the same Android APIs as the app.
//
// Some of them pin an older compileSdk of their own, and one of those
// depends on something that refuses to be used by anything older than
// 36, so the whole Android build fails at a metadata check before a line
// of this app is compiled. compileSdk is only which APIs are available
// to compile against: minSdk, which decides what the app installs on,
// and targetSdk, which opts in to new behaviour, are untouched.
//
// Registered before the block below, which evaluates every subproject:
// after that, there is nothing left to hook.
subprojects {
    afterEvaluate {
        val android = extensions.findByName("android")
        if (android is com.android.build.api.dsl.LibraryExtension) {
            android.compileSdk = 36
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
