class_name RateLimiter
extends RefCounted
## Token bucket per (peer, action). Used to rate-limit sensitive client requests on the server.

var _buckets := {}
var _rules := {}  # action -> [capacity, refill_per_sec]

func set_rule(action: String, capacity: float, refill_per_sec: float) -> void:
	_rules[action] = [capacity, refill_per_sec]

func allow(peer: int, action: String) -> bool:
	var rule: Array = _rules.get(action, [10.0, 5.0])
	var key := "%d:%s" % [peer, action]
	var now := Time.get_ticks_msec() / 1000.0
	var b: Array = _buckets.get(key, [rule[0], now])
	var tokens: float = min(rule[0], b[0] + (now - b[1]) * rule[1])
	if tokens < 1.0:
		_buckets[key] = [tokens, now]
		return false
	_buckets[key] = [tokens - 1.0, now]
	return true

func forget(peer: int) -> void:
	for k in _buckets.keys():
		if k.begins_with("%d:" % peer):
			_buckets.erase(k)
