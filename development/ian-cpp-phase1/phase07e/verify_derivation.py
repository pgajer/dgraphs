"""Regenerate a candidate in a scratch directory, leaving measured sources alone."""
import sys,tempfile,subprocess,shutil
from pathlib import Path
from support import *
with tempfile.TemporaryDirectory() as tmp:
 parent=Path(tmp);h=parent/'phase07e';h.mkdir();(parent/'phase07d').symlink_to(HERE.parent/'phase07d',target_is_directory=True)
 shutil.copyfile(HERE/'derive.py',h/'derive.py');p=subprocess.run([sys.executable,'-B',h/'derive.py'],capture_output=True,text=True);assert p.returncode==0,p.stderr
 files={}
 for f in (h/'candidate').rglob('*'):
  if f.is_file():
   n=str(f.relative_to(h/'candidate'));assert f.read_bytes()==(HERE/'candidate'/n).read_bytes(),n;files[n]=sha(f)
write(sys.argv[1],dict(passed=True,solver_calls=0,files=files));print(len(files),'derived candidate files match')
