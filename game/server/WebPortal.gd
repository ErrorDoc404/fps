extends Node
## Minimal HTTP/1.1 server embedded in the dedicated server process. Serves a download page,
## /status.json, and the files placed in the downloads directory (client builds).
## Read-only: GET/HEAD only, files are served solely from a whitelist built from the downloads directory listing.

const MAX_CONNECTIONS := 32
const MAX_HEADER := 8192
const IDLE_TIMEOUT := 30.0
const WRITE_BUDGET := 1 << 20   # bytes per connection per frame

var http_port := 8080
var game_port := 7777
var downloads_dir := ""
var _server := TCPServer.new()
var _conns: Array = []

func start(port: int, gport: int, dir: String) -> bool:
	http_port = port
	game_port = gport
	downloads_dir = dir
	var err := _server.listen(port)
	if err != OK:
		Log.error("web", "failed to bind HTTP port", {"port": port, "err": err})
		return false
	Log.info("web", "download site listening", {"port": port, "downloads": downloads_dir, "files": _files().keys()})
	return true

func stop() -> void:
	for c in _conns:
		c["peer"].disconnect_from_host()
	_conns.clear()
	_server.stop()

## name -> absolute path for every downloadable file (the only paths that can ever be served).
func _files() -> Dictionary:
	var out := {}
	var d := DirAccess.open(downloads_dir)
	if d == null:
		return out
	for f in d.get_files():
		if f.get_extension().to_lower() in ["zip", "7z", "gz", "txt"]:
			out[f] = downloads_dir.path_join(f)
	return out

func _process(dt: float) -> void:
	while _server.is_connection_available():
		var peer := _server.take_connection()
		if _conns.size() >= MAX_CONNECTIONS:
			peer.disconnect_from_host()
			continue
		peer.set_no_delay(true)
		_conns.append({"peer": peer, "buf": PackedByteArray(), "idle": 0.0, "file": null, "left": 0, "out": PackedByteArray()})
	for c in _conns.duplicate():
		if not _service(c, dt):
			c["peer"].disconnect_from_host()
			if c["file"]:
				c["file"].close()
			_conns.erase(c)

## Returns false when the connection should be closed.
func _service(c: Dictionary, dt: float) -> bool:
	var peer: StreamPeerTCP = c["peer"]
	peer.poll()
	var st := peer.get_status()
	if st == StreamPeerTCP.STATUS_ERROR or st == StreamPeerTCP.STATUS_NONE:
		return false
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return true
	c["idle"] += dt
	if c["idle"] > IDLE_TIMEOUT:
		return false
	# 1) pending response bytes (headers / small bodies)
	if not (c["out"] as PackedByteArray).is_empty():
		var r: Array = peer.put_partial_data(c["out"])
		if r[0] != OK:
			return false
		if r[1] > 0:
			c["idle"] = 0.0
			c["out"] = (c["out"] as PackedByteArray).slice(r[1])
		if not (c["out"] as PackedByteArray).is_empty():
			return true
		if c["file"] == null:
			return false  # response complete; Connection: close
	# 2) streaming a file body
	if c["file"]:
		var f: FileAccess = c["file"]
		var budget := WRITE_BUDGET
		while budget > 0 and c["left"] > 0:
			var chunk := f.get_buffer(min(65536, c["left"]))
			var r: Array = peer.put_partial_data(chunk)
			if r[0] != OK:
				return false
			var sent: int = r[1]
			c["left"] -= sent
			budget -= sent
			if sent < chunk.size():
				f.seek(f.get_position() - (chunk.size() - sent))
				break
			c["idle"] = 0.0
		return c["left"] > 0
	# 3) reading the request
	var avail := peer.get_available_bytes()
	if avail > 0:
		var r: Array = peer.get_partial_data(avail)
		if r[0] != OK:
			return false
		c["buf"].append_array(r[1])
		c["idle"] = 0.0
	var text: String = (c["buf"] as PackedByteArray).get_string_from_ascii()
	if text.find("\r\n\r\n") < 0:
		return c["buf"].size() < MAX_HEADER
	_handle(c, text)
	return true

