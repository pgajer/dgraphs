"""Reconcile raw executions, exact vectors, failure location and build provenance."""
import hashlib,itertools,json,math,subprocess,sys
from collections import Counter
from decimal import Decimal,localcontext
from pathlib import Path
from checks import load,write,events,sha,arrays
from validate import exact,retry_checks
from provenance import build_identity
root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
fixtures=load(root/'fixtures-v1/manifest.json')['cases'];panel=load(root/'panel-v2/ledger.json');old=load(root/'panel-v1/ledger.json');ops=load(root/'operational-v1/checks.json')
assert panel['complete'] and panel['comparison_gate'] and len(panel['runs'])==50 and not panel['gated']
assert old['complete'] and ops['complete'] and ops['passed']
assert all(x['passed'] for x in panel['comparisons'].values()) and all(x['same_path']['passed'] for x in panel['runs'].values())
rows=[];raw_pairs=0;raw_pair_count=0;raw_differences=[]
for f in fixtures:
 n=f['name'];assert sha(f['input'])==f['sha256'] and sha(f['source'])==f['source_sha256']
 source=load(f['source']);candidate=load(f['input']);candidate.pop('numerical_policy');source.pop('numerical_policy',None);assert source==candidate
 pair={c:panel['runs'][n+'/'+c] for c in ['native','evaluated']}
 r=dict(name=n,kind=f['kind'],attempts={c:e['process']['observed_solves'] for c,e in pair.items()},complete={c:e['complete'] for c,e in pair.items()})
 if n!='helix_500':assert all(e['passed'] for e in pair.values())
 else:assert all(not e['complete'] and e['process']['exit_code']==1 for e in pair.values())
 if f['kind']!='stage':
  vector_count=0;pair_count=0;maxima={};differences=[]
  for x,y in itertools.zip_longest(events(Path(pair['native']['child'])/'trace.jsonl'),events(Path(pair['evaluated']['child'])/'trace.jsonl')):
   assert x is not None and y is not None and x['event']==y['event']
   if x['event']=='solve':
    pair_count+=1
    fields=['scales','dual','objective','iterations','A_data','b','c','A_indices','A_indptr','A_shape']
    different=[k for k in fields if x[k]!=y[k]]
    vector_count+=int(not different)
    if different:differences.append(dict(number=x['number'],fields=different))
    for k in ['scales','dual','objective','A_data','b']:
     maxima[k]=max(maxima.get(k,0),arrays(x[k],y[k],1e-7,1e-7)['max_absolute'])
  raw_pairs+=vector_count;raw_pair_count+=pair_count;r.update(exact_raw_solver_pairs=vector_count,raw_solver_pairs=pair_count,raw_maximum_absolute_differences=maxima,nonidentical_pairs=differences)
  for c,e in pair.items():
   previous=old['runs'][n+'/'+c];check=exact(Path(previous['child'])/'trace.jsonl',Path(e['child'])/'trace.jsonl');assert check['passed'];r['preliminary_same_path_'+c]=check
  native=pair['native']['checks'];retry=native['retry_checks'] if 'retry_checks' in native else native
  r['accepted']=retry['accepted'];r['rejected']=len(retry['rejected']);r['retries']=len(retry['retries'])
  if f['kind'] in ['full','scale']:
   r['pruning_iterations']=native['counts'].get('pruned',0)
   r['final_topology']=native['topology'][-1] if native['complete'] else None
   if native['complete']:assert all(e['checks']['final_affinity_reconstruction']['pass_limit'] and e['checks']['final_affinity_reconstruction']['zero_support_equal'] for e in pair.values())
 else:assert load(Path(pair['native']['child'])/'stages.json')==load(Path(pair['evaluated']['child'])/'stages.json')
 rows.append(r)
# Physical guarded executions only: joined and falsified traces are not new solves.
processes=old['processes']+panel['processes']+ops['processes'];census=[];total=Counter()
for p in processes:
 if not p['observed_solves']:continue  # Diagnostic arguments name existing input traces, not new executions.
 child=next((Path(arg) for arg in p['command'] if str(arg).endswith('/child')),None)
 if child is None or not (child/'trace.jsonl').exists():continue
 counts=Counter()
 for e in events(child/'trace.jsonl'):
  if e['event']=='solve':
   counts['attempts']+=1;counts['accepted' if e['accepted'] else 'rejected']+=1
   if e.get('test_fault'):counts['injected_attempts']+=1
 assert counts['attempts']==p['observed_solves']
 if counts['attempts']:census.append(dict(child=str(child),**counts));total.update(counts)
