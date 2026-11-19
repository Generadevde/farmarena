extends Node
# LAB: folha com o desenho de todas as tropas no TAMANHO que aparecem no campo
# (pra ver de relance o quanto uma se parece com a outra)
func _ready():
	await get_tree().process_frame
	var units = []
	for c in CardDatabase.all_cards:
		if c == null or c.is_spell(): continue
		var st: UnitData = DeckBuilder.get_unit_stats(c)
		if st == null: continue
		units.append([c, st])
	units.sort_custom(func(a, b): return a[0].cost < b[0].cost if a[0].cost != b[0].cost else a[0].card_name < b[0].card_name)
	var cols = 12
	var cell = 150
	var zoom = float(OS.get_environment("LAB_ZOOM")) if OS.get_environment("LAB_ZOOM") != "" else 1.5
	var rows = int(ceil(units.size() / float(cols)))
	var sheet = Image.create_empty(cols * cell, rows * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("5f9648"))
	var names = []
	var i = 0
	for u in units:
		var c: CardData = u[0]
		var st: UnitData = u[1]
		var img: Image = c.icon.get_image()
		img.convert(Image.FORMAT_RGBA8)
		var k = st.unit_scale * Regras.sprite_factor(st.unit_scale) * zoom
		var s = maxi(8, int(round(48.0 * k)))
		img.resize(s, s, Image.INTERPOLATE_NEAREST)
		var ox = (i % cols) * cell + (cell - s) / 2
		var oy = (i / cols) * cell + (cell - 24) - s
		sheet.blend_rect(img, Rect2i(0, 0, s, s), Vector2i(ox, oy))
		names.append({"nome": c.card_name, "custo": c.cost, "n": st.unit_count, "scale": st.unit_scale})
		i += 1
	var where = OS.get_environment("LAB_FOLHA") if OS.get_environment("LAB_FOLHA") != "" else "/tmp/lab/folha"
	sheet.save_png(where + ".png")
	var f = FileAccess.open(where + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(names))
	f.close()
	print("FOLHA ", units.size())
	get_tree().quit()
