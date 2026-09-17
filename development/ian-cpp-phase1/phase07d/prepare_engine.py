"""Reuse all accepted panel geometries; declare only the new experimental policy."""
import sys,subprocess
from pathlib import Path
from support import *
w=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False);cases=[]
for e in load(w/'phase07c/fixtures-v1/manifest.json')['cases']:
 e=dict(e);source=Path(e['input']);d=load(source);d['numerical_policy']=POLICIES['units11'];p=out/(e['name']+'.json');write(p,d)
 e.update(input=str(p),sha256=sha(p),source=str(source),source_sha256=sha(source));cases.append(e)
write(out/'manifest.json',dict(cases=cases,revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),policy=POLICIES['units11']))
