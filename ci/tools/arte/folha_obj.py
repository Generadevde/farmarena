import sys
from PIL import Image
from kit import *
import objetos
PAL = {"P":"#f2ede0","S":"#58a0d8","A":"#c8483c","K":"#f0d060","M":"#a0a8b4","W":"#8a5a34"}
S=4; names=[(c,n) for c in objetos.OBJETOS for n in objetos.OBJETOS[c]]
cols=9; rows=(len(names)+cols-1)//cols
sheet=Image.new("RGBA",(cols*48*S,rows*48*S),(98,150,74,255))
for i,(c,n) in enumerate(names):
    im=recolor(objetos.OBJETOS[c][n]().img,PAL)
    im=im.resize((im.width*S,im.height*S),Image.NEAREST)
    sheet.alpha_composite(im,((i%cols)*48*S,(i//cols)*48*S))
sheet.save(sys.argv[1])