func _handle(c: Dictionary, text: String) -> void:
	var lines := text.split("\r\n")
	var parts := lines[0].split(" ")
	if parts.size() < 2:
		_respond(c, 400, "text/plain", "Bad Request".to_utf8_buffer())
		return
	var method := parts[0]
	var path := parts[1].split("?")[0].uri_decode()
	var host := ""
	for l in lines:
		if l.to_lower().begins_with("host:"):
			host = l.substr(5).strip_edges()
	if method != "GET" and method != "HEAD":
		_respond(c, 405, "text/plain", "Method Not Allowed".to_utf8_buffer())
		return
	var head_only := method == "HEAD"
	if path == "/" or path == "/index.html":
		_respond(c, 200, "text/html; charset=utf-8", _page(host).to_utf8_buffer(), head_only)
	elif path == "/status.json":
		_respond(c, 200, "application/json", JSON.stringify(_status()).to_utf8_buffer(), head_only)
	elif path.begins_with("/downloads/"):
		var name := path.substr(11)
		var files := _files()
		if not files.has(name):
			_respond(c, 404, "text/plain", "Not Found".to_utf8_buffer(), head_only)
			return
		var f := FileAccess.open(files[name], FileAccess.READ)
		if f == null:
			_respond(c, 500, "text/plain", "Unavailable".to_utf8_buffer(), head_only)
			return
		var size := f.get_length()
		c["out"] = _headers(200, "application/octet-stream", size, {"Content-Disposition": "attachment; filename=\"%s\"" % name})
		if head_only:
			f.close()
		else:
			c["file"] = f
			c["left"] = size
		Log.info("web", "download started", {"file": name, "bytes": size, "client": c["peer"].get_connected_host()})
	else:
		_respond(c, 404, "text/plain", "Not Found".to_utf8_buffer(), head_only)

func _headers(code: int, ctype: String, length: int, extra := {}) -> PackedByteArray:
	var reason: String = {200: "OK", 400: "Bad Request", 404: "Not Found", 405: "Method Not Allowed", 500: "Internal Server Error"}.get(code, "OK")
	var h := "HTTP/1.1 %d %s\r\nContent-Type: %s\r\nContent-Length: %d\r\nConnection: close\r\nCache-Control: no-store\r\nX-Content-Type-Options: nosniff\r\n" % [code, reason, ctype, length]
	for k in extra:
		h += "%s: %s\r\n" % [k, extra[k]]
	return (h + "\r\n").to_utf8_buffer()

func _respond(c: Dictionary, code: int, ctype: String, body: PackedByteArray, head_only := false) -> void:
	var out := _headers(code, ctype, body.size())
	if not head_only:
		out.append_array(body)
	c["out"] = out

func _status() -> Dictionary:
	var info := Session.server_info()
	info["game_port"] = game_port
	info["protocol"] = Net.PROTOCOL_VERSION
	var list := []
	for r in Session.rooms.values():
		list.append(r.summary())
	info["room_list"] = list
	return info

static func _human(bytes: int) -> String:
	return "%.1f MB" % (bytes / 1048576.0) if bytes >= 1048576 else "%d KB" % (bytes / 1024)

