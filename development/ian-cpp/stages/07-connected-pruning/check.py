"""Reconstruct edge-by-edge connected pruning independently of the C++ implementation."""
import json,sys,math
from pathlib import Path
import numpy as np
from scipy.special import ndtri
P=Path(sys.argv[1]);O=Path(sys.argv[2]);O.mkdir(exist_ok=False);load=lambda p:json.loads(Path(p).read_text())
def parts(n,edges):
 groups=[{i} for i in range(n)]
 for a,b in edges:
  x=next(g for g in groups if a in g);y=next(g for g in groups if b in g)
  if x is not y:x.update(y);groups.remove(y)
 return groups

def check(folder):
 events=[json.loads(l) for l in (folder/'trace.jsonl').read_text().splitlines()];result=load(folder/'result.json');protected={};history=[];allchecks=0;max_volume_error=0
 for event in events:
  kind=event['event']
  if kind=='processed':
   edges={tuple(e) for e in event['initial_edges']};D=np.array(event['D1']);D2=np.array(event['D2']);n=len(D);assert len(parts(n,edges))==1
  elif kind=='volume' and not event['multiscale']:vol=event
  elif kind=='decision':
   d=event;stats=np.array(d['stats']);s=np.array(vol['scales']);deg=np.bincount(np.array(sorted(edges)).ravel(),minlength=n);calculated=[]
   for i in range(n):
    weights=np.exp(-D2[i]/s[i]**2);weights[D2[i]/s[i]**2>-math.log(2*np.finfo(float).eps)]=0;k=max(2,int(deg[i]));calculated.append(math.fsum(weights)/(k*(math.sqrt(math.pi)/2)**math.log2(k)))
   max_volume_error=max(max_volume_error,float(np.max(np.abs(stats-calculated))));assert np.allclose(stats,calculated,rtol=1e-10,atol=1e-10)
   pos=stats[stats>0];q1,med,q3=np.quantile(pos,[.25,.5,.75]);loc=.333*((q1+med)+q3);sd=(q3-q1)/(2*ndtri((.75*len(pos)-.125)/(len(pos)+.25)));raw=loc+4.5*sd;floor=max(2.75,raw);cap=6-med;threshold=cap if np.all(pos<=floor) and cap<floor else floor
   assert abs(threshold-d['threshold'])<1e-10 and d['candidate_evaluation_deferred'] and not d['candidates']
   above=int(np.sum(stats>d['threshold']));needed=len(pos)-2*int(np.sum(pos<1.1));expanded=med-1>.1 and needed>above
   order=np.argsort(stats)[::-1].tolist() if expanded else sorted(range(n),key=lambda i:-stats[i]);candidate_count=needed if expanded else above;allowance=max(1,int(.1*candidate_count));seen=set();expected=[];selected=[];removed=[]
   h=dict(iteration=d['iteration'],statistical_candidates=candidate_count,allowance=allowance,examined=0,bridge_skips=0,bridge_checks=0,cached_skips=0,condition_rejections=0,endpoint_conflicts=0,removed=0)
   neighbors={i:sorted([b if a==i else a for a,b in edges if i in (a,b)],key=lambda j:(D[i,j],j),reverse=True) for i in range(n)}
   for rank,i in enumerate(order):
    if i in seen or not neighbors[i]:continue
    j=neighbors[i][0];edge=tuple(sorted([i,j]));assert edge in edges
    a=dict(event='pruning_attempt',iteration=d['iteration'],phase=d['phase'],edge=list(edge),trigger=i,conditions_tested=False,statistic=float(stats[i]),threshold=d['threshold'],margin=float(stats[i]-d['threshold']));h['examined']+=1
    # Component counting from scratch rather than core endpoint reachability.
    isbridge=len(parts(n,edges-{edge}))>1;allchecks+=1
    if edge in protected:
     assert isbridge;a['action']='cached_bridge';h['cached_skips']+=1
    else:h['bridge_checks']+=1;a['action']='new_bridge'
    if isbridge:
     h['bridge_skips']+=1
     if edge not in protected:protected[edge]=dict(edge=list(edge),trigger=i,first_iteration=d['iteration'],last_iteration=d['iteration'],encounters=1,statistic=float(stats[i]),threshold=d['threshold'],margin=float(stats[i]-d['threshold']))
     else:protected[edge]['encounters']+=1;protected[edge]['last_iteration']=d['iteration']
    else:
     a['conditions_tested']=True;eligible=stats[i]>d['threshold'] or (expanded and rank<needed)
     if not eligible:a['action']='conditions_failed';h['condition_rejections']+=1
     elif j in seen:a['action']='endpoint_conflict';h['endpoint_conflicts']+=1
     else:
      a['action']='removed';h['removed']+=1;edges.remove(edge);seen.update([i,j]);selected.append(i);removed.append(list(edge));assert len(parts(n,edges))==1
    expected.append(a)
    if h['removed']>=allowance:break
   history.append(h);position=0
  elif kind=='pruning_attempt':assert event==expected[position];position+=1
  elif kind in ['pruned','graph_stop']:
   assert position==len(expected) and {tuple(e) for e in event['edges']}==edges and len(set(event['components']))==1
   if kind=='pruned':assert event['selected']==selected and event['removed']==removed
   else:assert not removed and event['reason']==('no_connectivity_preserving_removal' if candidate_count else 'no_pruning_candidates')
 assert result['complete'] and result['pruning']['protected_bridges']==list(protected.values()) and result['pruning']['history']==history
 assert len(set(result['graph']['components']))==1 and not result['graph']['isolates']
 return dict(complete=True,connected_at_every_removal=True,attempts_checked=allchecks,protected_edges=len(protected),deletions=sum(h['removed'] for h in history),steps=len(history),stop_reason=result['pruning']['stop_reason'],maximum_volume_error=max_volume_error,final_edges=len(edges))
rows={}
for c in load(P/'fixtures.json')['cases']:
 if c['variant']:
  rows[c['name']]=check(P/'runs'/c['name']/'native/child');print(c['name'],rows[c['name']]['stop_reason'],flush=True)
(O/'summary.json').write_text(json.dumps(dict(passed=True,cases=rows,new_solver_calls=0),indent=2)+'\n')
