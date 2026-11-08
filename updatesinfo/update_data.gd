extends Resource
class_name UpdateData

## Ex: "1.2.0" -- só texto, aparece igual você digitar
@export var version: String = ""

## Título curto da atualização, ex: "Sistema de Nações"
@export var title: String = ""

## Data que você quiser mostrar -- texto livre também, ex: "12/08/2026"
@export var date: String = ""

## O texto completo da atualização -- pode usar quebra de linha à vontade,
## tipo uma lista: "- Item 1\n- Item 2\n- Item 3"
@export_multiline var description: String = ""
