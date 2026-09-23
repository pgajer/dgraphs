"""Render the maintained numerical snapshot only; no optimizer/private data reads."""
import json,math,subprocess,hashlib
from pathlib import Path
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor
P=Path(__file__).resolve().parent;d=json.loads((P/'figure-data.json').read_text());out=P/'build';out.mkdir(exist_ok=True)
pdf=out/'helix-arithmetic.pdf';c=canvas.Canvas(str(pdf),pagesize=(940,465))
ink='#243c4b';blue='#007c91';red='#be563c';muted='#61747c'
def text(x,y,s,size=11,color=ink):c.setFillColor(HexColor(color));c.setFont('Helvetica',size);c.drawString(x,y,s)
def line(x1,y1,x2,y2,color=ink,width=1):c.setStrokeColor(HexColor(color));c.setLineWidth(width);c.line(x1,y1,x2,y2)
text(30,435,'Matching the arithmetic resolves this helix comparison',21)
text(30,413,'1,000 profiles; unchanged solver settings, validation and one-retry policy',12,muted)
text(65,377,'Why the saved solve stopped',16)
text(525,377,'What happened in the full runs',16)
x0,y0,w,h=75,125,350,220
X=lambda i:x0+i/28*w
Y=lambda v:y0+(math.log10(max(v,1e-15))+14)/15*h
for power in [1,-2,-5,-8,-11,-14]:
 y=Y(10.**power);line(x0,y,x0+w,y,'#dce4e7',.5);text(x0-46,y-4,'1e'+str(power),10,muted)
for i in [0,5,10,15,20,25,28]:text(X(i)-4,y0-19,str(i),10,muted)
line(x0,y0,x0+w,y0,muted);line(x0,y0,x0,y0+h,muted)
for k,color in [('multiply',red),('power',blue)]:
 hist=d['history'][k]
 for a,b in zip(hist,hist[1:]):line(X(a['iterations']),Y(a['res_dual']),X(b['iterations']),Y(b['res_dual']),color,2)
 last=d['final_info'][k];c.setFillColor(HexColor(color));c.circle(X(last['iterations']),Y(last['res_dual']),3,fill=1,stroke=0)
c.setDash(4,3);line(x0,Y(1e-11),x0+w,Y(1e-11),'#546b75',1);c.setDash()
text(90,Y(1e-11)+5,'Solver requirement: 1e-11',10,muted)
text(227,217,'Multiply: stops at 18',11,red)
text(226,139,'Power: Solved at 27',11,blue)
text(148,78,'Solver iteration',11)
c.saveState();c.translate(20,160);c.rotate(90);text(0,0,'Internal dual residual (smaller is better)',11);c.restoreState()
text(60,46,'Saved fixed-problem histories from the audited interface replay.',9,muted)
text(60,32,'These residuals are distinct from the original-unit validation checks.',9,muted)
x0,y0,w,h=550,125,340,220
X=lambda i:x0+i/47*w
Y=lambda v:y0+(v-950)/850*h
for e in [1000,1250,1500,1750]:
 y=Y(e);line(x0,y,x0+w,y,'#dce4e7',.5);text(x0-34,y-4,str(e),10,muted)
for i in [0,10,20,30,40,47]:text(X(i)-4,y0-19,str(i),10,muted)
line(x0,y0,x0+w,y0,muted);line(x0,y0,x0,y0+h,muted)
vals=[d['initial_edges']]+[r['edges'] for r in d['trajectories']['native']]
py=[d['initial_edges']]+[r['edges'] for r in d['trajectories']['python']];assert vals==py and len(vals)==48
for i in range(47):line(X(i),Y(vals[i]),X(i+1),Y(vals[i+1]),blue,2)
for i in [0,5,10,15,20,25,30,35,40,47]:
 c.setStrokeColor(HexColor(blue));c.setFillColor(HexColor('#ffffff'));c.circle(X(i),Y(py[i]),2.6,stroke=1,fill=1)
c.setFillColor(HexColor(red));c.circle(X(0),Y(vals[0]),4,fill=1,stroke=0)
text(570,332,'Original native: stops before pruning',10,red)
text(632,267,'Shared power convention',12,blue)
text(632,249,'Line: native; circles: Python',10,muted)
text(700,220,'47 pruning steps',13)
text(700,200,'999 final edges',13)
text(700,180,'Final scales and affinities identical',10)
text(645,78,'Completed pruning step',11)
c.saveState();c.translate(491,197);c.rotate(90);text(0,0,'Edges remaining',11);c.restoreState()
text(532,46,'Fresh complete trajectories under the explicitly matched convention.',9,muted)
text(532,32,'Author checks on one Mac; independent review and portability pending.',9,muted)
c.showPage();c.save()
subprocess.run(['/opt/homebrew/bin/pdftoppm','-singlefile','-scale-to','1880','-png',str(pdf),str(out/'helix-arithmetic')],check=True)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(out/'figure-manifest.json').write_text(json.dumps(dict(data_sha256=sha(P/'figure-data.json'),script_sha256=sha(Path(__file__)),outputs={str(p.name):sha(p) for p in [pdf,out/'helix-arithmetic.png']}),indent=2)+'\n')