assert total['attempts']==sum(p['observed_solves'] for p in processes)<8000
assert sum(p['wall_seconds'] for p in processes)<3600 and all(p['reason'] is None for p in processes)
# Independently check every operational solution, including expected rejection.
operation_checks=[]
for p in ops['processes']:
 if not p['observed_solves']:continue
 child=next(Path(arg) for arg in p['command'] if str(arg).endswith('/child'))
 operation_checks.append(dict(child=str(child),checks=retry_checks(child,out/('operation-'+child.parent.name),True)))
# Pin the newly encountered fixed problem and exact binary64 dual residual.
trace=Path(panel['runs']['helix_500/native']['child'])/'trace.jsonl';solves=[e for e in events(trace) if e['event']=='solve']
a,b=solves[-2:];assert a['number']==17 and b['number']==18
write(out/'unresolved-first-attempt.json',a);write(out/'unresolved-retry.json',b)
terms=[[float(c)] for c in b['c']];sources=[[] for _ in b['c']]
for i,z in enumerate(b['dual']):
 for k in range(b['A_indptr'][i],b['A_indptr'][i+1]):
  j=b['A_indices'][k];terms[j].append(b['A_data'][k]*z);sources[j].append((b['A_data'][k],z))
j=max(range(len(terms)),key=lambda j:abs(math.fsum(terms[j])))
with localcontext() as ctx:
 ctx.prec=80
 decimal=Decimal.from_float(float(b['c'][j]))+sum((Decimal.from_float(float(v))*Decimal.from_float(float(z)) for v,z in sources[j]),Decimal(0))
failure=dict(C=b['C'],iteration=b['iteration'],phase=b['phase'],baseline_iterations=a['iterations'],retry_iterations=b['iterations'],baseline_dual=a['dual_check'],retry_dual=b['dual_check'],retry_primal=b['validation'],worst_column_zero_based=j,scalar_stationarity=abs(math.fsum(terms[j])),decimal_stationarity=str(abs(decimal)),threshold=1e-7,largest_term=max(map(abs,terms[j])),sum_absolute_terms=math.fsum(map(abs,terms[j])),accepted_graph_checkpoint=False)
# Reconstruct the preliminary fingerprint mismatch from recorded source revision.
prefix='development/ian-cpp-phase1/phase07c/';rev=old['revision'];names=subprocess.check_output(['git','ls-tree','-r','--name-only',rev,prefix],text=True).splitlines();names=sorted(n for n in names if n.startswith(tuple(prefix+d+'/' for d in ['include','src','tests'])) and Path(n).suffix in ['.hpp','.cpp','.inc'])
raw={n:subprocess.check_output(['git','show',rev+':'+n]) for n in names};cmake=subprocess.check_output(['git','show',rev+':'+prefix+'CMakeLists.txt']);digest=lambda b:hashlib.sha256(b).hexdigest();identity=lambda:digest((''.join(digest(raw[n]) for n in names)+digest(cmake)).encode())
expected=identity();name=prefix+'tests/retry_tests.cpp';raw[name]=raw[name].replace(b'#include <filesystem>\n',b'').replace(b'        std::filesystem::create_directories(argv[2]);\n',b'');stale=identity()
assert stale in (root/'build-v1/CMakeFiles/ian_core.dir/flags.make').read_text() and expected!=stale
current=build_identity(root/'build-v2');assert current==panel['build_identity']
warning_logs=[]
for folder in ['panel-v1','panel-v2','operational-v1']:
 for p in (root/folder).rglob('stderr.log'):
  text=p.read_text()
  if 'Warning' in text:warning_logs.append(dict(path=str(p),warning_lines=sum('Warning' in s for s in text.splitlines())))
result=dict(complete=True,rows=rows,raw_solver_pairs_exact=raw_pairs,raw_solver_pairs=raw_pair_count,primary_attempts=sum(e['process']['observed_solves'] for e in panel['runs'].values()),primary_accepted=sum(r.get('accepted',0)*2 for r in rows),primary_rejected=sum(r.get('rejected',0)*2 for r in rows),operational_checks=operation_checks,operation_assertions=len(ops['tests']),operation_attempts=sum(p['observed_solves'] for p in ops['processes']),census=census,total=dict(total),guarded_processes=len(processes),guarded_wall_seconds=sum(p['wall_seconds'] for p in processes),maximum_sampled_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in processes),failure=failure,build_provenance=dict(preliminary_embedded=stale,preliminary_committed_expected=expected,final=current),warning_logs=warning_logs,natural_retry_checkpoint_available=ops['natural_retry_checkpoint_available'])
write(out/'results.json',result)
print({k:result[k] for k in ['complete','primary_attempts','primary_accepted','primary_rejected','raw_solver_pairs_exact','operation_attempts','total','guarded_wall_seconds']})
