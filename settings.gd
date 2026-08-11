extends Node


const BASE_SIZE := Vector2i(640, 360)
const WINDOW_SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	var window := get_window()

	window.content_scale_size = BASE_SIZE
	window.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	window.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_INTEGER
	window.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST

	window.mode = Window.MODE_WINDOWED
	window.size = WINDOW_SIZE

	await get_tree().process_frame

	var screen_rect := DisplayServer.screen_get_usable_rect(window.current_screen)
	window.position = screen_rect.position + (screen_rect.size - window.size) / 2
