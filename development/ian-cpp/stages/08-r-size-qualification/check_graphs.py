"""Independent component-count bridge verification of saved connected traces."""
import sys,json
from pathlib import Path
P=Path(sys.argv[1]);O=Path(sys.argv[2]);O.mkdir(exist_ok=False)
def parts(n,edges,exclude=None):
 parent=list(range(n));count=n
 def find(a):
  while parent[a]!=a:parent[a]=parent[parent[a]];a=parent[a]
  return a
 for e in edges:
  if e==exclude:continue
  a,b=map(find,e)
  if a!=b:parent[a]=b;count-=1
 return count

def check(path):
 protected=set();attempts=0;removed=[];deletions=0;batches=0;cache_hits=0
 with path.open() as stream:
  for line in stream:
   e=json.loads(line);kind=e['event']
   if kind=='processed':n=len(e['D1']);edges={tuple(v) for v in e['initial_edges']};assert parts(n,edges)==1
   elif kind=='decision':removed=[]
   elif kind=='pruning_attempt':
    edge=tuple(e['edge']);assert edge in edges;bridge=parts(n,edges,edge)>1;action=e['action'];attempts+=1
    if action in ['new_bridge','cached_bridge']:
     assert bridge and not e['conditions_tested']
     if action=='cached_bridge':assert edge in protected;cache_hits+=1
     else:assert edge not in protected;protected.add(edge)
    else:
     assert not bridge and e['conditions_tested']
     if action=='removed':edges.remove(edge);removed.append(e['edge']);deletions+=1
   elif kind in ['pruned','graph_stop']:
    assert {tuple(v) for v in e['edges']}==edges and parts(n,edges)==1 and len(set(e['components']))==1
    if kind=='pruned':assert e['removed']==removed;batches+=1
    else:assert not removed
 return dict(n=n,proposals=attempts,deletions=deletions,batches=batches,cache_hits=cache_hits,protected_edges=len(protected),final_edges=len(edges),final_components=parts(n,edges),passed=True)
rows={}
for path in sorted((P/'panel-v2/runs').glob('*-connected/native/child/trace.jsonl')):
 rows[str(path.relative_to(P))]=check(path);print(path.parts[-4],rows[str(path.relative_to(P))]['proposals'],flush=True)
for path in sorted((P/'supplement-v1/runs').glob('*_2000/native/child/trace.jsonl')):rows[str(path.relative_to(P))]=check(path)
(O/'summary.json').write_text(json.dumps(dict(passed=True,engine_calls=0,cases=rows),indent=2)+'\n')
