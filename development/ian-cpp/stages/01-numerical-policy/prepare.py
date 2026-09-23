"""Freeze fixtures, derive the matching Python reference, and build; no solves."""
from pathlib import Path
import json,hashlib,subprocess,shutil,sys
ROOT=Path(__file__).resolve().parents[4];HERE=Path(__file__).resolve().parent
W=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker')
POLICY='IAN evaluated-LP retry-power 0.1'
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
write=lambda p,x:Path(p).write_text(json.dumps(x,indent=2)+'\n')
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
manifest={'revision':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),'commands':[],'sources':{},'fixtures':[]}
backend=ROOT/'inst/ian/backend';source=out/'source';shutil.copytree(backend,source)
manifest['sources']={str(p.relative_to(source)):sha(p) for p in source.rglob('*') if p.is_file()}
identity=hashlib.sha256(json.dumps(manifest['sources'],sort_keys=True).encode()).hexdigest();config=sha(source/'core/config.json')
manifest.update(source_identity=identity,configuration_identity=config)
ref=out/'reference';ref.mkdir();old=ROOT/'development/ian-cpp-phase1/phase07e/candidate'
for name in ['reference.py','reference_probe.py','retry_policy.py']:shutil.copy2(old/name,ref/name)
p=ref/'reference.py';s=p.read_text().replace('IAN evaluated-LP retry units11 almost 0.1',POLICY)
s=s.replace('import clarabel','import clarabel\nimport math\ndef _square(v): return math.pow(float(v),2.)').replace('C**2','_square(C)')
a=" generated=generate.prepare(folder/'source');text=generated.read_text()";assert a in s;s=s.replace(a,a+"\n assert text.count('e_len**2')==1 and text.count('w**2')==1\n text=text.replace('e_len**2','_ian_square(e_len)').replace('w**2','_ian_square(w)')");s=s.replace(' exec(compile(tree',' module._ian_square=_square\n exec(compile(tree');p.write_text(s)
manifest['reference']={str(p.name):sha(p) for p in ref.iterdir()}
fixtures=out/'fixtures';fixtures.mkdir()
cases=json.loads((W/'phase07e/engine-fixtures-v1/manifest.json').read_text())['cases']
cases=sorted(cases,key=lambda c:({'stage':0,'probe':1,'full':2,'scale':3}[c['kind']],c['name']))
cases.append({'name':'helix_1000','kind':'scale','input':str(W/'phase07f/fixtures-v1/helix_1000.json')})
for c in cases:
 p=Path(c['input']);j=json.loads(p.read_text());j['numerical_policy']=POLICY;dst=fixtures/p.name;write(dst,j)
 manifest['fixtures'].append(dict(name=c['name'],kind=c['kind'],source=str(p),source_sha256=sha(p),path=str(dst),sha256=sha(dst)))
for name in ['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset']:
 p=fixtures/(name+'.json');j=json.loads(p.read_text());j['numerical_policy']='IAN evaluated-LP 1.0';dst=fixtures/(name+'-strict.json');write(dst,j)
manifest['strict']={str(p.name):sha(p) for p in fixtures.glob('*-strict.json')}
# Reuse independently built, immutable pinned Rust archive; C++/R module rebuilt.
lib=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/typed-core/evidence/backend-v1/target/release/libclarabel_c.a')
manifest['solver_archive']={'path':str(lib),'sha256':sha(lib)}
base=['clang++','-std=c++17','-O2','-ffp-contract=off','-fno-fast-math', '-Wno-deprecated-declarations', '-I'+str(source/'core/include'),'-I'+str(source/'core/src'),'-I'+str(source/'Clarabel.cpp/include'),'-DSOURCE_HASH="'+identity+'"','-DCONFIG_HASH="'+config+'"']
objects=[]
def call(name,cmd):
 with (out/(name+'.log')).open('w') as f:r=subprocess.run(list(map(str,cmd)),stdout=f,stderr=subprocess.STDOUT)
 manifest['commands'].append({'name':name,'cmd':list(map(str,cmd)),'returncode':r.returncode});write(out/'manifest.json',manifest)
 if r.returncode:raise SystemExit('build failed '+name)
for name in ['core','identity_json','testing_json']:
 obj=out/(name+'.o');call(name,base+['-fPIC','-c',source/f'core/src/{name}.cpp','-o',obj]);objects.append(obj)
for name,file in [('engine','cli.cpp'),('probe','probe.cpp')]:call(name,base+[HERE/file,*objects,lib,'-framework','Security','-framework','CoreFoundation','-o',out/name])
rhome=subprocess.check_output(['R','RHOME'],text=True).strip();rcpp=subprocess.check_output(['Rscript','--vanilla','-e','cat(system.file("include",package="Rcpp"))'],text=True).strip()
call('module',base+['-fPIC','-shared','-undefined','dynamic_lookup','-Wl,-install_name,@rpath/dgraphs_ian.so','-I'+rhome+'/include','-I'+rcpp,source/'bridge.cpp',*objects[:2],lib,'-framework','Security','-framework','CoreFoundation','-o',out/'dgraphs_ian.so'])
call('no-json',base+['-c',ROOT/'dev/ian/typed-core/no_json_headers.cpp','-o',out/'no-json.o'])
manifest['binaries']={n:sha(out/n) for n in ['engine','probe','dgraphs_ian.so']};write(out/'manifest.json',manifest)
print('Built typed candidate and froze 26 fixtures; no solves.')
