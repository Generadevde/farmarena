"""Peças por TEMA (versão 117): comida, países, mitologia, ET, oceano e fazenda.
Mesmo esquema de cores-modelo. O tema de cada peça do jogo fica em TEMAS, no fim."""
import math
from kit import *

GLASS = (170, 220, 240, 255)
GLOW = (190, 240, 255, 255)
FIRE = (255, 200, 80, 255)


def fin(cv):
    cv.outline()
    return cv


def _disc(cv, cx, cy, r, c):
    for y in range(int(cy - r), int(cy + r) + 1):
        for x in range(int(cx - r), int(cx + r) + 1):
            if (x - cx) ** 2 + (y - cy) ** 2 <= r * r:
                cv.put(x, y, c)


# ------------------------------------------------------------ COMIDA
def obj_panela():
    cv = Canvas()
    cv.blob_rect(8, 22, 32, 20, "M", 4)
    cv.rect(6, 20, 36, 4, C("M", 0)); cv.rect(2, 26, 6, 3, C("M", 2)); cv.rect(40, 26, 6, 3, C("M", 2))
    cv.ellipse(24, 20, 14, 3, "P", shade=False)
    for x, y in ((16, 12), (24, 8), (32, 13)):
        cv.line(x, y, x + 2, y - 5, EYE_W); cv.line(x + 2, y - 5, x, y - 9, EYE_W)
    return fin(cv)


def obj_bolo():
    cv = Canvas()
    cv.blob_rect(6, 28, 36, 14, "W", 3); cv.rect(6, 33, 36, 3, C("K", 0))
    cv.blob_rect(11, 16, 26, 13, "W", 3); cv.rect(11, 16, 26, 4, C("P", 0))
    for x in (13, 19, 25, 31):
        cv.rect(x, 20, 3, 3, C("P", 0))
    cv.rect(23, 8, 2, 8, C("A", 1)); cv.put(23, 6, FIRE); cv.put(24, 5, FIRE); cv.put(24, 7, (255, 120, 60, 255))
    return fin(cv)


def obj_hamburguer():
    cv = Canvas()
    cv.ellipse(24, 16, 18, 10, "K")
    cv.rect(6, 17, 36, 10, (0, 0, 0, 0))
    for x, y in ((16, 10), (24, 8), (31, 11), (20, 13), (28, 14)):
        cv.put(x, y, EYE_W)
    cv.rect(5, 18, 38, 3, C("S", 1)); cv.rect(7, 21, 34, 2, C("P", 1))
    cv.rect(6, 23, 36, 6, C("W", 1)); cv.rect(6, 23, 36, 1, C("W", 0))
    cv.rect(5, 29, 38, 2, C("K", 0))
    cv.blob_rect(6, 31, 36, 9, "K", 4)
    return fin(cv)


def obj_queijo():
    cv = Canvas()
    for i in range(22):
        cv.rect(6 + i, 36 - i, 36 - i, 1, C("K", 0 if i > 14 else 1))
    cv.rect(6, 36, 36, 6, C("K", 2))
    for x, y, r in ((16, 32, 2.5), (27, 28, 3), (33, 35, 2), (22, 22, 2)):
        _disc(cv, x, y, r, C("K", 2))
    return fin(cv)


def ico_pizza():
    cv = Canvas()
    for i in range(34):
        half = i * 0.5
        for x in range(int(24 - half), int(24 + half) + 1):
            cv.put(x, 42 - i, C("K", 0 if i < 28 else 2))
    cv.rect(6, 6, 36, 4, C("W", 1))
    for x, y in ((20, 18), (28, 16), (24, 26), (16, 12), (32, 11)):
        _disc(cv, x, y, 2.5, C("P", 1))
    cv.put(22, 32, C("S", 1)); cv.put(26, 21, C("S", 1)); cv.put(18, 22, C("S", 1))
    return fin(cv)


