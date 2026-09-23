"""Final read-only vector/settings census; all earlier artifacts remain untouched."""
import sys,json,itertools,hashlib
from pathlib import Path
import numpy as np
P=Path(sys.argv[1]);O=P/'final-checks.json';assert not O.exists();M=json.loads((P/'manifest.json').read_text());L=json.loads((P/'ledger.json').read_text())
def events(p):
 with Path(p).open() as f:
  for line in f:yield json.loads(line)
base=P.parent/'stage04-performance/qual-native-pressmat_hellinger_subset/child/0/trace.jsonl';settings=next(e['settings'] for e in events(base) if e['event']=='solve');rows=[];total=accepted=0
for c in M['cases']:
 A=P/'runs'/c['name']/'native/child/trace.jsonl';B=P/'runs'/c['name']/'evaluated/child/trace.jsonl';dualdiff=scalediff=0;count=0
 for a,b in itertools.zip_longest(events(A),events(B)):
  assert a is not None and b is not None and a['event']==b['event']
  if a['event']!='solve':continue
  count+=1;total+=2;accepted+=int(a['accepted'])+int(b['accepted'])
  for key in ['dual','scales']:
   x=np.asarray(a[key]);y=np.asarray(b[key]);assert np.all(np.abs(x-y)<=1e-7+1e-7*np.maximum(np.abs(x),np.abs(y)))
   diff=float(np.max(np.abs(x-y),initial=0))
   if key=='dual':dualdiff=max(dualdiff,diff)
   else:scalediff=max(scalediff,diff)
  expected=dict(settings)
  for key in ['tol_gap_abs','tol_gap_rel','tol_feas']:expected[key]=a['solver_tolerance']
  assert a['settings']==expected
 rows.append(dict(dataset=c['name'],paired_attempts=count,max_dual_difference=dualdiff,max_scale_difference=scalediff,all_native_settings_match_accepted_policy=True))
assert len(L['processes'])==18 and total==sum(p['optimizer_calls'] for p in L['processes'])==572
assert all(x['state']=='reaped' and x['reason'] is None and x['exit_code']==0 for x in L['processes'])
result=dict(passed=True,entries=18,full_payloads=total,accepted=accepted,rejected_then_retried=total-accepted,settings_records=total//2,cases=rows,baseline_settings_trace=str(base),baseline_sha256=hashlib.sha256(base.read_bytes()).hexdigest())
O.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
