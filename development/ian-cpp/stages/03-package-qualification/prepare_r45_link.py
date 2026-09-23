"""Create an isolated correctly linked R 4.5 build configuration; no IAN calls."""
import json,sys,shutil,hashlib,subprocess
from pathlib import Path
root=Path(sys.argv[1]);cfg=json.loads((root/'environment.json').read_text());old=cfg['runtimes']['r45-v2'];new=json.loads(json.dumps(old));folder=root/'r45-v3';folder.mkdir();lib=folder/'library';lib.mkdir()
for k in ['R_LIBS','R_LIBS_USER','R_LIBS_SITE']:new['env'][k]=str(lib)
new['library']=str(lib);makevars=folder/'Makevars';makevars.write_text('MAKEFLAGS = -j2\nLIBR = /Library/Frameworks/R.framework/Versions/4.5-arm64/Resources/lib/libR.dylib\n');new['env']['R_MAKEVARS_USER']=str(makevars)
dep=Path('/Users/pgajer/current_projects/vaginal_microbiome/tools/runtime/r-4.5.2/user-library/RcppEigen');shutil.copytree(dep,lib/'RcppEigen');shutil.copytree(root/'r45-v2/library/ivue',lib/'ivue')
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
record=dict(dependency_source=str(dep),files={str(p.relative_to(lib)):sha(p) for p in lib.rglob('*') if p.is_file()},makevars=str(makevars),makevars_sha256=sha(makevars),linkage=subprocess.check_output(['otool','-L',str(lib/'RcppEigen/libs/RcppEigen.so')],text=True))
assert '/Versions/4.7/' not in record['linkage'];(folder/'preparation.json').write_text(json.dumps(record,indent=2)+'\n')
shutil.copy2(root/'environment.json',root/'environment-v2.json');cfg['runtimes']['r45-v3']=new;(root/'environment.json').write_text(json.dumps(cfg,indent=2)+'\n')
