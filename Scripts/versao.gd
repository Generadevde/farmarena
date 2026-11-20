extends RefCounted
class_name Versao
## Número da versão que aparece na tela inicial e em Configurações.
## O build do celular (.github/workflows/apk-celular.yml, passo "Número da
## versão") REESCREVE este arquivo com o número e a hora do build -- aqui
## fica só o valor de quem roda direto do editor.

const NUMERO = "dev"
const DATA = ""


static func texto() -> String:
	return "versão %s%s" % [NUMERO, ("  ·  " + DATA) if DATA != "" else ""]