func _page(host_header: String) -> String:
	var host := host_header
	if host.begins_with("["):
		host = host.substr(0, host.find("]") + 1)
	elif host.count(":") == 1:
		host = host.split(":")[0]
	if host == "":
		host = "this-server-address"
	var s := _status()
	var rows := ""
	var files := _files()
	var names := files.keys()
	names.sort()
	for n in names:
		var size := FileAccess.open(files[n], FileAccess.READ).get_length()
		var label := "Windows client" if n.to_lower().contains("windows") else ("Linux dedicated server" if n.to_lower().contains("server") else "File")
		rows += "<a class='dl' href='/downloads/%s'><span>%s</span><b>%s</b><i>%s</i></a>" % [n.uri_encode(), label, n.xml_escape(), _human(size)]
	if rows == "":
		rows = "<p class='dim'>No builds have been placed in the downloads folder yet.</p>"
	return """<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Operation: Blackout</title><style>
:root{--bg:#0b0d0b;--panel:#151915;--line:#2a3029;--text:#e6eadb;--dim:#9aa08f;--accent:#f5ba42;--ok:#78db6b}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--text);font:16px/1.5 system-ui,Segoe UI,sans-serif}
.wrap{max-width:860px;margin:0 auto;padding:40px 16px}
.stripe{height:8px;background:repeating-linear-gradient(135deg,var(--accent) 0 14px,transparent 14px 28px);opacity:.35}
h1{margin:0;font-size:52px;letter-spacing:2px;color:var(--accent)}h1 small{display:block;font-size:20px;color:var(--dim);letter-spacing:4px}
.tag{color:var(--dim);margin:6px 0 28px}
.panel{background:var(--panel);border:1px solid var(--line);clip-path:polygon(0 0,calc(100%% - 24px) 0,100%% 24px,100%% 100%%,0 100%%);padding:20px 22px;margin-bottom:18px}
h2{margin:0 0 12px;font-size:15px;letter-spacing:3px;color:var(--accent);text-transform:uppercase}
.dl{display:grid;grid-template-columns:200px 1fr auto;gap:12px;align-items:center;padding:14px 16px;margin:8px 0;background:#1d231c;border-left:4px solid var(--accent);color:var(--text);text-decoration:none}
.dl:hover{background:#283026}.dl span{color:var(--accent);font-weight:700}.dl i{color:var(--dim);font-style:normal}
.stat{display:flex;gap:28px;flex-wrap:wrap}.stat div b{display:block;font-size:22px}.stat div span{color:var(--dim);font-size:13px;text-transform:uppercase;letter-spacing:2px}
code{background:#000;padding:2px 8px;color:var(--ok)}ol{margin:0;padding-left:20px}.dim{color:var(--dim)}
.rooms{width:100%%;border-collapse:collapse}.rooms th{color:var(--dim);font-size:12px;letter-spacing:2px;text-align:left;padding:6px}.rooms td{padding:8px 6px;border-top:1px solid var(--line)}
@media(max-width:600px){.dl{grid-template-columns:1fr}h1{font-size:38px}}
</style></head><body><div class="stripe"></div><div class="wrap">
<h1><small>OPERATION:</small>BLACKOUT</h1><div class="tag">Four operators. One mission. No one left behind.</div>
<div class="panel"><h2>Server status</h2><div class="stat">
<div><b>%s</b><span>Address</span></div><div><b>%d / %d</b><span>Players online</span></div>
<div><b>%d / %d</b><span>Rooms</span></div><div><b>v%s</b><span>Version</span></div></div></div>
<div class="panel"><h2>Rooms</h2>%s</div>
<div class="panel"><h2>Downloads</h2>%s</div>
<div class="panel"><h2>How to join</h2><ol>
<li>Download the Windows client and extract the zip (keep the .exe and .pck together).</li>
<li>Run <b>OperationBlackout.exe</b>, open <b>SERVER BROWSER</b> and add <code>%s:%d</code>.</li>
<li>Connect, then join a room or create your own (up to four operators per room, optional password).</li></ol></div>
<p class="dim">Game traffic: UDP %d &middot; This page: TCP %d</p></div></body></html>""" % [
		"%s:%d" % [host, game_port], s["players"], s["max_players"], s["rooms"], s["max_rooms"], s["version"], _rooms_html(s["room_list"]),
		rows, host, game_port, game_port, http_port]

func _rooms_html(list: Array) -> String:
	if list.is_empty():
		return "<p class='dim'>No rooms yet. Create one from the in-game server browser.</p>"
	var h := "<table class='rooms'><tr><th></th><th>Room</th><th>Operation</th><th>Players</th><th>Status</th></tr>"
	for r in list:
		h += "<tr><td>%s</td><td>%s</td><td>%s</td><td>%d / %d</td><td>%s</td></tr>" % ["&#128274;" if r["locked"] else "",
			String(r["name"]).xml_escape(), String(r["mission_name"]).xml_escape(), r["players"], r["max"],
			"IN MISSION" if r["phase"] != "lobby" else "LOBBY"]
	return h + "</table>"
