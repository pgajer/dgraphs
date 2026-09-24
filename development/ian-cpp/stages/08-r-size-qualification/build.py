"""Snapshot and compile optional module/CLI using the accepted pinned Rust archive."""
import sys,json,hashlib,subprocess,shutil
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];O=Path(sys.argv[1]);O.mkdir(parents=True,exist_ok=False)
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest();write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n')
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
S=O/'source';shutil.copytree(ROOT/'inst/ian/backend',S)
files={str(p.relative_to(S)):sha(p) for p in S.rglob('*') if p.is_file()};identity=hashlib.sha256(json.dumps(files,sort_keys=True).encode()).hexdigest();config=sha(S/'core/config.json')
lib=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/evidence/backend-v1/target/release/libclarabel_c.a')
m=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),files=files,source_identity=identity,solver_archive=dict(path=str(lib),sha256=sha(lib)),commands=[],complete=False)
base=['clang++','-std=c++17','-O2','-ffp-contract=off','-fno-fast-math','-Wno-deprecated-declarations','-I'+str(S),'-I'+str(S/'core/include'),'-I'+str(S/'core/src'),'-I'+str(S/'Clarabel.cpp/include'),'-DSOURCE_HASH="'+identity+'"','-DCONFIG_HASH="'+config+'"']
def call(name,cmd):
 with (O/(name+'.log')).open('w') as f:r=subprocess.run(list(map(str,cmd)),stdout=f,stderr=subprocess.STDOUT,timeout=600)
 m['commands'].append(dict(name=name,argv=list(map(str,cmd)),exit_code=r.returncode));write(O/'manifest.json',m);print(name,r.returncode,flush=True);assert r.returncode==0
obj=[]
for name in ['core','identity_json','testing_json']:
 f=O/(name+'.o');call(name,base+['-fPIC','-c',S/f'core/src/{name}.cpp','-o',f]);obj.append(f)
call('engine',base+[H.parent/'01-numerical-policy/cli.cpp',*obj,lib,'-framework','Security','-framework','CoreFoundation','-o',O/'engine'])
call('controls',base+[H/'controls.cpp','-o',O/'controls'])
rhome=Path('/Library/Frameworks/R.framework/Resources');rcpp=subprocess.check_output([rhome/'bin/Rscript','--vanilla','-e','cat(system.file("include",package="Rcpp"))'],text=True).strip()
call('module',base+['-fPIC','-shared','-undefined','dynamic_lookup','-I'+str(rhome/'include'),'-I'+rcpp,S/'bridge.cpp',*obj[:2],lib,'-framework','Security','-framework','CoreFoundation','-o',O/'dgraphs_ian.so'])
call('no-json',base+['-c',ROOT/'dev/ian/typed-core/no_json_headers.cpp','-o',O/'no-json.o'])
m['complete']=True;m['binaries']={n:sha(O/n) for n in ['engine','controls','dgraphs_ian.so']};write(O/'manifest.json',m)
