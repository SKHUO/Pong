extends Node2D
class_name ModeSelect


const CHARACTER_SELECT_SCENE_PATH := "res://scenes/character_select/character_select.tscn"

@onready var local_button: Button = $UI/LocalButton
@onready var host_button: Button = $UI/HostButton
@onready var join_button: Button = $UI/JoinButton
@onready var back_button: Button = $UI/BackButton
@onready var address_input: LineEdit = $UI/AddressInput
@onready var status_label: Label = $UI/Status
@onready var address_label: Label = $UI/AddressHint


func _ready() -> void:
	RenderingServer.set_default_clear_color(PongPalette.BACKGROUND)
	NetworkManager.close()
	local_button.pressed.connect(_on_local_pressed)
	host_button.pressed.connect(_on_host_pressed)
	join_button.pressed.connect(_on_join_pressed)
	back_button.pressed.connect(_on_back_pressed)
	address_input.text_submitted.connect(_on_address_submitted)
	NetworkManager.connection_failed.connect(_on_connection_failed)
	NetworkManager.lobby_ready.connect(_on_lobby_ready)
	NetworkManager.session_ended.connect(_on_session_ended)
	address_input.grab_focus()


func _on_local_pressed() -> void:
	NetworkManager.close()
	GameSession.set_offline_mode()
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE_PATH)


func _on_host_pressed() -> void:
	var error := NetworkManager.host_game()
	if error != OK:
		_show_error("无法创建房间，端口 %d 可能已被占用。" % NetworkManager.DEFAULT_PORT)
		return

	_set_connecting_state(false)
	status_label.text = "房间已创建，等待玩家加入……"
	address_label.text = "房主地址：%s    端口：%d" % [
		_get_local_address_text(),
		NetworkManager.DEFAULT_PORT,
	]
	host_button.disabled = true
	join_button.disabled = true
	address_input.editable = false


func _on_join_pressed() -> void:
	_join_room(address_input.text.strip_edges())


func _on_address_submitted(_new_text: String) -> void:
	_on_join_pressed()


func _join_room(host_address: String) -> void:
	if host_address.is_empty():
		_show_error("请输入房主的 IP 地址。")
		address_input.grab_focus()
		return

	var error := NetworkManager.join_game(host_address)
	if error != OK:
		_show_error("无法发起连接，请检查 IP 地址。")
		return

	_set_connecting_state(true)
	status_label.text = "正在连接 %s:%d……" % [
		host_address,
		NetworkManager.DEFAULT_PORT,
	]
	address_label.text = "请确认双方处于可互相访问的网络。"


func _on_back_pressed() -> void:
	NetworkManager.close()
	_reset_ui()
	status_label.text = "已取消连接。"


func _on_connection_failed(message: String) -> void:
	_reset_ui()
	_show_error(message)


func _on_lobby_ready(_host_side: int, _client_side: int) -> void:
	status_label.text = "两名玩家已就位，正在进入角色选择……"
	get_tree().change_scene_to_file(CHARACTER_SELECT_SCENE_PATH)


func _on_session_ended(message: String) -> void:
	_reset_ui()
	status_label.text = message


func _set_connecting_state(is_joining: bool) -> void:
	local_button.disabled = true
	host_button.disabled = true
	join_button.disabled = true
	back_button.disabled = false
	address_input.editable = false
	if is_joining:
		address_input.release_focus()


func _reset_ui() -> void:
	local_button.disabled = false
	host_button.disabled = false
	join_button.disabled = false
	back_button.disabled = true
	address_input.editable = true
	status_label.add_theme_color_override("font_color", PongPalette.NEUTRAL)
	address_label.text = "房主需开放 UDP 端口 %d。" % NetworkManager.DEFAULT_PORT
	if not address_input.has_focus():
		address_input.grab_focus()


func _show_error(message: String) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", PongPalette.PLAYER_2)


func _get_local_address_text() -> String:
	var addresses: Array[String] = []
	for address in IP.get_local_addresses():
		var text := String(address)
		if (
			text.contains(".")
			and not text.begins_with("127.")
			and not text.begins_with("169.254.")
			and not addresses.has(text)
		):
			addresses.append(text)

	if addresses.is_empty():
		return "127.0.0.1"
	return ", ".join(PackedStringArray(addresses))
