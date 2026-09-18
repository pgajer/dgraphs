#!/usr/bin/env python3
"""Reconstruct presentation assets from the maintained aggregate snapshot; no solves."""
import hashlib, json, math, shutil, subprocess
from pathlib import Path
from reportlab.graphics.shapes import Drawing, Rect, String, Line, Circle
from reportlab.graphics import renderPDF, renderSVG
from reportlab.lib.colors import HexColor
E=Path(__file__).resolve().parents[1]
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    out=E/'build/assets';out.mkdir(parents=True,exist_ok=True)
    evidence=E/'figure-evidence.json'; specs=json.loads(evidence.read_text())['figures']; outputs={}
    poppler=shutil.which('pdftoppm') or '/opt/homebrew/bin/pdftoppm'
    for f in specs:
        d=Drawing(720,310);d.add(Rect(0,0,720,310,fillColor=HexColor('#ffffff'),strokeColor=None))
        def txt(x,y,s,size=12,color='#223c4c'):d.add(String(x,y,str(s),fontName='Helvetica',fontSize=size,fillColor=HexColor(color)))
        def rect(x,y,w,h,color):d.add(Rect(x,y,w,h,fillColor=HexColor(color),strokeColor=None))
        txt(15,283,f['title'],18)
        if f['kind']=='bars':
            for i,r in enumerate(f['data']):
                y=229-i*49;txt(15,y+4,r['label'],11);rect(302,y, r['seconds']/450*345,19,'#357b91' if i else '#82919a');txt(308+r['seconds']/450*345,y+4,f"{r['seconds']:.3f}",10)
            for v in [0,100,200,300,400]:txt(300+v/450*345,47,v,10)
            txt(390,24,'Wall time per solve (seconds)',11)
        elif f['kind']=='matrix':
            for x,t in zip([16,85,165,350],['Phase','Profiles','Numerical policy','Observed trajectory outcome']):txt(x,247,t,11)
            for i,row in enumerate(f['data']):
                y=202-i*36;rect(12,y-9,696,31,'#edf4f5' if i%2==0 else '#f5f6f7')
                for x,t in zip([16,85,165,350],row):txt(x,y,t,11)
            txt(15,16,'Different policies and two input sizes; rows are not independent replications.',10)
        elif f['kind']=='interface':
            txt(15,246,'Solver interface',11);txt(214,246,'Native-generated input',13);txt(462,246,'Python-generated input',13)
            for i,iface in enumerate(['native','python']):
                y=147-i*91;txt(15,y+30,iface.capitalize(),13)
                for j,inp in enumerate(['native','python']):
                    r=next(r for r in f['data'] if r['interface']==iface and r['input']==inp);x=195+249*j
                    rect(x,y,237,75,'#f8ead7' if inp=='native' else '#e0f0ed');txt(x+14,y+45,r['status'],18);txt(x+14,y+19,str(r['iterations'])+' iterations; repeated exactly',11)
            txt(15,19,'Two executions per cell; same-input vectors and histories match across interfaces.',10)
        else:
            left,right=295,666
            def xp(v):return left+(math.log10(v)+1)/(math.log10(3000)+1)*(right-left)
            txt(15,247,'Objective allowance T-L (approx.)',11)
            for i,r in enumerate(f['data']):
                y=204-i*63;a,b=xp(r['attained']),xp(r['upper']);txt(15,y-4,f"{r['allowance']:.7g} objective units",12)
                d.add(Line(a,y,b,y,strokeColor=HexColor('#32798c'),strokeWidth=3));d.add(Circle(a,y,4,fillColor=HexColor('#32798c'),strokeColor=None));d.add(Line(b,y-7,b,y+7,strokeColor=HexColor('#32798c'),strokeWidth=2))
                txt(a-5,y+15,f"{r['attained']:.5f}",10);txt(b-8,y-22,f"{r['upper']:.6g}",10)
            for v in [.1,1,10,100,1000]:txt(xp(v)-6,32,f'{v:g}',10)
            txt(314,12,'Feasible scale span (scale units, log axis)',11)
        for ext,renderer in [('pdf',renderPDF),('svg',renderSVG)]:
            p=out/f"{f['id']}.{ext}";renderer.drawToFile(d,str(p));outputs[str(p.relative_to(E))]=sha(p)
        subprocess.run([poppler,'-scale-to','1440','-png','-singlefile',str(out/f"{f['id']}.pdf"),str(out/f['id'])],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE)
        p=out/f"{f['id']}.png";outputs[str(p.relative_to(E))]=sha(p)
    (E/'build/figure-manifest.json').write_text(json.dumps({'operation':'figure reconstruction only; zero optimizer calls','input':{'path':str(evidence.relative_to(E)),'sha256':sha(evidence)},'script_sha256':sha(Path(__file__)),'outputs':outputs},indent=2)+'\n')
    print('Reconstructed four figures from maintained aggregate evidence.')
if __name__=='__main__':main()
