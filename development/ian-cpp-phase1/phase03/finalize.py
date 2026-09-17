"""Freeze final provenance and independently check durable stage artifacts; no solves."""
import argparse,json,subprocess,sys
from pathlib import Path
import numpy as np
from scipy import sparse
from scipy.sparse.csgraph import connected_components
from reference import sha,write,FROZEN,CYTHON
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('label');a=p.parse_args();w=a.root.parent;repo=Path.cwd();phase=Path('development/ian-cpp-phase1/phase03')
assert str(repo)=='/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree'
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
for name in ['checks','manifest']:assert not (a.root/f'final-{name}-{a.label}.json').exists()
prior_counts={}
for base,file in [(w,w/'evidence-manifest.json'),(w/'phase02',w/'phase02/evidence-manifest-v1.json')]:
 d=json.loads(file.read_text())
 for name,record in d['files'].items():assert sha(base/name)==record['sha256'],name
 prior_counts[str(base)]=len(d['files'])
 if base.name=='phase02':
  for name,record in d['source_files'].items():assert sha(repo/name)==record['sha256'],name
frozen=[]
for rev,files in [('8a106da',['numeric.hpp','solver.hpp','CMakeLists.txt','config.json']),('abfe23b',['engine.cpp','reference.py','verify_native.py']),('1f7e861',['stages.py']),('8d886b7',['run_case.py','run_stages.py']),('1f8c269',['failures.py']),('c72aad8',['compare.py','supplement.py']),('27b195e',['fixtures.py'])]:
 for name in files:
  path=phase/name;assert path.read_bytes()==subprocess.check_output(['git','show',f'{rev}:{path}']);frozen.append(dict(path=str(path),revision=rev,sha256=sha(path)))
manifest=json.loads((a.root/'fixtures-v1/manifest.json').read_text())
for name,digest in manifest['files'].items():assert sha(a.root/'fixtures-v1'/name)==digest
source_provenance=[json.loads(p.read_text()) for p in a.root.rglob('source/provenance.json')]
assert source_provenance and all(p==source_provenance[0] for p in source_provenance)
assert source_provenance[0]['cython']==sha(CYTHON)
assert source_provenance[0]['ian']==sha(FROZEN/'build/source-evidence/ian/ian/ian.py')
assert source_provenance[0]['adapter']==sha(FROZEN/'scripts/prepare_ian_adapter.py')
assert source_provenance[0]['audit']==sha(FROZEN/'scripts/pilot_audit.py')
checkpoints=[]
# Every successfully committed ordinary/injection checkpoint, including initial native.
for graphfile in sorted(a.root.rglob('child/graph.json')):
 folder=graphfile.parent;g=json.loads(graphfile.read_text());n=len(g['mapping']['profile_ids']);edges=np.asarray(g['edges'],dtype=int).reshape(-1,2)
 assert len(set(map(tuple,edges)))==len(edges) and np.all((edges>=0)&(edges<n)) and np.all(edges[:,0]<edges[:,1])
 assert edges.tolist()==sorted(edges.tolist())
 degree=np.bincount(edges.ravel(),minlength=n);assert degree.tolist()==g['degrees'];assert np.flatnonzero(degree==0).tolist()==g['isolates']
 adj=sparse.coo_matrix((np.ones(2*len(edges)),(np.r_[edges[:,0],edges[:,1]],np.r_[edges[:,1],edges[:,0]])),shape=(n,n)).tocsr();_,labels=connected_components(adj,directed=False);assert labels.tolist()==g['components']
 events=[json.loads(l) for l in (folder/'trace.jsonl').read_text().splitlines()];processed=next(e for e in events if e['event']=='processed');D=np.asarray(processed['D1']);u=np.zeros(n)
 np.maximum.at(u,edges[:,0],D[edges[:,0],edges[:,1]]);np.maximum.at(u,edges[:,1],D[edges[:,0],edges[:,1]]);assert np.array_equal(u,g['upper'])
 status=json.loads((folder/'status.json').read_text());assert status['graph'] and status['graph_sha256']==sha(graphfile)
 for stage in ['graph','scales','affinity']:
  f=folder/(stage+'.json')
  assert f.exists()==status[stage]
  if f.exists():
   d=json.loads(f.read_text());assert d['stage']==stage and d['status']=='validated';assert d['configuration_sha256']==sha(phase/'config.json');assert status[stage+'_sha256']==sha(f)
 if status['affinity']:
  d=json.loads((folder/'affinity.json').read_text());K=np.asarray(d['affinity']);sc=json.loads((folder/'scales.json').read_text());scales=np.asarray(sc['internal_scales']);D2=np.asarray(processed['D2']);inv=np.ones(n);inv[degree>0]=1/scales[degree>0];power=(inv[None,:]*D2)*inv[:,None];expected=np.zeros_like(D2);np.exp(-power,where=power<-np.log(2*np.finfo(float).eps),out=expected);expected[expected<1e-8]=0;expected[degree==0,:]=0;expected[:,degree==0]=0;expected=np.maximum(expected,expected.T)
  assert np.array_equal(K==0,expected==0) and np.allclose(K,expected,rtol=1e-7,atol=1e-7)
  assert np.array_equal(np.diag(K),(degree>0).astype(float));assert np.array_equal(K,K.T) and np.isfinite(K).all() and np.all((K>=0)&(K<=1))
 checkpoints.append(dict(folder=str(folder),graph_sha256=sha(graphfile),stages={s:status[s] for s in ['graph','scales','affinity','complete']}))
analysis=json.loads((a.root/'analysis-v1/results.json').read_text());assert analysis['total_optimizations']==81 and analysis['valid_raw_payloads']==80
references={str(path):dict(sha256=sha(path),bytes=path.stat().st_size) for path in [CYTHON,FROZEN/'build/source-evidence/ian/ian/ian.py',FROZEN/'build/source-evidence/ian/ian/cutils.pyx',FROZEN/'scripts/prepare_ian_adapter.py',FROZEN/'scripts/pilot_audit.py',FROZEN/'scripts/run_ian_pilot.py',FROZEN/'scripts/run_full_cohort_background.py',w/'build-v2/rust-target/release/libclarabel_c.dylib']}
write(a.root/f'final-checks-{a.label}.json',dict(revision=revision,status='',branch='codex/ian-cpp-feasibility-20260917',phase_base='322595c73047c4df3ac9c3b43ed44b20effafcd4',cwd=str(repo),prior_artifacts_preserved=prior_counts,source_checks=frozen,reference_hashes=references,checkpoints=checkpoints,analysis_sha256=sha(a.root/'analysis-v1/results.json'),note='Raw solve checks are in analysis-v1. These checks validate provenance, input integrity and durable graph/affinity contents without executing an optimization.'))
files={str(p.relative_to(a.root)):dict(sha256=sha(p),bytes=p.stat().st_size) for p in sorted(a.root.rglob('*')) if p.is_file() and not p.name.startswith('final-manifest-')}
sourcefiles={p:dict(sha256=sha(p),bytes=Path(p).stat().st_size) for p in subprocess.check_output(['git','ls-files',str(phase)],text=True).splitlines()}
write(a.root/f'final-manifest-{a.label}.json',dict(revision=revision,files=files,source_files=sourcefiles,note='Excludes this manifest and later handoff outside phase03. Includes failed build-v1 and original/verification runs; no earlier evidence overwritten.'))
print(json.dumps(dict(revision=revision,files=len(files),source_files=len(sourcefiles),graph_checkpoints_checked=len(checkpoints),prior_artifacts_preserved=prior_counts),indent=2))
