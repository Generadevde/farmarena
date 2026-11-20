extends Node
## Baralhos dos bots: quão repetidos são e o que falta neles.
##   HOME=/tmp/x godot --headless res://ci/lab/decks.tscn
## Imprime: cartas diferentes em uso, as mais usadas, quantas cartas dois
## bots quaisquer têm em comum (de 7) e quantos baralhos têm buraco
## (sem Derruba-torre, sem resposta pra Bando, pra Voador, pra Tanque).

func _ready():
	await get_tree().process_frame
	await get_tree().process_frame
	var decks: Array = []
	var use := {}
	var gaps := {}
	var kinds := {}
	for bot_name in BotSimulator.roster_names:
		var p = BotLearning.get_or_create_profile(bot_name)
		if p == null or p.deck.is_empty():
			continue
		var names: Array = []
		for c in p.deck:
			if c == null:
				continue
			names.append(c.card_name)
			use[c.card_name] = int(use.get(c.card_name, 0)) + 1
			var k = Catalogo.kind_of(c)
			kinds[k] = int(kinds.get(k, 0)) + 1
		decks.append(names)
		for g in Catalogo.deck_gaps(p.deck):
			gaps[g] = int(gaps.get(g, 0)) + 1
	var n = decks.size()
	var shared = 0.0
	var pairs = 0
	var same = 0
	for i in n:
		for j in range(i + 1, n):
			var s = 0
			for x in decks[i]:
				if decks[j].has(x):
					s += 1
			shared += s
			pairs += 1
			if s >= 5:
				same += 1
	var top: Array = use.keys()
	top.sort_custom(func(a, b): return use[a] > use[b])
	print("DECKS bots=", n, " cartas diferentes em uso=", use.size(), " de ", Catalogo.cards().size())
	print("DECKS em comum entre 2 bots (média, de 7)=", snappedf(shared / maxf(pairs, 1), 0.01), " | pares quase iguais (5+ em comum)=", same, " de ", pairs)
	print("DECKS mais usadas: ", top.slice(0, 10).map(func(k): return "%s %d%%" % [k, int(round(100.0 * use[k] / n))]))
	print("DECKS tipos (cartas no total): ", kinds)
	print("DECKS buracos (baralhos com o problema, de ", n, "): ", gaps)
	get_tree().quit()
