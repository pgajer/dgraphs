"""Full trace comparisons and raw LP checks; no solve or trajectory alteration."""
import argparse,json,math
from pathlib import Path
import numpy as np
from scipy import sparse

def load(p):return json.loads(Path(p).read_text())
def traces(p):return [json.loads(s) for s in (Path(p)/'trace.jsonl').read_text().splitlines()]
def arrays(a,b,atol,rtol):
 x=np.asarray(a,dtype=float);y=np.asarray(b,dtype=float)
 if x.shape!=y.shape:return dict(pass_limit=False,shape_a=list(x.shape),shape_b=list(y.shape))
 delta=abs(x-y);limit=atol+rtol*np.maximum(abs(x),abs(y));return dict(pass_limit=bool(np.isfinite(x).all() and np.isfinite(y).all() and np.all(delta<=limit)),max_absolute=float(delta.max(initial=0)),max_relative=float((delta/np.maximum(1e-300,np.maximum(abs(x),abs(y)))).max(initial=0)),bitwise_equal=bool(np.array_equal(x,y)),atol=atol,rtol=rtol)

def check_lp(e):
 A=sparse.csr_matrix((e['A_data'],e['A_indices'],e['A_indptr']),shape=e['A_shape']);b=np.asarray(e['b']);c=np.asarray(e['c']);x=np.asarray(e['scales']);z=np.asarray(e['dual']);active=np.asarray(e['active'],dtype=bool);u=np.asarray(e['upper'])
 if x.shape!=c.shape or z.shape!=b.shape or not all(np.isfinite(t).all() for t in [x,z,b,c,u]):return dict(accepted=False,reason='shape_or_nonfinite')
 residual=np.maximum(A@x-b,0);normalized=residual/np.maximum(1,np.maximum(abs(b),abs(A)@abs(x)))
 objective=math.fsum(float(v)*float(w) for v,w in zip(c,x));objerror=abs(objective-e['objective'])/max(1,abs(objective),abs(e['objective']));station=float(abs(c+A.T@z).max());negative=float(np.maximum(-z,0).max(initial=0));dual=-math.fsum(float(v)*float(w) for v,w in zip(b,z));gap=abs(objective-dual)/max(1,abs(objective),abs(dual))
 primal=e['status']=='optimal' and normalized.max(initial=0)<=1e-7 and objerror<=1e-7 and np.all(x[active]>0)
 return dict(accepted=bool(primal),dual_valid=station<=1e-7 and negative<=1e-7 and gap<=1e-7,normalized_primal=float(normalized.max(initial=0)),absolute_primal=float(residual.max(initial=0)),objective_error=objerror,dual_stationarity=station,dual_negative=negative,dual_relative_gap=gap,lower_violation=float(np.maximum(-x,0).max(initial=0)),upper_violation=float(np.maximum(x-u,0).max(initial=0)))

DISCRETE=['event','phase','iteration','representatives','member_to_profile','specimen_ids','profile_ids','initial_edges','edges','degrees','isolates','components','site','number','active','A_shape','A_indices','A_indptr','C','minC','maxC','recycled','bisection_index','bisection_updates','median_target_met','boundary_stop','cap_reached','converged','reason','status','accepted','multiscale','candidates','selected','removed']
FLOATS={'D1':(1e-12,2e-14),'D2':(1e-12,2e-14),'scl':(1e-12,2e-14),'upper':(1e-12,2e-14),'A_data':(1e-12,2e-14),'b':(1e-12,2e-14),'c':(1e-12,2e-14),'scales':(1e-7,1e-7),'ratios':(1e-7,1e-7),'stats':(1e-7,1e-7),'wstats':(1e-7,1e-7),'location':(1e-7,1e-7),'dispersion':(1e-7,1e-7),'threshold':(1e-7,1e-7),'raw_threshold':(1e-7,1e-7),'floored_threshold':(1e-7,1e-7),'cap':(1e-7,1e-7),'median':(1e-7,1e-7),'median_residual':(1e-7,1e-7),'threshold_margins':(1e-7,1e-7),'median_margin':(1e-7,1e-7),'lower_margin':(1e-7,1e-7),'upper_margin':(1e-7,1e-7),'affinity':(1e-7,1e-7)}

def compare(a,b,out):
 A=traces(a);B=traces(b);out=Path(out);out.mkdir(parents=True,exist_ok=False);checks=[];first=None;scl=1
 for i in range(max(len(A),len(B))):
  if i>=len(A) or i>=len(B):bad=['trace_length'];r=dict(index=i,bad=bad)
  else:
   x,y=A[i],B[i];bad=[];numeric={}
   if x['event']=='processed':scl=x['scl']
   for key in DISCRETE:
    if key in x or key in y:
     if x.get(key)!=y.get(key):bad.append(key)
   for key,(atol,rtol) in FLOATS.items():
    if key in x or key in y:
     if key not in x or key not in y:bad.append(key);continue
     if key=='scales' and x['event']=='complete':atol/=scl
     numeric[key]=arrays(x[key],y[key],atol,rtol)
     if not numeric[key]['pass_limit']:bad.append(key)
     if key=='affinity':
      ka=np.asarray(x[key]);kb=np.asarray(y[key]);support=ka.shape==kb.shape and np.array_equal(ka==0,kb==0)
      if not support:bad.append('affinity_zero_support')
   r=dict(index=i,event=x['event'],bad=bad,numeric=numeric)
  checks.append(r)
  if bad and first is None:
   first=i;context=dict(index=i,fields=bad,preceding_a=A[max(0,i-3):i],preceding_b=B[max(0,i-3):i],event_a=A[i] if i<len(A) else None,event_b=B[i] if i<len(B) else None,input_a=str(a),input_b=str(b))
   write(out/'first-divergence.json',context)
 # Only evaluate endpoint checkpoints as an additional check, never a replacement.
 summary=dict(a=str(a),b=str(b),events_a=len(A),events_b=len(B),passed=first is None,first_divergence=first,checks=checks,
  raw_checks_a=[dict(number=e['number'],**check_lp(e)) for e in A if e['event']=='solve'],raw_checks_b=[dict(number=e['number'],**check_lp(e)) for e in B if e['event']=='solve'])
 write(out/'comparison.json',summary);return summary

def write(p,d):Path(p).write_text(json.dumps(d,indent=2,allow_nan=False)+'\n')
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('a');p.add_argument('b');p.add_argument('output');a=p.parse_args();r=compare(a.a,a.b,a.output);print(json.dumps({k:r[k] for k in ['passed','events_a','events_b','first_divergence']}))
