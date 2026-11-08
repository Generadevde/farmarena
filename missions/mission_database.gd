extends Node

# fonte de TODAS as missões possíveis do jogo -- arrasta aqui, direto no
# Inspector desse autoload, todo arquivo .tres de MissionData que você criar.
# Mesmo padrão do CardDatabase.all_cards (preenchimento manual sobrevive à
# exportação pro Android; escaneamento de pasta em tempo de execução não)
@export var all_missions: Array[MissionData] = []
