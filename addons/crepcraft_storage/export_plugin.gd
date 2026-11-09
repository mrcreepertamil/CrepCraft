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

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		var variant := "debug" if debug else "release"
		var library_path := "crepcraft_storage/bin/%s/crepcraft-storage-%s.aar" % [variant, variant]
		return PackedStringArray([library_path])

	func _get_name() -> String:
		return PLUGIN_NAME