def ico_cafe():
    cv = Canvas()
    cv.blob_rect(10, 20, 24, 20, "M", 4)
    cv.ellipse(22, 21, 11, 3, "W", shade=False)
    for k in range(10):
        cv.put(34 + (k if k < 5 else 9 - k), 24 + k, C("M", 1)); cv.put(35 + (k if k < 5 else 9 - k), 24 + k, C("M", 2))
    cv.rect(6, 41, 32, 3, C("M", 2))
    for x in (16, 23, 29):
        cv.line(x, 14, x + 2, 9, EYE_W); cv.line(x + 2, 9, x, 4, EYE_W)
    return fin(cv)


def arma_garfo():
    cv = Canvas()
    cv.rect(38, 16, 2, 28, C("M", 1)); cv.rect(38, 16, 1, 28, C("M", 0))
    cv.rect(35, 13, 8, 3, C("M", 1))
    for x in (35, 38, 41):
        cv.rect(x, 3, 2, 10, C("M", 0))
    return fin(cv)


def arma_rolo():
    cv = Canvas()
    cv.blob_rect(35, 12, 7, 22, "W", 3)
    cv.rect(37, 5, 3, 7, C("W", 2)); cv.rect(37, 34, 3, 8, C("W", 2))
    return fin(cv)


# ------------------------------------------------------------ PAÍSES
def chap_sombrero():
    cv = Canvas()
    cv.ellipse(24, 9, 20, 3.5, "K")
    cv.blob_rect(18, 0, 12, 9, "K", 4)
    cv.rect(18, 6, 12, 2, C("P", 1))
    for x in range(6, 43, 4):
        cv.put(x, 10, C("P", 1)); cv.put(x + 1, 10, C("S", 1))
    return fin(cv)


def chap_samurai():
    cv = Canvas()
    cv.ellipse(24, 8, 12, 7, "P")
    cv.rect(10, 9, 28, 3, C("P", 2))
    cv.line(24, 6, 15, 0, C("K", 0)); cv.line(24, 6, 33, 0, C("K", 0)); cv.line(25, 6, 16, 0, C("K", 1)); cv.line(25, 6, 34, 0, C("K", 1))
    cv.rect(22, 5, 5, 4, C("K", 0))
    return fin(cv)


