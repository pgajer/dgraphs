"""Adversarial acceptance controls; no optimizations or extra benchmark cases."""
import json,sys
import numpy as np
from scipy import sparse
from common import validate
A=sparse.csr_matrix([[-1.,0.],[1.,0.],[0.,1.],[-1.,0.],[0.,-1.]])
d=dict(A=A,b=np.array([-.5,1.,0.,0.,0.]),c=np.ones(2),upper=np.array([1.,0.]),active=np.array([True,False]))
controls=[('valid',[.5,0],.5,'optimal',True),('missing',None,.5,'optimal',False),
 ('nonfinite',[np.nan,0],.5,'optimal',False),('infeasible',[.1,0],.1,'optimal',False),
 ('nonfinite_objective',[.5,0],np.inf,'optimal',False),('missing_objective',[.5,0],None,'optimal',False),
 ('upper_bound',[2.,0],2.,'optimal',False),('isolate_nonzero',[.5,.1],.6,'optimal',False),
 ('wrong_objective',[.5,0],1.,'optimal',False),('wrong_status',[.5,0],.5,'optimal_inaccurate',False),
 ('wrong_shape',[.5],.5,'optimal',False),('nonpositive_active',[0.,0],0.,'optimal',False)]
results=[]
for name,x,obj,status,expected in controls:
    result=validate(d,x,obj,status);assert result['accepted']==expected,name
    results.append(dict(name=name,expected=expected,result=result))
print(json.dumps(results,indent=2,allow_nan=False))
