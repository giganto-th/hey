# -*- coding: utf-8 -*-
import sys, os
import numpy as np
from PIL import Image, ImageFilter
NAMES=["idle","walk_a","walk_b","flap_up","flap_down","peck","eat","sleep","startled","dizzy","happy","carried"]
OUT=480           # output canvas in px (2x of 240 art units)
IDLE_FRAC=0.72    # idle bird height as a fraction of the canvas

def key(img):
    a=np.asarray(img.convert("RGB")).astype(np.float32)
    r,g,b=a[...,0],a[...,1],a[...,2]
    green=g-np.maximum(r,b)                 # how much greener than anything else
    alpha=np.clip(1-(green-30)/90,0,1)      # <30 solid, >120 transparent
    # despill: remove green cast on edge pixels
    spill=np.clip(g-np.maximum(r,b),0,None)
    g2=np.where(alpha<1, g-spill*0.9, g)
    out=np.dstack([r,g2,b,alpha*255]).clip(0,255).astype(np.uint8)
    return Image.fromarray(out,"RGBA")

def main(src,dst,cols=4,rows=3):
    sheet=key(Image.open(src))
    W,H=sheet.size; cw,ch=W//cols,H//rows
    cells=[]
    for i,n in enumerate(NAMES):
        c,r=i%cols,i//cols
        cell=sheet.crop((c*cw,r*ch,(c+1)*cw,(r+1)*ch))
        al=np.asarray(cell.split()[3])
        # drop specks: keep the largest region by erosion trick (cheap): threshold + bbox of strong alpha
        ys,xs=np.where(al>40)
        bbox=(xs.min(),ys.min(),xs.max()+1,ys.max()+1)
        cells.append((n,cell,bbox,al))
    idle_h=cells[0][2][3]-cells[0][2][1]
    scale=OUT*IDLE_FRAC/idle_h
    os.makedirs(dst,exist_ok=True)
    report=[]
    for n,cell,bbox,al in cells:
        x0,y0,x1,y1=bbox
        crop=cell.crop(bbox)
        w,h=crop.size
        crop=crop.resize((max(1,round(w*scale)),max(1,round(h*scale))),Image.LANCZOS)
        ys,xs=np.where(np.asarray(crop.split()[3])>40)
        cx=xs.mean()  # centroid x keeps the body over the pivot
        canvas=Image.new("RGBA",(OUT,OUT),(0,0,0,0))
        px=round(OUT/2-cx); py=OUT-crop.height-2
        # shrink if it can't fit the canvas
        if crop.height>OUT-4 or crop.width>OUT-4:
            f=min((OUT-4)/crop.height,(OUT-4)/crop.width); crop=crop.resize((round(crop.width*f),round(crop.height*f)),Image.LANCZOS)
            px=round(OUT/2-cx*f); py=OUT-crop.height-2
        px=max(0,min(OUT-crop.width,px))
        canvas.alpha_composite(crop,(px,py))
        canvas.save(os.path.join(dst,n+".png"))
        report.append((n,crop.width,crop.height))
    print(src,"scale",round(scale,3),[(n,w,h) for n,w,h in report])
    # contact sheet
    cs=Image.new("RGBA",(OUT//2*6,OUT//2*2),(225,225,230,255))
    for i,(n,*_) in enumerate(report):
        im=Image.open(os.path.join(dst,n+".png")).resize((OUT//2,OUT//2))
        cs.alpha_composite(im,((i%6)*OUT//2,(i//6)*OUT//2))
    cs.save(os.path.join(dst,"_contact.png"))

if __name__=="__main__":
    main(sys.argv[1],sys.argv[2])
