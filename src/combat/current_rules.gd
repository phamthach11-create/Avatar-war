extends RefCounted
## Pure formation helpers, shared by requested combat and tests. Zero-based slots.
static func area(primary: int, shape: String) -> Array[int]:
	var result: Array[int] = []
	if primary < 0 or primary >= 9: return result
	var row: int = primary / 3
	var col: int = primary % 3
	for i in range(9):
		var r: int = i / 3
		var c: int = i % 3
		var dr := absi(r-row)
		var dc := absi(c-col)
		var inside := i == primary
		match shape:
			"Adjacent": inside = dr <= 1 and dc <= 1
			"Row Adjacent": inside = r == row and dc <= 1
			"Line Adjacent": inside = c == col and dr <= 1
			"Row", "Full Row": inside = r == row
			"Full Line": inside = c == col
			"Cross": inside = dr + dc <= 1
			"All", "All Allies", "All Enemies": inside = true
		if inside: result.append(i)
	return result
