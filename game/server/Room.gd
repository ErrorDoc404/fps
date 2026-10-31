class_name Room
extends RefCounted
## One squad room on a dedicated server: up to 4 operators, its own lobby state and (during a mission) its own World,
## simulated in an isolated physics/navigation space. A server hosts many rooms at once.

var id := 0
var name := ""
var password_hash := ""
var max_players := 4
var members := {}          # peer_id -> member dict
var leader_peer := 0
var phase := "lobby"       # lobby | loading | active | results
var selected_mission := "op01"
var session_id := ""
var disconnected := {}     # profile_id -> {member, time}   (slot reserved for reconnection during a mission)
var world: Node            # server World (inside holder)
var holder: Node           # /root/Rooms/R<id> (SubViewport with its own World3D on the server)
var created_at := 0.0

func locked() -> bool:
	return password_hash != ""

func occupancy() -> int:
	return members.size() + disconnected.size()

func is_full() -> bool:
	return occupancy() >= max_players

func free_slot() -> int:
	var used := []
	for m in members.values():
		used.append(m["slot"])
	for d in disconnected.values():
		used.append(d["member"]["slot"])
	for s in range(max_players):
		if not used.has(s):
			return s
	return -1

func peer_for_slot(slot: int) -> int:
	for pid in members:
		if members[pid]["slot"] == slot:
			return pid
	return 0

func node_path() -> String:
	return "/root/Rooms/R%d" % id

func lobby_state() -> Dictionary:
	var ms := {}
	for pid in members:
		ms[str(pid)] = members[pid].duplicate()
		ms[str(pid)].erase("profile_id")
	return {"room": summary(), "members": ms, "leader": leader_peer, "phase": phase, "mission": selected_mission}

## Entry shown in the room browser.
func summary() -> Dictionary:
	var m := GameData.mission(selected_mission)
	var leader_name := ""
	if members.has(leader_peer):
		leader_name = members[leader_peer]["name"]
	return {"id": id, "name": name, "locked": locked(), "players": occupancy(), "max": max_players, "phase": phase,
		"mission": selected_mission, "mission_name": "%s %s" % [m.get("code", ""), m.get("name", "")], "leader": leader_name}
