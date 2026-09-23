"""Compile and exercise the real typed-to-R conversion without invoking IAN."""
from pathlib import Path
import subprocess,json,time,sys,hashlib
H=Path(__file__).resolve().parent;B=Path(sys.argv[1]);O=Path(sys.argv[2]);O.mkdir();m=json.loads((B/'manifest.json').read_text());cmd=next(x['argv'] for x in m['commands'] if x['name']=='module');cmd=[str(H/'projection.cpp') if x==str(B/'source/bridge.cpp') else str(O/'projection.so') if x==str(B/'dgraphs_ian.so') else x for x in cmd];start=time.monotonic()
with (O/'build.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=120)
(O/'command.json').write_text(json.dumps(dict(command=cmd,exit_code=r.returncode,seconds=time.monotonic()-start,revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),source_sha256={name:hashlib.sha256((H/name).read_bytes()).hexdigest() for name in ['projection.cpp','projection.R']}),indent=2)+'\n');assert r.returncode==0
cmd=['/Library/Frameworks/R.framework/Resources/bin/Rscript','--vanilla',str(H/'projection.R'),str(O/'projection.so'),str(O/'checks.json'),'after']
with (O/'run.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=60)
(O/'run-command.json').write_text(json.dumps(dict(command=cmd,exit_code=r.returncode),indent=2)+'\n');assert r.returncode==0
print((O/'checks.json').read_text())
