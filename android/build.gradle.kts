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

subprojects {
    plugins.withId("com.android.library") {
        val android = project.extensions.getByName("android") as com.android.build.gradle.LibraryExtension
        if (android.namespace == null) {
            val manifestFile = project.file("src/main/AndroidManifest.xml")
            if (manifestFile.exists()) {
                val manifestContent = manifestFile.readText()
                val packageRegex = """package=["']([^"']+)["']""".toRegex()
                val matchResult = packageRegex.find(manifestContent)
                if (matchResult != null) {
                    android.namespace = matchResult.groupValues[1]
                } else {
                    android.namespace = "com.example." + project.name.replace("-", "_")
                }
            } else {
                android.namespace = "com.example." + project.name.replace("-", "_")
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
