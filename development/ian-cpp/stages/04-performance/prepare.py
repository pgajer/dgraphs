"""Identity-bound preparation and driver compilation. No engine entry."""
import sys,json,hashlib,subprocess,time,platform
from pathlib import Path
H=Path(__file__).resolve().parent;ROOT=H.parents[3];P=Path(sys.argv[1]);P.mkdir(parents=True,exist_ok=False)
S=P.parent/'stage01-policy';B=S/'build-v1';load=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
write=lambda p,v:Path(p).write_text(json.dumps(v,indent=2)+'\n')
bm=load(B/'manifest.json');cfg=load(P.parent/'stage03-package/environment.json')['runtimes']['rdevel-v2']
cases=[]
for name,path,baseline in [('pressmat_hellinger_subset',B/'fixtures/pressmat_hellinger_subset.json',S/'qualification-v2/runs/pressmat_hellinger_subset'),('helix_500',B/'fixtures/helix_500.json',S/'qualification-v2/runs/helix_500'),('quadform_d4_1000',P.parent/'stage02-scale/fixtures-v1/quadform_d4_1000.json',P.parent/'stage02-scale/panel-v1/runs/quadform_d4_1000')]:
 cases.append(dict(name=name,path=str(path),sha256=sha(path),baseline=str(baseline)))
manifest=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cases=cases,reference=str(S/'reference-v2'),library=cfg['library'],rscript=cfg['rscript'],r_environment=cfg['env'],wrapper=str(ROOT/'R/ian_graph.R'),**{'trace.writer':str(H.parent/'01-numerical-policy/trace_json.R')},platform=platform.platform(),cpu=subprocess.check_output(['sysctl','-n','machdep.cpu.brand_string'],text=True).strip(),sources={str(p):sha(p) for p in H.iterdir() if p.is_file()},reference_hashes={p.name:sha(p) for p in (S/'reference-v2').glob('*.py')},commands=[])
source=B/'source';lib=Path(bm['solver_archive']['path']);assert sha(lib)==bm['solver_archive']['sha256'];manifest['linked_inputs']={str(p):sha(p) for p in [B/'core.o',B/'identity_json.o',B/'testing_json.o',lib,Path(cfg['library'])/'dgraphs/ian/native/dgraphs_ian.so',ROOT/'R/ian_graph.R']}
cmd=['clang++','-std=c++17','-O2','-ffp-contract=off','-fno-fast-math','-Wno-deprecated-declarations','-I'+str(source/'core/include'),'-I'+str(source/'core/src'),'-I'+str(source/'Clarabel.cpp/include'),str(H/'native.cpp'),str(B/'core.o'),str(B/'identity_json.o'),str(B/'testing_json.o'),str(lib),'-framework','Security','-framework','CoreFoundation','-o',str(P/'native')]
write(P/'manifest.json',manifest);start=time.monotonic()
with (P/'build.log').open('w') as f:r=subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,timeout=300)
manifest['commands'].append(dict(command=cmd,returncode=r.returncode,seconds=time.monotonic()-start));write(P/'manifest.json',manifest);assert r.returncode==0
manifest['native_sha256']=sha(P/'native');write(P/'manifest.json',manifest)
print('Prepared fixtures and persistent driver; zero solves.')