def chap_fez():
    cv = Canvas()
    for i in range(9):
        cv.rect(17 - i // 4, 1 + i, 14 + i // 2, 1, C("P", 0 if i < 3 else 1))
    cv.rect(15, 10, 18, 1, C("P", 2))
    cv.line(24, 1, 32, 5, PUPIL); cv.rect(31, 5, 2, 5, C("K", 0))
    return fin(cv)


def chap_coco():
    """chapéu-coco"""
    cv = Canvas()
    cv.ellipse(24, 6, 9, 6, "M")
    cv.rect(11, 8, 26, 3, C("M", 2)); cv.rect(15, 7, 18, 1, C("A", 1))
    return fin(cv)


def arma_katana():
    cv = Canvas()
    for k in range(28):
        cv.rect(37 + (1 if k < 6 else 0), 2 + k, 2, 1, C("M", 0)); cv.put(39 + (1 if k < 6 else 0), 2 + k, C("M", 2))
    cv.rect(34, 30, 9, 2, C("K", 1))
    cv.rect(37, 32, 3, 10, C("P", 2)); cv.put(38, 34, C("K", 0)); cv.put(38, 38, C("K", 0))
    return fin(cv)


def arma_baguete():
    cv = Canvas()
    cv.blob_rect(35, 4, 7, 36, "K", 3)
    for y in (10, 18, 26, 34):
        cv.line(36, y, 40, y - 3, C("K", 2))
    return fin(cv)


def ico_bandeira():
    cv = Canvas()
    cv.rect(8, 4, 3, 40, C("W", 1)); cv.rect(8, 4, 1, 40, C("W", 0)); _disc(cv, 9, 4, 2.5, C("K", 0))
    for i in range(30):
        dy = int(2 * math.sin(i / 4.0))
        cv.rect(11 + i, 8 + dy, 1, 7, C("P", 0 if i < 12 else 1))
        cv.rect(11 + i, 15 + dy, 1, 7, C("K", 0 if i < 12 else 1))
        cv.rect(11 + i, 22 + dy, 1, 7, C("S", 0 if i < 12 else 1))
    return fin(cv)


def torre_pagode():
    cv = Canvas()
    cv.blob_rect(12, 34, 24, 11, "P", 1); cv.rect(21, 37, 6, 8, C("W", 2))
    for i, (y, w) in enumerate(((30, 40), (20, 30), (10, 20))):
        x0 = 24 - w // 2
        cv.rect(x0, y, w, 3, C("S", 1)); cv.rect(x0 - 2, y + 2, 3, 2, C("S", 0)); cv.rect(x0 + w - 1, y + 2, 3, 2, C("S", 2))
        cv.rect(x0 + 4, y - 6 if i else y, w - 8, 6 if i else 0, C("P", 1))
    cv.rect(18, 24, 12, 6, C("P", 1)); cv.rect(20, 14, 8, 6, C("P", 1))
    cv.rect(23, 2, 2, 8, C("K", 0))
    return fin(cv)


def torre_piramide():
    cv = Canvas()
    for i in range(36):
        half = i * 0.6
        for x in range(int(24 - half), int(24 + half) + 1):
            cv.put(x, 8 + i, C("K", 0 if x < 24 else 2))
        if i % 6 == 5:
            cv.rect(int(24 - half), 8 + i, int(half * 2) + 1, 1, C("K", 1))
    cv.rect(21, 36, 6, 8, PUPIL)
    _disc(cv, 24, 6, 2.5, C("K", 0))
    return fin(cv)


# ------------------------------------------------------------ MITOLOGIA
def arma_tridente():
    cv = Canvas()
    cv.rect(38, 14, 2, 30, C("K", 1)); cv.rect(38, 14, 1, 30, C("K", 0))
    cv.rect(33, 12, 12, 2, C("K", 1))
    for x, top in ((33, 5), (38, 1), (43, 5)):
        cv.rect(x, top, 2, 12 - top + 1, C("K", 0)); cv.put(x, top - 1, C("K", 0))
    return fin(cv)


def arma_cajado():
    cv = Canvas()
    cv.rect(38, 12, 2, 32, C("W", 1)); cv.rect(38, 12, 1, 32, C("W", 0))
    _disc(cv, 39, 7, 5, C("S", 1)); _disc(cv, 38, 6, 2.5, C("S", 0)); cv.put(37, 5, SHINE)
    cv.put(33, 3, GLOW); cv.put(45, 4, GLOW); cv.put(44, 11, GLOW)
    return fin(cv)


def chap_aureola():
    cv = Canvas()
    for a in range(360):
        x = 24 + 10 * math.cos(math.radians(a)); y = 4 + 2.6 * math.sin(math.radians(a))
        cv.put(int(x), int(y), C("K", 0)); cv.put(int(x), int(y) + 1, C("K", 1))
    return fin(cv)


def chap_louros():
    cv = Canvas()
    for i in range(7):
        cv.rect(11 + i * 2, 8 - i // 2, 3, 3, C("S", 0 if i % 2 else 1))
        cv.rect(35 - i * 2, 8 - i // 2, 3, 3, C("S", 0 if i % 2 else 1))
    return fin(cv)


def chap_chifres_diabo():
    cv = Canvas()
    for k in range(8):
        cv.rect(14 - k // 3, 9 - k, 3 - k // 3, 1, C("P", 0 if k > 4 else 1))
        cv.rect(31 + k // 3 + k // 3, 9 - k, 3 - k // 3, 1, C("P", 0 if k > 4 else 1))
    return fin(cv)


def ico_olho():
    cv = Canvas()
    for i in range(40):
        h = 11 * math.sin(math.pi * i / 39)
        for y in range(int(24 - h), int(24 + h) + 1):
            cv.put(4 + i, y, EYE_W)
    _disc(cv, 24, 24, 8, C("S", 1)); _disc(cv, 24, 24, 4, PUPIL); cv.put(21, 21, SHINE); cv.put(22, 20, SHINE)
    for x in (10, 18, 30, 38):
        cv.line(x, 10, x, 6, C("K", 0))
    return fin(cv)


def torre_templo():
    cv = Canvas()
    cv.rect(4, 40, 40, 5, C("M", 2)); cv.rect(7, 36, 34, 4, C("M", 1))
    for x in (9, 17, 25, 33):
        cv.rect(x, 16, 5, 20, C("M", 0)); cv.rect(x + 3, 16, 2, 20, C("M", 1)); cv.rect(x - 1, 14, 7, 2, C("M", 1))
    for i in range(10):
        cv.rect(6 + i * 2, 13 - i, 36 - i * 4, 1, C("M", 0 if i < 7 else 1))
    _disc(cv, 24, 10, 2.5, C("K", 0))
    return fin(cv)


# ------------------------------------------------------------ ET
def arma_pistola_laser():
    cv = Canvas()
    cv.blob_rect(34, 18, 10, 6, "M", 2)
    cv.rect(36, 24, 4, 8, C("M", 2))
    cv.rect(37, 10, 3, 8, C("S", 1)); _disc(cv, 38, 8, 2.5, C("S", 0)); cv.put(38, 4, GLOW); cv.put(38, 2, GLOW)
    return fin(cv)


def chap_antenas():
    cv = Canvas()
    cv.line(19, 10, 15, 2, C("M", 1)); cv.line(29, 10, 33, 2, C("M", 1))
    _disc(cv, 15, 2, 2.2, C("S", 0)); _disc(cv, 33, 2, 2.2, C("S", 0))
    return fin(cv)


def obj_robo_bola():
    cv = Canvas()
    cv.ellipse(24, 24, 15, 15, "M")
    cv.rect(13, 20, 22, 7, PUPIL); _disc(cv, 19, 23, 2.5, C("P", 0)); _disc(cv, 29, 23, 2.5, C("P", 0))
    cv.rect(23, 4, 2, 6, C("M", 1)); _disc(cv, 24, 3, 2, C("S", 0))
    cv.rect(5, 22, 5, 3, C("M", 2)); cv.rect(38, 22, 5, 3, C("M", 2))
    cv.rect(16, 39, 5, 5, C("M", 2)); cv.rect(27, 39, 5, 5, C("M", 2))
    return fin(cv)


def obj_capsula():
    cv = Canvas()
    cv.ellipse(24, 22, 12, 18, "M")
    cv.ellipse(24, 18, 7, 8, "S", shade=False); cv.put(21, 14, SHINE); cv.put(22, 13, SHINE)
    cv.rect(10, 38, 5, 6, C("M", 2)); cv.rect(33, 38, 5, 6, C("M", 2)); cv.rect(21, 40, 6, 4, C("M", 2))
    cv.put(24, 45, FIRE); cv.put(23, 46, FIRE); cv.put(25, 46, FIRE)
    return fin(cv)


def ico_planeta():
    cv = Canvas()
    cv.ellipse(24, 24, 13, 13, "A")
    for a in range(360):
        x = 24 + 21 * math.cos(math.radians(a)); y = 24 + 5 * math.sin(math.radians(a))
        if not (math.sin(math.radians(a)) < 0 and abs(x - 24) < 12):
            cv.put(int(x), int(y), C("K", 0)); cv.put(int(x), int(y) + 1, C("K", 1))
    cv.put(19, 18, SHINE); cv.put(20, 17, SHINE)
    return fin(cv)


# ------------------------------------------------------------ OCEANO
def obj_barco():
    cv = Canvas()
    for i in range(9):
        cv.rect(5 + i, 30 + i, 38 - i * 2, 1, C("W", 0 if i < 2 else (1 if i < 6 else 2)))
    cv.rect(23, 4, 2, 26, C("W", 2))
    for i in range(20):
        cv.rect(25, 6 + i, 1 + i * 3 // 4, 1, EYE_W)
    for i in range(14):
        cv.rect(22 - i * 2 // 3, 12 + i, 1 + i * 2 // 3, 1, C("P", 1))
    cv.rect(3, 40, 42, 2, GLOW)
    return fin(cv)


def ico_ancora():
    cv = Canvas()
    for a in range(360):
        cv.put(int(24 + 4 * math.cos(math.radians(a))), int(7 + 4 * math.sin(math.radians(a))), C("M", 1))
    cv.rect(23, 11, 3, 30, C("M", 1)); cv.rect(23, 11, 1, 30, C("M", 0)); cv.rect(15, 16, 19, 3, C("M", 1))
    for a in range(20, 161):
        x = 24 + 15 * math.cos(math.radians(a)); y = 28 + 13 * math.sin(math.radians(a))
        cv.put(int(x), int(y), C("M", 1)); cv.put(int(x), int(y) + 1, C("M", 2)); cv.put(int(x), int(y) - 1, C("M", 0))
    cv.rect(7, 28, 4, 4, C("M", 0)); cv.rect(37, 28, 4, 4, C("M", 0))
    return fin(cv)


def ico_concha():
    cv = Canvas()
    cv.ellipse(24, 24, 18, 15, "P")
    for a in (-60, -30, 0, 30, 60):
        cv.line(24, 40, int(24 + 22 * math.sin(math.radians(a))), int(40 - 26 * math.cos(math.radians(a))), C("P", 2))
    cv.rect(19, 38, 10, 5, C("P", 1))
    return fin(cv)


def arma_arpao():
    cv = Canvas()
    cv.rect(38, 10, 2, 34, C("W", 1)); cv.rect(38, 10, 1, 34, C("W", 0))
    for k in range(9):
        cv.rect(39 - k // 2, 1 + k, 1 + k, 1, C("M", 0))
    cv.rect(34, 10, 3, 2, C("M", 1)); cv.rect(41, 10, 3, 2, C("M", 1))
    return fin(cv)


def torre_farol():
    cv = Canvas()
    for i in range(30):
        w = 12 + i // 4
        cv.rect(24 - w // 2, 14 + i, w, 1, C("P", 1) if (i // 6) % 2 == 0 else EYE_W)
    cv.rect(16, 11, 16, 3, C("M", 2))
    cv.rect(18, 4, 12, 7, C("K", 0)); cv.rect(18, 4, 12, 1, C("M", 1)); cv.rect(23, 4, 2, 7, C("M", 1))
    for i in range(5):
        cv.rect(19 + i, 3 - i, 10 - i * 2, 1, C("P", 2))
    cv.line(31, 7, 45, 3, FIRE); cv.line(31, 8, 45, 11, FIRE)
    cv.rect(21, 36, 6, 8, C("W", 2))
    return fin(cv)


# ------------------------------------------------------------ FAZENDA
def obj_carrinho():
    cv = Canvas()
    for i in range(12):
        cv.rect(10 + i // 2, 18 + i, 28 - i, 1, C("S", 0 if i < 3 else (1 if i < 9 else 2)))
    cv.ellipse(22, 17, 12, 4, "W", shade=False)
    cv.line(36, 22, 46, 16, C("W", 1)); cv.line(36, 23, 46, 17, C("W", 2))
    cv.ellipse(18, 37, 7, 7, "M"); _disc(cv, 18, 37, 2.5, C("K", 1))
    cv.rect(30, 30, 2, 12, C("M", 2))
    return fin(cv)


def ico_trigo():
    cv = Canvas()
    for x0, lean in ((16, -4), (24, 0), (32, 4)):
        cv.line(x0, 44, x0 + lean, 16, C("K", 2))
        for k in range(6):
            y = 6 + k * 4
            _disc(cv, x0 + lean - 3 + k % 2, y, 2.2, C("K", 0)); _disc(cv, x0 + lean + 3 - k % 2, y + 2, 2.2, C("K", 1))
    cv.rect(13, 36, 22, 3, C("P", 1))
    return fin(cv)


NOVAS = {
    "objeto": {"panela": obj_panela, "bolo": obj_bolo, "hamburguer": obj_hamburguer, "queijo": obj_queijo, "robo_bola": obj_robo_bola,
               "capsula": obj_capsula, "barco": obj_barco, "carrinho": obj_carrinho},
    "torre": {"pagode": torre_pagode, "piramide": torre_piramide, "templo": torre_templo, "farol": torre_farol},
    "icone": {"pizza": ico_pizza, "cafe": ico_cafe, "bandeira": ico_bandeira, "olho": ico_olho, "planeta": ico_planeta, "ancora": ico_ancora,
              "concha": ico_concha, "trigo": ico_trigo},
    "chapeu": {"sombrero": chap_sombrero, "samurai": chap_samurai, "fez": chap_fez, "coco": chap_coco, "aureola": chap_aureola,
               "louros": chap_louros, "chifres_diabo": chap_chifres_diabo, "antenas": chap_antenas},
    "arma": {"garfo": arma_garfo, "rolo": arma_rolo, "katana": arma_katana, "baguete": arma_baguete, "tridente": arma_tridente,
             "cajado": arma_cajado, "pistola_laser": arma_pistola_laser, "arpao": arma_arpao},
}

# ------------------------------------------------------------ o TEMA de cada peça (a que não está aqui é "Fazenda")
TEMAS = {
    "Comida": ["panela", "bolo", "hamburguer", "queijo", "pizza", "cafe", "garfo", "rolo", "baguete", "cozinheiro", "frigideira", "tomate", "cebola",
               "milho", "abobora", "melancia", "pimenta", "cogumelo", "ovo", "garrafa", "fornalha", "barril"],
    "Guerra": ["tanque", "tanque_duplo", "jipe", "lanca_missil", "artilharia", "helicoptero", "dirigivel", "andador", "submarino", "caminhao", "bobina",
               "prisma", "bunker", "radar", "usina", "refinaria", "quartel", "canhao_grande", "missil", "bomba", "paraquedas", "mira", "engrenagem",
               "estrela", "onda", "relogio", "capacete", "boina", "quepe", "fuzil", "bazuca", "lanca_chamas", "bala", "laser", "armadura", "escudo",
               "elmo", "colete", "espingarda", "forte", "motosserra"],
    "ET e máquina": ["et", "ovni", "antena", "robo_bola", "capsula", "planeta", "pistola_laser", "antenas", "balde", "rodas", "foguete", "tripe",
                     "cerca_eletrica", "raio", "espelho"],
    "Oceano": ["barco", "ancora", "concha", "arpao", "farol", "tubarao", "polvo", "baleia", "peixe", "siri", "caranguejo", "aguaviva", "medusa", "gota",
               "jacare", "sapo"],
    "Mitologia": ["tridente", "cajado", "aureola", "louros", "chifres_diabo", "olho", "templo", "ciclope", "dragao", "cerbero", "mapinguari", "saci",
                  "curupira", "caveira", "fantasma", "chama", "morcego", "capa", "coroa", "chifres", "medusa", "fogo"],
    "Países": ["sombrero", "samurai", "fez", "coco", "katana", "baguete", "bandeira", "pagode", "piramide", "cartola", "cowboy", "poncho", "penacho",
               "terno", "gorro", "viola", "berrante"],
    "Bichos": ["vaca", "boi", "porco", "galinha", "pato", "ovelha", "bode", "cavalo", "sapo", "capivara", "gato", "coruja", "abelha", "cachorro", "burro",
               "tatu", "jacare", "urubu", "onca", "tamandua", "cobra", "preguica", "bezerro", "jegue", "formiga", "casco", "ave", "patinha", "inseto",
               "penas", "la", "listrado", "patas", "asas", "rabo_galo", "asas_inseto", "malhado", "pata", "rasteiro", "casca", "montado", "ninho",
               "colmeia", "galinheiro"],
}
