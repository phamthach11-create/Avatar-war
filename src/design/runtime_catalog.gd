extends RefCounted
## Shared gameplay data gate for 2D and future 3D presenters.
const ACTIVE := "res://data/runtime/active.json"

static func problem() -> String:
	if not FileAccess.file_exists(ACTIVE):
		return "Runtime catalog missing. Run: python -m tools.design_sync sync"
	var active: Variant = JSON.parse_string(FileAccess.get_file_as_string(ACTIVE))
	if not active is Dictionary:
		return "Invalid runtime pointer"
	var source := "res://" + str(active.get("source", ""))
	if not FileAccess.file_exists(source) or FileAccess.get_sha256(source) != active.get("source_sha256", ""):
		return "Excel changed; runtime is stale. Run: python -m tools.design_sync plan"
	var path := "res://" + str(active.get("bundle", ""))
	if not FileAccess.file_exists(path) or FileAccess.get_sha256(path) != active.get("bundle_sha256", ""):
		return "Runtime bundle missing or modified"
	var bundle: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not bundle is Dictionary or bundle.get("source_sha256", "") != active.get("source_sha256", ""):
		return "Runtime bundle revision mismatch"
	for file in bundle.get("engine_files", {}):
		var code := FileAccess.get_file_as_string("res://" + file).replace("\r\n", "\n")
		if code.sha256_text() != bundle.engine_files[file]:
			return "Combat code changed; runtime verification is required: " + file
	return ""

static func scenario(id: String) -> Dictionary:
	var error := problem()
	if not error.is_empty():
		push_error(error)
		return {}
	var active: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ACTIVE))
	var bundle: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://" + active.bundle))
	return bundle.scenarios.get(id, {}).duplicate(true)
