extends Node

# fonte de TODAS as atualizações/changelog -- arrasta aqui, direto no
# Inspector desse autoload, todo arquivo .tres de UpdateData que você criar.
# A ORDEM do array é a ordem que aparece na tela -- coloca a mais recente
# no topo do array se quiser ela aparecendo primeiro
@export var all_updates: Array[UpdateData] = []
