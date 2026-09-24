"""Read-only binary64 reconstruction and convergence-history analysis. No solves."""
import math
from fractions import Fraction
from common import *
root=Path(sys.argv[1]);out={}
traces={k:W/f'phase07f/ladder-v1/helix_1000/{k}/child/trace.jsonl' for k in ['native','evaluated']}
terminal=load(W/'phase07f/analysis-v1/helix_1000-native-terminal-problem.json')
D=None
for e in events(traces['native']):
 if e['event']=='processed':D=e['D1'];break
r=882;start=terminal['A_indptr'][r];i,j=terminal['A_indices'][start:start+2];d=D[i][j];u=terminal['upper'][i];C=terminal['C']
values={'distance':d,'upper':u,'C':C,'multiply_square':d*d,'power_square':math.pow(d,2),'correctly_rounded_square':float(Fraction(d)**2),'multiply_rhs':(-(d*d)/u)*(C*C)-d*C,'power_rhs':(-math.pow(d,2)/u)*math.pow(C,2)-d*C}
out['origin']=dict(row_zero_based=r,profiles_zero_based=[i,j],values={k:dict(value=v,hex=v.hex()) for k,v in values.items()},difference_ulp=abs(values['multiply_rhs']-values['power_rhs'])/math.ulp(values['multiply_rhs']))
out['reconstruction']={}
for interface,path in traces.items():
 rows=[]
 for e in events(path):
  if e['event']!='solve':continue
  C=e['C'];u=e['upper'];n=len(u);edge_rows=len(e['b'])-2*n
  for mode,square in [('multiply',lambda x:x*x),('power',lambda x:math.pow(x,2.))]:
   b=[];a=[]
   for r in range(0,edge_rows,2):
    start=e['A_indptr'][r];i,j=e['A_indices'][start:start+2];d=D[i][j]
    if e['site']=='parameterized':
     a.extend([(-d/u[i])*C,-1.,(-u[j]/d)*(1/C),-1.])
     b.extend([(-square(d)/u[i])*square(C)+(-d)*C,(-u[j])+(-d)*C])
    else:
     w=d*C;inv=1/u[i]
     a.extend([inv*(-w),-1.,u[j]*(-1/w),-1.])
     b.extend([(-square(w))*inv+(-w),(-1.)*u[j]+(-w)])
   b+=u+[0.]*n;a +=[1.]*n+[-1.]*n
   db=[k for k,(x,y) in enumerate(zip(b,e['b'])) if x!=y];da=[k for k,(x,y) in enumerate(zip(a,e['A_data'])) if x!=y]
   rows.append(dict(number=e['number'],site=e['site'],mode=mode,rhs_differences=db,matrix_differences=da))
 out['reconstruction'][interface]=rows
# Check already audited cross-interface/repeat histories; exclude time only.
raw=[load(W/f'phase07g/runs/{k}/child/raw.json') for k in range(8)]
clean=lambda d:{k:([clean(x) for x in v] if k=='history' else clean(v) if k=='info' else v) for k,v in d.items() if k not in ['seconds','solve_time']}
assert all(clean(raw[k])==clean(raw[0]) for k in [2,5,7])
assert all(clean(raw[k])==clean(raw[1]) for k in [3,4,6])
hist=[raw[k]['history'] for k in [0,1]]
first=next(i for i,(a,b) in enumerate(zip(*hist)) if clean(a)!=clean(b))
out['convergence']=dict(histories_exact_across_interfaces_and_repeats=True,first_differing_callback=first,first_callback_values=[hist[0][first],hist[1][first]],multiply=raw[0],power=raw[1],warning='Final callback precedes internal termination/postprocessing; exact unobserved termination branch is not inferred.')
out['source_files']={str(p):sha(p) for p in list(traces.values())+[W/f'phase07g/runs/{k}/child/raw.json' for k in range(8)]}
out['solver_calls']=0;write(root/'arithmetic.json',out)
print(out['origin'])
for k,rows in out['reconstruction'].items():
 print(k,{mode:sum(bool(r['rhs_differences'] or r['matrix_differences']) for r in rows if r['mode']==mode) for mode in ['multiply','power']})
