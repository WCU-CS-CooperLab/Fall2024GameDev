GDPC                0                                                                         P   res://.godot/exported/133200997/export-254818f4b91b5a7a67310bd8a2a483f5-main.scnp.      �      a�/PIb��
d�`a    X   res://.godot/exported/133200997/export-de0413ac4d87a0f11912173e72a085a3-client_ui.scn   p"      `	      Sy��m�d�X�^        res://.godot/extension_list.cfg �]              
bs�]]3�����*�B    ,   res://.godot/global_script_class_cache.cfg  `]             ��Р�8���8~$}P�       res://.godot/uid_cache.bin  �]      I       z>4:��j�BAعB?    $   res://client/multiplayer_client.gd          �      �4W,��b���o*�        res://client/ws_webrtc_client.gd�      R      �7w]�����`/�I?       res://demo/client_ui.gd �      r      ұ�p��؅���3V8S�        res://demo/client_ui.tscn.remap �\      f       ���� Z�ӏ ��OH       res://demo/main.gd  �+      �      � >��?|�	ƫ���       res://demo/main.tscn.remap  �\      a       �hC��kg��+AY��       res://project.binary�]      �      ^C�RӪ��6�w�Z'�        res://server/ws_webrtc_server.gd`7      �      )H�[,�j�����В        res://server_node/package.json   O      �      �U3��?����}���       res://webrtc/LICENSE.json   Q      4      �i}{~Ш�<+�� %�        res://webrtc/webrtc.gdextension PU      +      �s�
�
���(2���    extends "ws_webrtc_client.gd"

var rtc_mp := WebRTCMultiplayerPeer.new()
var sealed := false

func _init() -> void:
	connected.connect(_connected)
	disconnected.connect(_disconnected)

	offer_received.connect(_offer_received)
	answer_received.connect(_answer_received)
	candidate_received.connect(_candidate_received)

	lobby_joined.connect(_lobby_joined)
	lobby_sealed.connect(_lobby_sealed)
	peer_connected.connect(_peer_connected)
	peer_disconnected.connect(_peer_disconnected)


func start(url: String, _lobby: String = "", _mesh: bool = true) -> void:
	stop()
	sealed = false
	mesh = _mesh
	lobby = _lobby
	connect_to_url(url)


func stop() -> void:
	multiplayer.multiplayer_peer = null
	rtc_mp.close()
	close()


func _create_peer(id: int) -> WebRTCPeerConnection:
	var peer: WebRTCPeerConnection = WebRTCPeerConnection.new()
	# Use a public STUN server for moderate NAT traversal.
	# Note that STUN cannot punch through strict NATs (such as most mobile connections),
	# in which case TURN is required. TURN generally does not have public servers available,
	# as it requires much greater resources to host (all traffic goes through
	# the TURN server, instead of only performing the initial connection).
	peer.initialize({
		"iceServers": [ { "urls": ["stun:stun.l.google.com:19302"] } ]
	})
	peer.session_description_created.connect(_offer_created.bind(id))
	peer.ice_candidate_created.connect(_new_ice_candidate.bind(id))
	rtc_mp.add_peer(peer, id)
	if id < rtc_mp.get_unique_id():  # So lobby creator never creates offers.
		peer.create_offer()
	return peer


func _new_ice_candidate(mid_name: String, index_name: int, sdp_name: String, id: int) -> void:
	send_candidate(id, mid_name, index_name, sdp_name)


func _offer_created(type: String, data: String, id: int) -> void:
	if not rtc_mp.has_peer(id):
		return
	print("created", type)
	rtc_mp.get_peer(id).connection.set_local_description(type, data)
	if type == "offer": send_offer(id, data)
	else: send_answer(id, data)


func _connected(id: int, use_mesh: bool) -> void:
	print("Connected %d, mesh: %s" % [id, use_mesh])
	if use_mesh:
		rtc_mp.create_mesh(id)
	elif id == 1:
		rtc_mp.create_server()
	else:
		rtc_mp.create_client(id)
	multiplayer.multiplayer_peer = rtc_mp


func _lobby_joined(_lobby: String) -> void:
	lobby = _lobby


func _lobby_sealed() -> void:
	sealed = true


func _disconnected() -> void:
	print("Disconnected: %d: %s" % [code, reason])
	if not sealed:
		stop() # Unexpected disconnect


func _peer_connected(id: int) -> void:
	print("Peer connected: %d" % id)
	_create_peer(id)


func _peer_disconnected(id: int) -> void:
	if rtc_mp.has_peer(id):
		rtc_mp.remove_peer(id)


func _offer_received(id: int, offer: String) -> void:
	print("Got offer: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("offer", offer)


func _answer_received(id: int, answer: String) -> void:
	print("Got answer: %d" % id)
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.set_remote_description("answer", answer)


func _candidate_received(id: int, mid: String, index: int, sdp: String) -> void:
	if rtc_mp.has_peer(id):
		rtc_mp.get_peer(id).connection.add_ice_candidate(mid, index, sdp)
        extends Node

enum Message {
	JOIN,
	ID,
	PEER_CONNECT,
	PEER_DISCONNECT,
	OFFER,
	ANSWER,
	CANDIDATE,
	SEAL,
}

@export var autojoin := true
@export var lobby := ""  # Will create a new lobby if empty.
@export var mesh := true  # Will use the lobby host as relay otherwise.

var ws := WebSocketPeer.new()
var code := 1000
var reason := "Unknown"
var old_state := WebSocketPeer.STATE_CLOSED

signal lobby_joined(lobby: String)
signal connected(id: int, use_mesh: bool)
signal disconnected()
signal peer_connected(id: int)
signal peer_disconnected(id: int)
signal offer_received(id: int, offer: String)
signal answer_received(id: int, answer: String)
signal candidate_received(id: int, mid: String, index: int, sdp: String)
signal lobby_sealed()


func connect_to_url(url: String) -> void:
	close()
	code = 1000
	reason = "Unknown"
	ws.connect_to_url(url)


func close() -> void:
	ws.close()


func _process(_delta: float) -> void:
	ws.poll()
	var state := ws.get_ready_state()
	if state != old_state and state == WebSocketPeer.STATE_OPEN and autojoin:
		join_lobby(lobby)
	while state == WebSocketPeer.STATE_OPEN and ws.get_available_packet_count():
		if not _parse_msg():
			print("Error parsing message from server.")
	if state != old_state and state == WebSocketPeer.STATE_CLOSED:
		code = ws.get_close_code()
		reason = ws.get_close_reason()
		disconnected.emit()
	old_state = state


func _parse_msg() -> bool:
	var parsed: Dictionary = JSON.parse_string(ws.get_packet().get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("type") or not parsed.has("id") or \
		typeof(parsed.get("data")) != TYPE_STRING:
		return false

	var msg := parsed as Dictionary
	if not str(msg.type).is_valid_int() or not str(msg.id).is_valid_int():
		return false

	var type := str(msg.type).to_int()
	var src_id := str(msg.id).to_int()

	if type == Message.ID:
		connected.emit(src_id, msg.data == "true")
	elif type == Message.JOIN:
		lobby_joined.emit(msg.data)
	elif type == Message.SEAL:
		lobby_sealed.emit()
	elif type == Message.PEER_CONNECT:
		# Client connected.
		peer_connected.emit(src_id)
	elif type == Message.PEER_DISCONNECT:
		# Client connected.
		peer_disconnected.emit(src_id)
	elif type == Message.OFFER:
		# Offer received.
		offer_received.emit(src_id, msg.data)
	elif type == Message.ANSWER:
		# Answer received.
		answer_received.emit(src_id, msg.data)
	elif type == Message.CANDIDATE:
		# Candidate received.
		var candidate: PackedStringArray = msg.data.split("\n", false)
		if candidate.size() != 3:
			return false
		if not candidate[1].is_valid_int():
			return false
		candidate_received.emit(src_id, candidate[0], candidate[1].to_int(), candidate[2])
	else:
		return false

	return true  # Parsed.


func join_lobby(lobby: String) -> Error:
	return _send_msg(Message.JOIN, 0 if mesh else 1, lobby)


func seal_lobby() -> Error:
	return _send_msg(Message.SEAL, 0)


func send_candidate(id: int, mid: String, index: int, sdp: String) -> Error:
	return _send_msg(Message.CANDIDATE, id, "\n%s\n%d\n%s" % [mid, index, sdp])


func send_offer(id: int, offer: String) -> Error:
	return _send_msg(Message.OFFER, id, offer)


func send_answer(id: int, answer: String) -> Error:
	return _send_msg(Message.ANSWER, id, answer)


func _send_msg(type: int, id: int, data: String = "") -> Error:
	return ws.send_text(JSON.stringify({
		"type": type,
		"id": id,
		"data": data,
	}))
              extends Control

@onready var client: Node = $Client
@onready var host: LineEdit = $VBoxContainer/Connect/Host
@onready var room: LineEdit = $VBoxContainer/Connect/RoomSecret
@onready var mesh: CheckBox = $VBoxContainer/Connect/Mesh

func _ready() -> void:
	client.lobby_joined.connect(_lobby_joined)
	client.lobby_sealed.connect(_lobby_sealed)
	client.connected.connect(_connected)
	client.disconnected.connect(_disconnected)

	multiplayer.connected_to_server.connect(_mp_server_connected)
	multiplayer.connection_failed.connect(_mp_server_disconnect)
	multiplayer.server_disconnected.connect(_mp_server_disconnect)
	multiplayer.peer_connected.connect(_mp_peer_connected)
	multiplayer.peer_disconnected.connect(_mp_peer_disconnected)


@rpc("any_peer", "call_local")
func ping(argument: float) -> void:
	_log("[Multiplayer] Ping from peer %d: arg: %f" % [multiplayer.get_remote_sender_id(), argument])


func _mp_server_connected() -> void:
	_log("[Multiplayer] Server connected (I am %d)" % client.rtc_mp.get_unique_id())


func _mp_server_disconnect() -> void:
	_log("[Multiplayer] Server disconnected (I am %d)" % client.rtc_mp.get_unique_id())


func _mp_peer_connected(id: int) -> void:
	_log("[Multiplayer] Peer %d connected" % id)


func _mp_peer_disconnected(id: int) -> void:
	_log("[Multiplayer] Peer %d disconnected" % id)


func _connected(id: int, use_mesh: bool) -> void:
	_log("[Signaling] Server connected with ID: %d. Mesh: %s" % [id, use_mesh])


func _disconnected() -> void:
	_log("[Signaling] Server disconnected: %d - %s" % [client.code, client.reason])


func _lobby_joined(lobby: String) -> void:
	_log("[Signaling] Joined lobby %s" % lobby)


func _lobby_sealed() -> void:
	_log("[Signaling] Lobby has been sealed")


func _log(msg: String) -> void:
	print(msg)
	$VBoxContainer/TextEdit.text += str(msg) + "\n"


func _on_peers_pressed() -> void:
	_log(str(multiplayer.get_peers()))


func _on_ping_pressed() -> void:
	ping.rpc(randf())


func _on_seal_pressed() -> void:
	client.seal_lobby()


func _on_start_pressed() -> void:
	client.start(host.text, room.text, mesh.button_pressed)


func _on_stop_pressed() -> void:
	client.stop()
              RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script    res://demo/client_ui.gd ��������   Script #   res://client/multiplayer_client.gd ��������      local://PackedScene_yd4x3 I         PackedScene          	         names "   )   	   ClientUI    layout_mode    anchors_preset    offset_right    offset_bottom    size_flags_horizontal    size_flags_vertical    script    Control    Client    Node    VBoxContainer    anchor_right    anchor_bottom    grow_horizontal    grow_vertical    Connect    HBoxContainer    Label    text    Host 	   LineEdit    Room    RoomSecret    placeholder_text    Mesh    button_pressed 	   CheckBox    Start    Button    Stop    Seal    Ping    Peers 	   TextEdit    _on_start_pressed    pressed    _on_stop_pressed    _on_seal_pressed    _on_ping_pressed    _on_peers_pressed    	   variants                         �D     D                                    �?            Connect to:       ws://localhost:9080             Room       secret             Mesh       Start       Stop       Seal       Ping       Print peers       node_count             nodes     �   ��������       ����                                                            
   	   ����                           ����                              	      	                    ����      	                    ����      	      
                    ����      	                                 ����      	                                ����      	                          ����      	                                ����      	       	             ����      	             	             ����      	             	             ����      	             	              ����      	             	          !   ����      	                    "   "   ����      	                    conn_count             conns     #   
       $   #                     $   %                     $   &                     $   '                     $   (                    node_paths              editable_instances              version             RSRCextends Control

func _enter_tree() -> void:
	for c in $VBoxContainer/Clients.get_children():
		# So each child gets its own separate MultiplayerAPI.
		get_tree().set_multiplayer(
				MultiplayerAPI.create_default_interface(),
				NodePath("%s/VBoxContainer/Clients/%s" % [get_path(), c.name])
		)


func _ready() -> void:
	if OS.get_name() == "Web":
		$VBoxContainer/Signaling.hide()


func _on_listen_toggled(button_pressed: bool) -> void:
	if button_pressed:
		$Server.listen(int($VBoxContainer/Signaling/Port.value))
	else:
		$Server.stop()


func _on_LinkButton_pressed() -> void:
	OS.shell_open("https://github.com/godotengine/webrtc-native/releases")
              RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script    res://demo/main.gd ��������   PackedScene    res://demo/client_ui.tscn O��]��e   Script !   res://server/ws_webrtc_server.gd ��������      local://PackedScene_pm2bw x         PackedScene          	         names "   (      Control    layout_mode    anchor_left    anchor_top    anchor_right    anchor_bottom    script    VBoxContainer    grow_horizontal    grow_vertical 
   Signaling    HBoxContainer    Label    text    Port 
   min_value 
   max_value    value    SpinBox    ListenButton    toggle_mode    Button    CenterContainer    size_flags_horizontal    size_flags_vertical    LinkButton 	   modulate    Clients    columns    GridContainer 	   ClientUI 
   ClientUI2 
   ClientUI3 
   ClientUI4    Server    Node    _on_listen_toggled    toggled    _on_LinkButton_pressed    pressed    	   variants                 `<   ���<   �|?   ��{?                      �?            Signaling server:      �D    �G    �F            Listen      �?��t?��T>  �?   W   Make sure to download the GDExtension WebRTC Plugin and place it in the project folder                         node_count             nodes     �   ��������        ����                                                          ����                           	                    
   ����                          ����            	                    ����            
                                ����                                      ����                                        ����                                      ����                                        ���                          ���                          ���                           ���!                           #   "   ����                   conn_count             conns               %   $                     '   &                    node_paths              editable_instances              version             RSRC         extends Node

enum Message {
	JOIN,
	ID,
	PEER_CONNECT,
	PEER_DISCONNECT,
	OFFER,
	ANSWER,
	CANDIDATE,
	SEAL,
}

## Unresponsive clients time out after this time (in milliseconds).
const TIMEOUT = 1000

## A sealed room will be closed after this time (in milliseconds).
const SEAL_TIME = 10000

## All alphanumeric characters.
const ALFNUM = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"

var _alfnum := ALFNUM.to_ascii_buffer()

var rand: RandomNumberGenerator = RandomNumberGenerator.new()
var lobbies: Dictionary = {}
var tcp_server := TCPServer.new()
var peers: Dictionary = {}

class Peer extends RefCounted:
	var id := -1
	var lobby := ""
	var time := Time.get_ticks_msec()
	var ws := WebSocketPeer.new()


	func _init(peer_id: int, tcp: StreamPeer) -> void:
		id = peer_id
		ws.accept_stream(tcp)


	func is_ws_open() -> bool:
		return ws.get_ready_state() == WebSocketPeer.STATE_OPEN


	func send(type: int, id: int, data: String = "") -> void:
		return ws.send_text(JSON.stringify({
			"type": type,
			"id": id,
			"data": data,
		}))


class Lobby extends RefCounted:
	var peers := {}
	var host := -1
	var sealed := false
	var time := 0  # Value is in milliseconds.
	var mesh := true

	func _init(host_id: int, use_mesh: bool) -> void:
		host = host_id
		mesh = use_mesh

	func join(peer: Peer) -> bool:
		if sealed: return false
		if not peer.is_ws_open(): return false
		peer.send(Message.ID, (1 if peer.id == host else peer.id), "true" if mesh else "")
		for p: Peer in peers.values():
			if not p.is_ws_open():
				continue
			if not mesh and p.id != host:
				# Only host is visible when using client-server
				continue
			p.send(Message.PEER_CONNECT, peer.id)
			peer.send(Message.PEER_CONNECT, (1 if p.id == host else p.id))
		peers[peer.id] = peer
		return true


	func leave(peer: Peer) -> bool:
		if not peers.has(peer.id):
			return false

		peers.erase(peer.id)
		var close := false
		if peer.id == host:
			# The room host disconnected, will disconnect all peers.
			close = true
		if sealed:
			return close

		# Notify other peers.
		for p: Peer in peers.values():
			if not p.is_ws_open():
				continue
			if close:
				# Disconnect peers.
				p.ws.close()
			else:
				# Notify disconnection.
				p.send(Message.PEER_DISCONNECT, peer.id)

		return close


	func seal(peer_id: int) -> bool:
		# Only host can seal the room.
		if host != peer_id:
			return false

		sealed = true

		for p: Peer in peers.values():
			if not p.is_ws_open():
				continue
			p.send(Message.SEAL, 0)

		time = Time.get_ticks_msec()
		peers.clear()

		return true


func _process(_delta: float) -> void:
	poll()


func listen(port: int) -> void:
	if OS.has_feature("web"):
		OS.alert("Cannot create WebSocket servers in Web exports due to browsers' limitations.")
		return
	stop()
	rand.seed = int(Time.get_unix_time_from_system())
	tcp_server.listen(port)


func stop() -> void:
	tcp_server.stop()
	peers.clear()


func poll() -> void:
	if not tcp_server.is_listening():
		return

	if tcp_server.is_connection_available():
		var id := randi() % (1 << 31)
		peers[id] = Peer.new(id, tcp_server.take_connection())

	# Poll peers.
	var to_remove := []
	for p: Peer in peers.values():
		# Peers timeout.
		if p.lobby.is_empty() and Time.get_ticks_msec() - p.time > TIMEOUT:
			p.ws.close()
		p.ws.poll()
		while p.is_ws_open() and p.ws.get_available_packet_count():
			if not _parse_msg(p):
				print("Parse message failed from peer %d" % p.id)
				to_remove.push_back(p.id)
				p.ws.close()
				break
		var state := p.ws.get_ready_state()
		if state == WebSocketPeer.STATE_CLOSED:
			print("Peer %d disconnected from lobby: '%s'" % [p.id, p.lobby])
			# Remove from lobby (and lobby itself if host).
			if lobbies.has(p.lobby) and lobbies[p.lobby].leave(p):
				print("Deleted lobby %s" % p.lobby)
				lobbies.erase(p.lobby)
			# Remove from peers
			to_remove.push_back(p.id)

	# Lobby seal.
	for k: String in lobbies:
		if not lobbies[k].sealed:
			continue
		if lobbies[k].time + SEAL_TIME < Time.get_ticks_msec():
			# Close lobby.
			for p: Peer in lobbies[k].peers:
				p.ws.close()
				to_remove.push_back(p.id)

	# Remove stale peers
	for id: int in to_remove:
		peers.erase(id)


func _join_lobby(peer: Peer, lobby: String, mesh: bool) -> bool:
	if lobby.is_empty():
		for _i in 32:
			lobby += char(_alfnum[rand.randi_range(0, ALFNUM.length() - 1)])
		lobbies[lobby] = Lobby.new(peer.id, mesh)
	elif not lobbies.has(lobby):
		return false
	lobbies[lobby].join(peer)
	peer.lobby = lobby
	# Notify peer of its lobby
	peer.send(Message.JOIN, 0, lobby)
	print("Peer %d joined lobby: '%s'" % [peer.id, lobby])
	return true


func _parse_msg(peer: Peer) -> bool:
	var pkt_str: String = peer.ws.get_packet().get_string_from_utf8()
	var parsed: Dictionary = JSON.parse_string(pkt_str)
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("type") or not parsed.has("id") or \
		typeof(parsed.get("data")) != TYPE_STRING:
		return false
	if not str(parsed.type).is_valid_int() or not str(parsed.id).is_valid_int():
		return false

	var msg := {
		"type": str(parsed.type).to_int(),
		"id": str(parsed.id).to_int(),
		"data": parsed.data,
	}

	if msg.type == Message.JOIN:
		if peer.lobby:  # Peer must not have joined a lobby already!
			return false

		return _join_lobby(peer, msg.data, msg.id == 0)

	if not lobbies.has(peer.lobby):  # Lobby not found?
		return false

	var lobby: Lobby = lobbies[peer.lobby]

	if msg.type == Message.SEAL:
		# Client is sealing the room.
		return lobby.seal(peer.id)

	var dest_id: int = msg.id
	if dest_id == MultiplayerPeer.TARGET_PEER_SERVER:
		dest_id = lobby.host

	if not peers.has(dest_id):  # Destination ID not connected.
		return false

	if peers[dest_id].lobby != peer.lobby:  # Trying to contact someone not in same lobby.
		return false

	if msg.type in [Message.OFFER, Message.ANSWER, Message.CANDIDATE]:
		var source := MultiplayerPeer.TARGET_PEER_SERVER if peer.id == lobby.host else peer.id
		peers[dest_id].send(msg.type, source, msg.data)
		return true

	return false  # Unknown message.
          {
  "name": "signaling_server",
  "version": "1.0.0",
  "description": "",
  "main": "server.js",
  "dependencies": {
    "ws": "^7.5.9"
  },
  "devDependencies": {
    "eslint": "^8.28.0",
    "eslint-config-airbnb-base": "^14.2.1",
    "eslint-plugin-import": "^2.23.4"
  },
  "scripts": {
    "lint": "eslint server.js && echo \"Lint OK\" && exit 0",
    "format": "eslint server.js --fix && echo \"Lint OK\" && exit 0"
  },
  "author": "Fabio Alessandrelli",
  "license": "MIT"
}
            MIT License 

Copyright (c) 2013-2022 Niels Lohmann

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
            [configuration]

entry_symbol = "webrtc_extension_init"
compatibility_minimum = 4.1

[libraries]

linux.debug.x86_64 = "lib/libwebrtc_native.linux.template_debug.x86_64.so"
linux.debug.x86_32 = "lib/libwebrtc_native.linux.template_debug.x86_32.so"
linux.debug.arm64 = "lib/libwebrtc_native.linux.template_debug.arm64.so"
linux.debug.arm32 = "lib/libwebrtc_native.linux.template_debug.arm32.so"
macos.debug = "lib/libwebrtc_native.macos.template_debug.universal.framework"
windows.debug.x86_64 = "lib/libwebrtc_native.windows.template_debug.x86_64.dll"
windows.debug.x86_32 = "lib/libwebrtc_native.windows.template_debug.x86_32.dll"
android.debug.arm64 = "lib/libwebrtc_native.android.template_debug.arm64.so"
android.debug.x86_64 = "lib/libwebrtc_native.android.template_debug.x86_64.so"
ios.debug.arm64 = "lib/libwebrtc_native.ios.template_debug.arm64.dylib"
ios.debug.x86_64 = "lib/libwebrtc_native.ios.template_debug.x86_64.simulator.dylib"

linux.release.x86_64 = "lib/libwebrtc_native.linux.template_release.x86_64.so"
linux.release.x86_32 = "lib/libwebrtc_native.linux.template_release.x86_32.so"
linux.release.arm64 = "lib/libwebrtc_native.linux.template_release.arm64.so"
linux.release.arm32 = "lib/libwebrtc_native.linux.template_release.arm32.so"
macos.release = "lib/libwebrtc_native.macos.template_release.universal.framework"
windows.release.x86_64 = "lib/libwebrtc_native.windows.template_release.x86_64.dll"
windows.release.x86_32 = "lib/libwebrtc_native.windows.template_release.x86_32.dll"
android.release.arm64 = "lib/libwebrtc_native.android.template_release.arm64.so"
android.release.x86_64 = "lib/libwebrtc_native.android.template_release.x86_64.so"
ios.release.arm64 = "lib/libwebrtc_native.ios.template_release.arm64.dylib"
ios.release.x86_64 = "lib/libwebrtc_native.ios.template_release.x86_64.simulator.dylib"
     [remap]

path="res://.godot/exported/133200997/export-de0413ac4d87a0f11912173e72a085a3-client_ui.scn"
          [remap]

path="res://.godot/exported/133200997/export-254818f4b91b5a7a67310bd8a2a483f5-main.scn"
               list=Array[Dictionary]([])
        O��]��e   res://demo/client_ui.tscn*+�~�t�   res://demo/main.tscn       res://webrtc/webrtc.gdextension
ECFG      application/config/name          WebRTC Signaling Example   application/config/description�      �   A WebSocket signaling server/client for WebRTC.
This demo is devided in 4 parts.
The protocol is text based, and composed by a command and possibly
multiple payload arguments, each separated by a new line.      application/config/tags0   "         demo       network 	   official       application/run/main_scene         res://demo/main.tscn   application/config/features   "         4.2 )   debug/gdscript/warnings/shadowed_variable          +   debug/gdscript/warnings/untyped_declaration         '   debug/gdscript/warnings/unused_argument             display/window/stretch/mode         canvas_items   display/window/stretch/aspect         expand  #   rendering/renderer/rendering_method         gl_compatibility*   rendering/renderer/rendering_method.mobile         gl_compatibility       