extends Node

# guarda qual bot vai ser enfrentado na próxima partida -- setado pelo menu
# antes de trocar pra cena de batalha, e lido por ela assim que começa
var next_ai_profile: AIProfile = null

# guarda os dados de um replay salvo, setado pela tela de estatísticas antes
# de trocar pra cena de batalha -- se isso estiver preenchido, a cena de
# batalha entra em MODO REPRODUÇÃO em vez de partida normal
var replay_data: Dictionary = {}
