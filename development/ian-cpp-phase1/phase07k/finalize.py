"""Bind immutable evidence and check literal binary64 equality. No solves."""
import itertools,platform,importlib.metadata
import numpy as np
from common import *
root=Path(sys.argv[1]);derivation=load(root/'derivation.json');ledger=load(root/'ledger.json')
for p,h in derivation['parent_files'].items():assert sha(p)==h,('historical_source_changed',p)
for mode,files in derivation['derivations'].items():
 for p,h in files.items():
  path=root/mode/'build/ian_engine' if p=='engine_sha256' else root/mode/'candidate'/p
  assert sha(path)==h,('candidate_changed',path)
for p,h in load(root/'arithmetic.json')['source_files'].items():assert sha(p)==h,('historical_evidence_changed',p)
bits={}
for name,i,j in [('power',4,5),('power_vs_historical_python',4,1),('multiply',2,3)]:
 count=0;fields=0
 a=events(root/f'runs/{i}/child/trace.jsonl');b=events(root/f'runs/{j}/child/trace.jsonl')
 for x,y in itertools.zip_longest(a,b):
  assert x is not None and y is not None and x['event']==y['event']
  keys=['A_data','b','c','upper','scales','dual'] if x['event']=='solve' else ['scales','affinity'] if x['event']=='complete' else []
  for key in keys:
   xx=np.asarray(x[key],dtype='<f8');yy=np.asarray(y[key],dtype='<f8')
   assert xx.shape==yy.shape and xx.tobytes()==yy.tobytes(),(name,count,key)
   fields+=1
  count+=x['event']=='solve'
 bits[name]=dict(solves=count,fields_bitwise_equal=fields)
externals=set(derivation['parent_files'])|set(load(root/'arithmetic.json')['source_files'])
externals.update(p['cell']['fixture'] for p in ledger['processes'])
externals.update([str(W/'phase07e/build-v1/ian_engine'),str(W/'phase06a/clean-v2/prefix/lib/libclarabel_c.dylib')])
for p in (root/'baseline-supplement').glob('*/checks/summary.json'):externals.add(load(p)['left'])
manifest=dict(solver_calls=ledger['optimizer_calls'],execution_source=ledger['revision'],finalization_source=revision(),all_parent_and_candidate_hashes_preserved=True,binary64_checks=bits,external_inputs={p:sha(p) for p in sorted(externals)},files={str(p.relative_to(root)):sha(p) for p in sorted(root.rglob('*')) if p.is_file() and p.name not in ['manifest.json'] and '__pycache__' not in p.parts},platform=platform.platform(),python=sys.version,packages={p:importlib.metadata.version(p) for p in ['numpy','scipy','cvxpy','clarabel']},compiler=subprocess.check_output(['clang++','--version'],text=True),scope='Author evidence preservation and literal bit checks, not an independent audit')
assert not (root/'manifest.json').exists();write(root/'manifest.json',manifest)
print(dict(preserved=True,binary64_checks=bits,files=len(manifest['files']),solver_calls=manifest['solver_calls']))
