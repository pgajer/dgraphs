"""Freeze six hard LPs with original returns and expected outcomes; no solves."""
import sys,subprocess,shutil
from pathlib import Path
from support import *
w=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
old=load(w/'phase07d/fixtures-v1/manifest.json');cases={};ledger=load(w/'phase07d/diagnostic-v1/ledger.json')
for name,item in old['cases'].items():
 e=dict(item);source=Path(e['path']);p=out/(name+'.json');shutil.copyfile(source,p)
 strict=None
 if e['saved_strict']:
  strict=out/(name+'-saved-strict.json');shutil.copyfile(e['saved_strict'],strict)
 expected={c:ledger['runs'][name+'/'+c]['accepted'] for c in ['ordinary','units11']}
 cases[name]=dict(path=str(p),sha256=sha(p),source=str(source),source_sha256=sha(source),saved_strict=str(strict) if strict else None,expected=expected)
source=w/'phase07d/analysis-v2/native-terminal-problem.json';p=out/'post_prune_terminal.json';shutil.copyfile(source,p)
cases['post_prune_terminal']=dict(path=str(p),sha256=sha(p),source=str(source),source_sha256=sha(source),saved_strict=None,expected=dict(ordinary=False,units11=True))
probe=w.parent/'auditor/review-7d/terminal-probe/run/child/result.json'
write(out/'manifest.json',dict(cases=cases,revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),plan_sha256=sha(HERE/'PLAN.md'),solver_sources=old['solver_sources'],python_modules=old['python_modules'],solver_calls=0,reused_auditor_probe=dict(path=str(probe),sha256=sha(probe),fresh_execution=False)))
print('Six fixed problems preserved; no new solves.')
