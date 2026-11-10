import sys
from PIL import Image
from kit import *
import pecas
T = [
 ({"pernas":"casco","corpo":"redondo","bracos":"patas","cabeca":"vaca"}, {"P":"#f2ede0","S":"#3a3038","K":"#f0b0a0","M":"#d8d0c0"}),
 ({"pernas":"casco","corpo":"armadura","bracos":"patas","cabeca":"boi","arma":"marreta"}, {"P":"#8a5a3c","K":"#e0b090","M":"#a8b0bc","W":"#7a5030"}),
 ({"pernas":"patinha","corpo":"redondo","bracos":"patas","cabeca":"porco","chapeu":"cozinheiro","arma":"frigideira"}, {"P":"#f0a0a8","K":"#f8c0c0","M":"#5a606c","W":"#4a3828"}),
 ({"pernas":"ave","corpo":"penas","bracos":"asas","cabeca":"galinha","costas":"rabo_galo"}, {"P":"#f4f0e4","A":"#d83c30","K":"#f0b030"}),
 ({"pernas":"ave","corpo":"penas","bracos":"asas","cabeca":"pato","chapeu":"bandana","arma":"estilingue"}, {"P":"#f0e8a0","A":"#3c70c8","K":"#f09030","W":"#7a5030","M":"#888890"}),
 ({"pernas":"casco","corpo":"la","bracos":"patas","cabeca":"ovelha","arma":"viola"}, {"P":"#4a4048","S":"#f4f0e8","K":"#4a4048","W":"#b07038"}),
 ({"pernas":"casco","corpo":"poncho","bracos":"patas","cabeca":"bode","chapeu":"cowboy"}, {"P":"#c8c0b0","S":"#e8e0d0","A":"#b8402c","K":"#e8d8c0","M":"#e0d8c0","W":"#6a4428"}),
 ({"pernas":"bota","corpo":"macacao","bracos":"humanos","cabeca":"humano","chapeu":"palha","arma":"forcado"}, {"S":"#c84838","A":"#3c5c98","K":"#e8b088","M":"#a0a8b4","W":"#6a4428"}),
 ({"pernas":"bota","corpo":"macacao","bracos":"humanos","cabeca":"velho","chapeu":"palha","arma":"lampiao"}, {"S":"#58a050","A":"#705038","K":"#d8a078","M":"#606878","W":"#6a4428"}),
 ({"pernas":"fantasma","corpo":"saco","bracos":"humanos","cabeca":"espantalho","chapeu":"palha","arma":"foice"}, {"P":"#c8a860","S":"#8a6a40","A":"#a03c30","K":"#d8b870","M":"#b0b8c0","W":"#5a4028"}),
 ({"pernas":"bota","corpo":"poncho","bracos":"humanos","cabeca":"abobora","arma":"machado"}, {"P":"#f08828","S":"#58a040","A":"#503868","K":"#e8b088","M":"#a0a8b4","W":"#5a4028"}),
 ({"pernas":"bota","corpo":"macacao","bracos":"humanos","cabeca":"milho","arma":"enxada"}, {"P":"#f4d040","S":"#68b048","A":"#3c5c98","K":"#e8b088","M":"#a0a8b4","W":"#6a4428"}),
 ({"pernas":"patinha","corpo":"redondo","bracos":"patas","cabeca":"sapo","chapeu":"coroa"}, {"P":"#68b848","K":"#d8e890","A":"#d83c30","S":"#40a0d8"}),
 ({"pernas":"patinha","corpo":"redondo","bracos":"patas","cabeca":"capivara","chapeu":"flor"}, {"P":"#a87848","K":"#c89868","A":"#f070a0","S":"#58a040"}),
 ({"pernas":"patinha","corpo":"redondo","bracos":"patas","cabeca":"gato","arma":"porrete"}, {"P":"#f09838","K":"#f8e0c0","W":"#6a4428","M":"#b0b8c0"}),
 ({"pernas":"ave","corpo":"penas","bracos":"asas","cabeca":"coruja"}, {"P":"#8a6848","K":"#e8d8b0","M":"#f0a030"}),
 ({"pernas":"inseto","corpo":"listrado","bracos":"patas","cabeca":"abelha","costas":"asas_inseto"}, {"P":"#f4c830","M":"#3a3038"}),
 ({"pernas":"bota","corpo":"redondo","bracos":"patas","cabeca":"et","costas":"foguete"}, {"P":"#78c878","K":"#a8e0a0","A":"#f04848","M":"#b0b8c0","W":"#484858"}),
 ({"pernas":"rodas","corpo":"armadura","bracos":"humanos","cabeca":"balde","arma":"motosserra"}, {"M":"#98a0ac","S":"#787c88","K":"#787c88","A":"#e06030","W":"#484858"}),
 ({"pernas":"bota","corpo":"macacao","bracos":"humanos","cabeca":"cebola","chapeu":"penacho","arma":"escudo"}, {"P":"#c880c0","S":"#e8e0d0","A":"#8048a0","K":"#e8d0e0","M":"#a0a8b4","W":"#6a4428"}),
 ({"pernas":"casco","corpo":"redondo","bracos":"patas","cabeca":"cavalo","costas":"capa","chapeu":"coroa"}, {"P":"#b87848","S":"#3a2820","A":"#b82c2c","K":"#e0c0a0"}),
]
S=4; cols=7; rows=(len(T)+cols-1)//cols
sheet = Image.new("RGBA",(cols*48*S,rows*48*S),(98,150,74,255))
for i,(r,p) in enumerate(T):
    im = pecas.montar(r,p).resize((48*S,48*S),Image.NEAREST)
    sheet.alpha_composite(im,((i%cols)*48*S,(i//cols)*48*S))
sheet.save(sys.argv[1])
