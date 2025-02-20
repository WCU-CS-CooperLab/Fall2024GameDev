GDPC                �                                                                         P   res://.godot/exported/133200997/export-3070c538c03ee49b7677ff960a3f5195-main.scn�      �      �m f��`�fRP��t�    T   res://.godot/exported/133200997/export-a4a223816b4643698240bff1109424b1-minimal.scn �      k      +u�eMH���_��@    ,   res://.godot/global_script_class_cache.cfg  �             ��Р�8���8~$}P�       res://.godot/uid_cache.bin  �             �� �T!1����`X�       res://Signaling.gd  @      S      S���|	����%��       res://chat.gd           1      | ��� E��كD       res://link_button.gd@      �       ����<[ȓ�\�Y��       res://main.gd   �      �      T�[L;[?�#i�(��       res://main.tscn.remap   �      a       �J�Sw� ������       res://minimal.gd�      ;      �B��^�����:�'x�       res://minimal.tscn.remap      d       ����V.�3ò{�       res://project.binary�      �      &�,�=�EI�L�~�2I        extends Node
# An example peer-to-peer chat client.

var peer := WebRTCPeerConnection.new()

# Create negotiated data channel.
var channel = peer.create_data_channel("chat", {"negotiated": true, "id": 1})

func _ready() -> void:
	# Connect all functions.
	peer.ice_candidate_created.connect(_on_ice_candidate)
	peer.session_description_created.connect(_on_session)

	# Register to the local signaling server (see below for the implementation).
	Signaling.register(String(get_path()))


func _on_ice_candidate(media: String, index: int, sdp: String) -> void:
	# Send the ICE candidate to the other peer via the signaling server.
	Signaling.send_candidate(String(get_path()), media, index, sdp)


func _on_session(type: String, sdp: String) -> void:
	# Send the session to other peer via the signaling server.
	Signaling.send_session(String(get_path()), type, sdp)
	# Set generated description as local.
	peer.set_local_description(type, sdp)


func _process(delta: float) -> void:
	# Always poll the connection frequently.
	peer.poll()
	if channel.get_ready_state() == WebRTCDataChannel.STATE_OPEN:
		while channel.get_available_packet_count() > 0:
			print(String(get_path()), " received: ", channel.get_packet().get_string_from_utf8())


func send_message(message: String) -> void:
	channel.put_packet(message.to_utf8_buffer())
               extends LinkButton

func _on_LinkButton_pressed() -> void:
	OS.shell_open("https://github.com/godotengine/webrtc-native/releases")
             extends Node

const Chat = preload("res://chat.gd")

func _ready() -> void:
	var p1 := Chat.new()
	var p2 := Chat.new()
	add_child(p1)
	add_child(p2)

	# Wait a second and send message from P1.
	await get_tree().create_timer(1.0).timeout
	p1.send_message("Hi from %s" % String(p1.get_path()))

	# Wait a second and send message from P2.
	await get_tree().create_timer(1.0).timeout
	p2.send_message("Hi from %s" % String(p2.get_path()))
            RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script    res://main.gd ��������   PackedScene    res://minimal.tscn ��������   Script    res://link_button.gd ��������      local://PackedScene_ivxb4 `         PackedScene          	         names "         Main    script    Node    Minimal    CenterContainer    anchors_preset    anchor_right    anchor_bottom    grow_horizontal    grow_vertical    LinkButton 	   modulate    layout_mode    text    _on_LinkButton_pressed    pressed    	   variants                                     �?           �?��k?��>  �?   W   Make sure to download the GDExtension WebRTC Plugin and place it in the project folder                node_count             nodes     0   ��������       ����                      ���                            ����                           	                 
   
   ����                                     conn_count             conns                                     node_paths              editable_instances              version             RSRC             extends Node
# Main scene.

# Create the two peers.
var p1 := WebRTCPeerConnection.new()
var p2 := WebRTCPeerConnection.new()
var ch1 := p1.create_data_channel("chat", { "id": 1, "negotiated": true })
var ch2 := p2.create_data_channel("chat", { "id": 1, "negotiated": true })

func _ready() -> void:
	print(p1.create_data_channel("chat", { "id": 1, "negotiated": true }))
	# Connect P1 session created to itself to set local description.
	p1.session_description_created.connect(p1.set_local_description)
	# Connect P1 session and ICE created to p2 set remote description and candidates.
	p1.session_description_created.connect(p2.set_remote_description)
	p1.ice_candidate_created.connect(p2.add_ice_candidate)

	# Same for P2.
	p2.session_description_created.connect(p2.set_local_description)
	p2.session_description_created.connect(p1.set_remote_description)
	p2.ice_candidate_created.connect(p1.add_ice_candidate)

	# Let P1 create the offer.
	p1.create_offer()

	# Wait a second and send message from P1.
	await get_tree().create_timer(1).timeout
	ch1.put_packet("Hi from P1".to_utf8_buffer())

	# Wait a second and send message from P2.
	await get_tree().create_timer(1).timeout
	ch2.put_packet("Hi from P2".to_utf8_buffer())


func _process(delta: float) -> void:
	p1.poll()
	p2.poll()
	if ch1.get_ready_state() == ch1.STATE_OPEN and ch1.get_available_packet_count() > 0:
		print("P1 received: ", ch1.get_packet().get_string_from_utf8())
	if ch2.get_ready_state() == ch2.STATE_OPEN and ch2.get_available_packet_count() > 0:
		print("P2 received: ", ch2.get_packet().get_string_from_utf8())
     RSRC                    PackedScene            ��������                                                  resource_local_to_scene    resource_name 	   _bundled    script       Script    res://minimal.gd ��������      local://PackedScene_ib6mk          PackedScene          	         names "         Minimal    script    Node    	   variants                       node_count             nodes     	   ��������       ����                    conn_count              conns               node_paths              editable_instances              version             RSRC     # A local signaling server. Add this to autoloads with name "Signaling" (/root/Signaling)
extends Node

# We will store the two peers here.
var peers: Array[String] = []

func register(path: String) -> void:
	assert(peers.size() < 2)
	peers.push_back(path)
	if peers.size() == 2:
		get_node(peers[0]).peer.create_offer()


func _find_other(path: String) -> String:
	# Find the other registered peer.
	for p in peers:
		if p != path:
			return p

	return ""


func send_session(path: String, type: String, sdp: String) -> void:
	var other := _find_other(path)
	assert(not other.is_empty())
	get_node(other).peer.set_remote_description(type, sdp)


func send_candidate(path: String, media: String, index: int, sdp: String) -> void:
	var other := _find_other(path)
	assert(not other.is_empty())
	get_node(other).peer.add_ice_candidate(media, index, sdp)
             [remap]

path="res://.godot/exported/133200997/export-3070c538c03ee49b7677ff960a3f5195-main.scn"
               [remap]

path="res://.godot/exported/133200997/export-a4a223816b4643698240bff1109424b1-minimal.scn"
            list=Array[Dictionary]([])
        �J��n��5   res://main.tscn ECFG      application/config/name$         WebRTC Minimal Connection      application/config/description`      X   This is a minimal sample of using WebRTC connections to connect two peers to each other.   application/config/tags0   "         demo       network 	   official       application/run/main_scene         res://main.tscn    application/config/features   "         4.2    autoload/Signaling         *res://Signaling.gd +   debug/gdscript/warnings/untyped_declaration            display/window/stretch/mode         canvas_items   display/window/stretch/aspect         expand  #   rendering/renderer/rendering_method         gl_compatibility*   rendering/renderer/rendering_method.mobile         gl_compatibility         