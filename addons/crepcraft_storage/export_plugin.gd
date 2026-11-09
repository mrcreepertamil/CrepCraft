@tool
extends EditorPlugin

var _export_plugin: AndroidStorageExportPlugin

func _enter_tree() -> void:
	_export_plugin = AndroidStorageExportPlugin.new()
	add_export_plugin(_export_plugin)

func _exit_tree() -> void:
	if _export_plugin != null:
		remove_export_plugin(_export_plugin)
		_export_plugin = null

class AndroidStorageExportPlugin extends EditorExportPlugin:
	const PLUGIN_NAME := "CrepCraftStorage"

	func _supports_platform(platform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform, debug: bool) -> PackedStringArray:
		var variant := "debug" if debug else "release"
		var library_path := "crepcraft_storage/bin/%s/crepcraft-storage-%s.aar" % [variant, variant]
		if not FileAccess.file_exists("res://addons/" + library_path):
			push_error("Missing Android storage plugin AAR: " + library_path + ". Build it with the GitHub Actions workflow and copy the artifact into addons/crepcraft_storage/bin/.")
			return PackedStringArray()
		return PackedStringArray([library_path])

	func _get_name() -> String:
		return PLUGIN_NAME
