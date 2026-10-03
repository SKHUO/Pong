extends Node

signal lobby_ready(host_side: int, client_side: int)
signal connection_failed(message: String)
signal session_ended(message: String)

const DEFAULT_PORT := 7788
const MAX_CLIENTS := 1

var mode := GameSession.Mode.OFFLINE
var local_side := PlayerSide.NONE
var _connected_peer_id := 0


func _ready() -> void:
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func host_game() -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_server(DEFAULT_PORT, MAX_CLIENTS)
	if error != OK:
		return error

	multiplayer.multiplayer_peer = peer
	mode = GameSession.Mode.ONLINE
	local_side = PlayerSide.PLAYER_1
	GameSession.set_online_mode(local_side)
	return OK


func join_game(host_address: String) -> Error:
	close()
	var peer := ENetMultiplayerPeer.new()
	var error := peer.create_client(host_address, DEFAULT_PORT)
	if error != OK:
		return error

	multiplayer.multiplayer_peer = peer
	mode = GameSession.Mode.ONLINE
	local_side = PlayerSide.PLAYER_2
	GameSession.set_online_mode(local_side)
	return OK


func close() -> void:
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null
	_connected_peer_id = 0
	mode = GameSession.Mode.OFFLINE
	local_side = PlayerSide.NONE


func is_online() -> bool:
	return mode == GameSession.Mode.ONLINE


func is_host() -> bool:
	return is_online() and multiplayer.is_server()


func get_connected_peer_id() -> int:
	return _connected_peer_id


func _on_peer_connected(peer_id: int) -> void:
	if not is_host() or _connected_peer_id != 0:
		return

	_connected_peer_id = peer_id
	rpc("_client_enter_lobby")
	lobby_ready.emit(PlayerSide.PLAYER_1, PlayerSide.PLAYER_2)


func _on_peer_disconnected(peer_id: int) -> void:
	if not is_host():
		return
	if peer_id != _connected_peer_id:
		return

	_connected_peer_id = 0
	_finish_session("对手已离开房间。")


func _on_connected_to_server() -> void:
	if is_host():
		return

	var peers := multiplayer.get_peers()
	if peers.is_empty():
		return

	_connected_peer_id = peers[0]


func _on_connection_failed() -> void:
	close()
	connection_failed.emit("连接失败，请检查 IP 地址和房主网络。")


func _on_server_disconnected() -> void:
	_connected_peer_id = 0
	mode = GameSession.Mode.OFFLINE
	local_side = PlayerSide.NONE
	session_ended.emit("房主已断开连接。")


@rpc("authority", "call_remote", "reliable")
func _client_enter_lobby() -> void:
	if is_host():
		return

	lobby_ready.emit(PlayerSide.PLAYER_1, PlayerSide.PLAYER_2)


func _finish_session(message: String) -> void:
	close()
	session_ended.emit(message)
