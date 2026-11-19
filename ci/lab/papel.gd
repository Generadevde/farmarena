extends Node
# LAB: confere o "duelo no papel" (Scripts/duelo_papel.gd) contra os duelos de
# verdade medidos no laboratório.   LAB_PAPEL=/tmp/lab/matriz_X.json  [LAB_SOLO=/tmp/lab/solo_X.json]
func _ready():
	await get_tree().process_frame
	var m: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("LAB_PAPEL")))
	var by_name := {}
	for c in Catalogo.cards():
		by_name[c.card_name] = c
	var ok := 0
	var total := 0
	var wrong: Array = []
	var est := {}
	var real := {}
	var cnt := {}
	var t0 = Time.get_ticks_msec()
	for key in m:
		var parts = str(key).split("|")
		if parts[0] >= parts[1] or !by_name.has(parts[0]) or !by_name.has(parts[1]):
			continue
		var measured = float(m[key])
		var paper = DueloPapel.duel(by_name[parts[0]], by_name[parts[1]])
		for k in 2:
			var n = parts[k]
			var sign_k = 1.0 if k == 0 else -1.0
			cnt[n] = int(cnt.get(n, 0)) + 1
			if measured * sign_k > 0.02: real[n] = int(real.get(n, 0)) + 1
			if paper * sign_k > 0.02: est[n] = int(est.get(n, 0)) + 1
		if absf(measured) <= 0.02:
			continue
		total += 1
		if (measured > 0) == (paper > 0.02) and absf(paper) > 0.02:
			ok += 1
		else:
			wrong.append("%s x %s: real %+.2f papel %+.2f" % [parts[0], parts[1], measured, paper])
	print("PAPEL acerto do vencedor: %d/%d = %d%%  (%d ms por duelo)" % [ok, total, int(round(100.0 * ok / maxi(total, 1))), int((Time.get_ticks_msec() - t0) / maxi(total, 1))])
	var err := 0.0
	var names = cnt.keys()
	names.sort()
	for n in names:
		var r = 100.0 * int(real.get(n, 0)) / cnt[n]
		var e = 100.0 * int(est.get(n, 0)) / cnt[n]
		err += absf(r - e)
		print("PAPEL %-24s real %3d%%  papel %3d%%  %+d" % [n, int(r), int(e), int(e - r)])
	print("PAPEL erro médio na %% de vitórias: %.1f pontos" % (err / maxi(names.size(), 1)))
	if OS.get_environment("LAB_ERROS") != "":
		for w in wrong:
			print("PAPEL errou ", w)
	var solo_path = OS.get_environment("LAB_SOLO")
	if solo_path != "":
		var solo: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(solo_path))
		var terr := 0.0
		var tn := 0
		for n in solo:
			if !by_name.has(n) or by_name[n].is_spell():
				continue
			var st: UnitData = DeckBuilder.get_unit_stats(by_name[n])
			if st == null or st.unit_type == UnitData.UnitType.BUILDING:
				continue
			var e = DueloPapel.tower_share(by_name[n]) * 100.0
			terr += absf(e - float(solo[n]) * 100.0)
			tn += 1
			print("PAPELTORRE %-24s real %3d%%  papel %3d%%" % [n, int(float(solo[n]) * 100.0), int(e)])
		print("PAPEL erro médio no dano em torre: %.1f pontos (%d cartas)" % [terr / maxi(tn, 1), tn])
	get_tree().quit()
