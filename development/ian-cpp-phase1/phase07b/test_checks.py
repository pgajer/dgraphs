"""Small external-check falsification and dual-map checks; no solver calls."""
import sys
from pathlib import Path
import numpy as np
from scipy import sparse
from common import pack,scalar_check,write
out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=False)
e=dict(**pack(sparse.csr_matrix([[-1.],[1.]])),b=[-1.,2.],c=[1.],active=[1],upper=[2.])
good=scalar_check(e,[1.],[1.,0.],1.,'Solved')
checks=dict(valid_solution=good['accepted'],constraint_error_rejected=not scalar_check(e,[.9],[1.,0.],.9,'Solved')['accepted'],
    bad_dual_rejected=not scalar_check(e,[1.],[0.,0.],1.,'Solved')['accepted'],
    negative_dual_rejected=not scalar_check(e,[1.],[-1.,0.],1.,'Solved')['accepted'],
    wrong_objective_rejected=not scalar_check(e,[1.],[1.,0.],2.,'Solved')['accepted'],
    almost_solved_rejected=not scalar_check(e,[1.],[1.,0.],1.,'AlmostSolved')['accepted'],
    row_scaled_dual_map=scalar_check(e,[1.],np.array([.25,.5])*[4.,0.],1.,'Solved')['accepted'])
write(out/'results.json',dict(checks=checks,passed=all(checks.values()),solver_calls=0))
assert all(checks.values());print(checks)
