extends SceneTree
# AI images often come with the transparency checkerboard painted in. This removes it: the light neutral greys
# reachable from the border, plus closed pockets of it (inside glasses, between strokes) that hold both its tones.
# Run: Godot --headless --path . -s tools/cut_checkerboard.gd -- <in.png> <out.png> [...]
func is_bg(c: Color) -> bool:
	var mx := maxf(c.r, maxf(c.g, c.b))
	var mn := minf(c.r, minf(c.g, c.b))
	return mx - mn < 0.03 and mn > 0.78
func cut(src: String, dst: String) -> void:
	var im := Image.load_from_file(src)
	im.convert(Image.FORMAT_RGBA8)
	var w := im.get_width()
	var h := im.get_height()
	var bg := PackedByteArray()
	bg.resize(w * h)
	var stack := PackedInt32Array()
	for x in w:
		stack.append(x); stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w); stack.append(y * w + w - 1)
	while stack.size() > 0:
		var i: int = stack[stack.size() - 1]
		stack.resize(stack.size() - 1)
		if bg[i] == 1: continue
		var x := i % w
		var y := i / w
		if not is_bg(im.get_pixel(x, y)): continue
		bg[i] = 1
		if x > 0: stack.append(i - 1)
		if x < w - 1: stack.append(i + 1)
		if y > 0: stack.append(i - w)
		if y < h - 1: stack.append(i + w)
	# Enclosed pockets of checkerboard (inside the glasses, between strokes): both of its tones in one patch.
	var seen := PackedByteArray()
	seen.resize(w * h)
	for start in w * h:
		if bg[start] == 1 or seen[start] == 1 or not is_bg(im.get_pixel(start % w, start / w)):
			continue
		var comp := PackedInt32Array()
		var st := PackedInt32Array([start])
		var hi := false
		var lo := false
		while st.size() > 0:
			var i: int = st[st.size() - 1]
			st.resize(st.size() - 1)
			if seen[i] == 1: continue
			var c := im.get_pixel(i % w, i / w)
			if not is_bg(c): continue
			seen[i] = 1
			comp.append(i)
			if c.v > 0.96: hi = true
			if c.v < 0.9: lo = true
			var x := i % w
			if x > 0: st.append(i - 1)
			if x < w - 1: st.append(i + 1)
			if i >= w: st.append(i - w)
			if i < w * (h - 1): st.append(i + w)
		if hi and lo and comp.size() >= 40:
			for i in comp: bg[i] = 1
	var removed := 0
	for y in h:
		for x in w:
			var i := y * w + x
			var c := im.get_pixel(x, y)
			if bg[i] == 1:
				im.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
				removed += 1
			else:
				# Soften the edge a little where the drawing meets what was removed.
				var edge := (x > 0 and bg[i - 1] == 1) or (x < w - 1 and bg[i + 1] == 1) or (y > 0 and bg[i - w] == 1) or (y < h - 1 and bg[i + w] == 1)
				if edge:
					im.set_pixel(x, y, Color(c.r, c.g, c.b, 0.6))
	im.save_png(dst)
	print(dst, " removed ", removed, " of ", w * h)
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2 or args.size() % 2 == 1:
		print("usage: Godot --headless --path . -s tools/cut_checkerboard.gd -- <in.png> <out.png> [<in2.png> <out2.png> ...]")
	for i in range(0, args.size() - 1, 2):
		cut(args[i], args[i + 1])
	quit()
