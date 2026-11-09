package com.afcreeper.crepcraft.storage

import org.godotengine.godot.Godot
import org.godotengine.godot.plugin.GodotPlugin
import org.godotengine.godot.plugin.UsedByGodot

class CrepCraftStoragePlugin(godot: Godot) : GodotPlugin(godot) {
    override fun getPluginName(): String = "CrepCraftStorage"

    @UsedByGodot
    fun getExternalFilesDir(): String {
        val directory = activity?.getExternalFilesDir(null) ?: return ""
        return directory.absolutePath
    }
}
