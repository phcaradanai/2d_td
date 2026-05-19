## DebugLog — lightweight combat-safe debug logging service.
##
## Autoloaded as "DebugLog".  All public functions are no-ops in release builds.
## Use this instead of raw push_warning()/print() inside combat loops to prevent
## log flooding (which causes Godot's TOO_MANY_WARNINGS rate-limiter to fire and
## drops FPS through debugger overhead).
##
## API:
##   DebugLog.warn_once(key, msg)           — push_warning once per session per key
##   DebugLog.warn_rate(key, msg, interval) — push_warning at most once per interval
##   DebugLog.trace(flag, msg)              — print only when named flag is true
##   DebugLog.set_flag(name, enabled)       — toggle a named trace flag at runtime
##
## Flags are off by default.  Turn on from the debug panel or console:
##   DebugLog.set_flag("formation", true)
##   DebugLog.set_flag("economy", true)
##   DebugLog.set_flag("targeting", true)
##   DebugLog.set_flag("combat", true)
extends Node

# ── Internal state ─────────────────────────────────────────────────────────────
# Keys that have already emitted a once-only warning this session.
var _warned_once: Dictionary = {}
# Last-emit timestamp (msec) per rate-limited key.
var _last_warn_msec: Dictionary = {}
# Named boolean trace flags.  All default to false.
var _flags: Dictionary = {}

# ── Public API ─────────────────────────────────────────────────────────────────

## Emit push_warning exactly once per session for a given key.
## Subsequent calls with the same key are silently discarded.
func warn_once(key: String, msg: String) -> void:
	if not OS.is_debug_build():
		return
	if _warned_once.has(key):
		return
	_warned_once[key] = true
	push_warning(msg)

## Emit push_warning at most once per `interval_sec` for a given key.
func warn_rate(key: String, msg: String, interval_sec: float = 5.0) -> void:
	if not OS.is_debug_build():
		return
	var now := Time.get_ticks_msec()
	var last: int = _last_warn_msec.get(key, 0)
	if now - last < int(interval_sec * 1000.0):
		return
	_last_warn_msec[key] = now
	push_warning(msg)

## Print only when the named flag is enabled AND we are in a debug build.
func trace(flag_name: String, msg: String) -> void:
	if not OS.is_debug_build():
		return
	if not _flags.get(flag_name, false):
		return
	print("[%s] %s" % [flag_name.to_upper(), msg])

## Enable or disable a named trace flag at runtime.
func set_flag(flag_name: String, enabled: bool) -> void:
	_flags[flag_name] = enabled

## Query a flag value (for external checks without coupling to the autoload path).
func flag(flag_name: String) -> bool:
	return _flags.get(flag_name, false)

## Reset all once-only keys (useful when restarting a level in the same session).
func reset_session() -> void:
	_warned_once.clear()
	_last_warn_msec.clear()
