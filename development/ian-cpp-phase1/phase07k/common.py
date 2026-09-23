import hashlib, json, sys, subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
E=HERE.parent/'phase07e'
W=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker')
def load(p): return json.loads(Path(p).read_text())
def write(p,d):
 p=Path(p);p.parent.mkdir(parents=True,exist_ok=True)
 t=p.with_suffix(p.suffix+'.tmp');t.write_text(json.dumps(d,allow_nan=False,indent=2)+'\n');t.replace(p)
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def events(p):
 with Path(p).open() as f:
  for line in f:
   if line.endswith('\n'): yield json.loads(line)
def revision(): return subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
