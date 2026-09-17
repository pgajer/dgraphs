"""Regenerate in a temporary directory; never rewrite measured candidate sources."""
import hashlib,json,shutil,subprocess,sys,tempfile
from pathlib import Path
H=Path(__file__).resolve().parent
with tempfile.TemporaryDirectory() as tmp:
 parent=Path(tmp);target=parent/'phase07c';target.mkdir()
 for name in ['phase06b','phase03','phase05']:(parent/name).symlink_to(H.parent/name,target_is_directory=True)
 shutil.copyfile(H/'extract.py',target/'extract.py')
 p=subprocess.run([sys.executable,'-B',target/'extract.py'],capture_output=True,text=True);assert p.returncode==0,p.stderr
 files={}
 for f in target.rglob('*'):
  if f.is_file() and f.name!='extract.py':
   name=str(f.relative_to(target));assert f.read_bytes()==(H/name).read_bytes(),name;files[name]=hashlib.sha256(f.read_bytes()).hexdigest()
 result=dict(passed=True,generated_files=files,solver_calls=0)
 Path(sys.argv[1]).write_text(json.dumps(result,indent=2)+'\n');print(len(files),'derived files match')
