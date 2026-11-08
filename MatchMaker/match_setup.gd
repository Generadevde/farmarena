extends Node

# guarda qual bot vai ser enfrentado na próxima partida -- setado pelo menu
# antes de trocar pra cena de batalha, e lido por ela assim que começa
var next_ai_profile: AIProfile = null

# guarda os dados de um replay salvo, setado pela tela de estatísticas antes
# de trocar pra cena de batalha -- se isso estiver preenchido, a cena de
# batalha entra em MODO REPRODUÇÃO em vez de partida normal
var replay_data: Dictionary = {}

# modo da próxima partida -- 1v1 normal ou 2v2 (você + bot aliado contra 2 bots)
const MODE_1V1 = 0
const MODE_2V2 = 1
var mode: int = MODE_1V1
var ally_ai_profile: AIProfile = null          # bot do SEU lado no 2v2
var second_enemy_ai_profile: AIProfile = null  # segundo bot inimigo no 2v2
