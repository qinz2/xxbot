class_name ScreenCaptureManager
extends Node

## Screen capture manager for capturing and saving screenshots
## Handles cross-platform screen capture functionality

# Signals
signal screenshot_started()
signal screenshot_completed(file_path: String)
signal screenshot_failed(error_message: String)
signal screenshot_warning(warning_message: String)

# Configuration
const SCREENSHOT_DIR = "user://screenshots/"
const MAX_SCREENSHOTS = 100

## Captures the current screen and saves it to disk
func capture_screen() -> void:
	screenshot_started.emit()
	print("[ScreenCapture] Starting screen capture...")
	
	# Get the primary screen image
	var screen_id = DisplayServer.get_primary_screen()
	var image = DisplayServer.screen_get_image(screen_id)
	
	if image == null:
		var error_msg = "Failed to capture screen: DisplayServer.screen_get_image() returned null"
		print("[ERROR] ", error_msg)
		screenshot_failed.emit(error_msg)
		return
	
	# Ensure directory exists
	if not _ensure_directory_exists():
		var error_msg = "Failed to create screenshot directory"
		print("[ERROR] ", error_msg)
		screenshot_failed.emit(error_msg)
		return
	
	# Generate filename and full path
	var filename = _generate_filename()
	var full_path = SCREENSHOT_DIR + filename
	
	# Save the image
	var save_error = _save_image(image, full_path)
	if save_error != OK:
		var error_msg = "Failed to save screenshot: " + error_string(save_error)
		print("[ERROR] ", error_msg)
		screenshot_failed.emit(error_msg)
		return
	
	# Success
	var absolute_path = ProjectSettings.globalize_path(full_path)
	print("[ScreenCapture] Screenshot saved successfully: ", absolute_path)
	screenshot_completed.emit(absolute_path)
	
	# Check if there are too many screenshots
	_check_screenshot_count()

## Returns the screenshot directory path
func get_screenshot_directory() -> String:
	return SCREENSHOT_DIR

## Returns the count of screenshots in the directory
func get_screenshot_count() -> int:
	var dir = DirAccess.open(SCREENSHOT_DIR)
	if dir == null:
		return 0
	
	var count = 0
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			count += 1
		file_name = dir.get_next()
	dir.list_dir_end()
	
	return count

## Cleans up old screenshots if count exceeds max_count
func cleanup_old_screenshots(max_count: int = MAX_SCREENSHOTS) -> void:
	var dir = DirAccess.open(SCREENSHOT_DIR)
	if dir == null:
		print("[WARNING] Cannot open screenshot directory for cleanup")
		return
	
	# Get all screenshot files with timestamps
	var files = []
	dir.list_dir_begin()
	var file_name = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var full_path = SCREENSHOT_DIR + file_name
			var modified_time = FileAccess.get_modified_time(full_path)
			files.append({"name": file_name, "time": modified_time})
		file_name = dir.get_next()
	dir.list_dir_end()
	
	# If count is within limit, no cleanup needed
	if files.size() <= max_count:
		return
	
	# Sort by time (oldest first)
	files.sort_custom(func(a, b): return a["time"] < b["time"])
	
	# Delete oldest files
	var to_delete = files.size() - max_count
	for i in range(to_delete):
		var file_path = SCREENSHOT_DIR + files[i]["name"]
		var error = DirAccess.remove_absolute(ProjectSettings.globalize_path(file_path))
		if error == OK:
			print("[INFO] Deleted old screenshot: ", files[i]["name"])
		else:
			print("[WARNING] Failed to delete screenshot: ", files[i]["name"])

## Generates a timestamp-based filename
func _generate_filename() -> String:
	var datetime = Time.get_datetime_dict_from_system()
	var filename = "screenshot_%04d%02d%02d_%02d%02d%02d.png" % [
		datetime.year,
		datetime.month,
		datetime.day,
		datetime.hour,
		datetime.minute,
		datetime.second
	]
	return filename

## Ensures the screenshot directory exists
func _ensure_directory_exists() -> bool:
	var dir = DirAccess.open("user://")
	if dir == null:
		print("[ERROR] Cannot access user:// directory")
		return false
	
	if not dir.dir_exists(SCREENSHOT_DIR):
		var error = dir.make_dir_recursive(SCREENSHOT_DIR)
		if error != OK:
			print("[ERROR] Failed to create directory: ", SCREENSHOT_DIR, " Error: ", error_string(error))
			return false
		print("[INFO] Created screenshot directory: ", SCREENSHOT_DIR)
	
	return true

## Saves an image to the specified path
func _save_image(image: Image, path: String) -> Error:
	var error = image.save_png(path)
	if error != OK:
		print("[ERROR] Failed to save PNG: ", error_string(error))
	return error

## Checks screenshot count and emits warning if too many
func _check_screenshot_count() -> void:
	var count = get_screenshot_count()
	if count > MAX_SCREENSHOTS:
		var warning_msg = "截图文件过多（%d个），建议清理旧文件" % count
		print("[WARNING] ", warning_msg)
		screenshot_warning.emit(warning_msg)
