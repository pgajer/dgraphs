"""Freeze deterministic original LPs and source/settings provenance, no solves."""
import subprocess,sys
from pathlib import Path
import clarabel
from support import *
w=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
trace=w/'phase07c/panel-v2/helix_500/evaluated/child/trace.jsonl';solves={e['number']:e for e in events(trace) if e['event']=='solve'}
old=load(w/'phase07b/fixtures-v1/manifest.json');cases={}
for name,number,strict in [('unresolved',17,18),('predecessor',16,None),('first_repaired',1,2)]:
 p=out/(name+'.json');write(p,solves[number]);s=None
 if strict is not None:s=out/(name+'-saved-strict.json');write(s,solves[strict])
 cases[name]=dict(path=str(p),sha256=sha(p),source=str(trace),source_sha256=sha(trace),number=number,saved_strict=str(s) if s else None)
for name,key in [('small_helix','helix120_first'),('pressmat_stress','pressmat500_stress')]:
 source=Path(old['cases'][key]['path']);p=out/(name+'.json');write(p,load(source));cases[name]=dict(path=str(p),sha256=sha(p),source=str(source),source_sha256=sha(source),saved_strict=None)
source=w/'phase06a/clean-v2/dependencies/Clarabel.cpp/Clarabel.rs'
files=['src/solver/implementations/default/info.rs','src/solver/implementations/default/settings.rs','src/solver/implementations/default/problemdata.rs','src/solver/implementations/default/residuals.rs','src/solver/implementations/default/solution.rs','src/algebra/vecmath.rs','src/solver/core/kktsolvers/direct/quasidef/directldlkktsolver.rs']
write(out/'manifest.json',dict(cases=cases,revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),plan_sha256=sha(HERE/'PLAN.md'),solver_sources={str(source/f):sha(source/f) for f in files},python_modules={str(p):sha(p) for p in Path(clarabel.__file__).parent.glob('*') if p.is_file()},solver_calls=0))
print('Five fixed problems frozen without new solves.')
