"""Detailed terminal coefficient difference; arithmetic only, zero solver calls."""
import math,sys
from pathlib import Path
from support import *
r=Path(sys.argv[1]);out=Path(sys.argv[2]);assert not out.exists()
a=load(r/'helix_1000-native-terminal-problem.json');b=load(r/'matched-python-terminal-problem.json');rows=[]
for i,(x,y) in enumerate(zip(a['b'],b['b'])):
 if x!=y:
  start,end=a['A_indptr'][i:i+2]
  rows.append(dict(row_zero_based=i,native=x,python=y,native_hex=x.hex(),python_hex=y.hex(),absolute_difference=abs(x-y),ulp_at_native=math.ulp(x),ulp_difference=abs(x-y)/math.ulp(x),frozen_comparison_allowance=1e-12+2e-14*max(abs(x),abs(y)),columns=a['A_indices'][start:end],coefficients=a['A_data'][start:end],native_backend_rhs=a['backend_rhs'][i],python_backend_rhs=b['backend_rhs'][i],backend_difference=abs(a['backend_rhs'][i]-b['backend_rhs'][i])))
assert len(rows)==1 and rows[0]['ulp_difference']==1
write(out,dict(solver_calls=0,native_sha256=sha(r/'helix_1000-native-terminal-problem.json'),python_sha256=sha(r/'matched-python-terminal-problem.json'),rhs_differences=rows,unchanged_fields=[k for k in ['A_data','A_indices','A_indptr','A_shape','c','upper','active','C','solver_units','solver_tolerance'] if a[k]==b[k]],causal_attribution='unresolved; identical-data cross-interface replay not executed'))
print(rows)
