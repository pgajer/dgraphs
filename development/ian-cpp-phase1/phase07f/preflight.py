"""Verify reused identities and falsify trace checking without optimization."""
import subprocess,sys,hashlib
from pathlib import Path
from support import *
w=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
m=load(w/'phase07f/fixtures-v1/manifest.json');old=load(w/'phase07e/manifest-v1.json')
for name,item in old['source_files'].items():
 if '/phase07e/' in name:assert sha(Path.cwd()/name)==item['sha256'],name
assert sha(w/'phase07e/build-v1/ian_engine')==m['runtime']['engine_sha256']
for e in m['cases']:assert sha(e['input'])==e['sha256']
source=w/'phase07e/trajectory-v1/helix_500/native/child/trace.jsonl';small=out/'saved-solve-prefix.jsonl';count=0
with small.open('w') as f:
 for e in events(source):
  if e['event']=='solve':
   f.write(__import__('json').dumps(e)+'\n');count+=1
   if e['attempt']==1:break
assert count==3
cmd=[sys.executable,'-B',E/'test_trace.py',out/'trace-controls',small]
p=subprocess.run(list(map(str,cmd)),capture_output=True,text=True);(out/'stdout.log').write_text(p.stdout);(out/'stderr.log').write_text(p.stderr);assert p.returncode==0,p.stderr
result=load(out/'trace-controls/results.json');assert result['passed']
write(out/'results.json',dict(passed=True,solver_calls=0,source=str(source),source_sha256=sha(source),prefix_sha256=sha(small),copied_solve_events=count,controls=len(result['synthetic_trace_controls']),command=list(map(str,cmd)),runtime=m['runtime'],revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()))
print('Reused runtime identities and 13 no-solve trace falsifications pass.')
