"""One explicit HiGHS dual-simplex call, observing the backend without altering it."""
import time,warnings
from scipy.optimize import linprog
from scipy.optimize._highspy import _core as h
from support import *
f,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=False);A,b,c=read_arrays(f);origin=load(f/'origin.json');original_class=h._Highs;calls=0

def attrs(obj):
    d={}
    for k in dir(obj):
        if k.startswith('_'):continue
        v=getattr(obj,k)
        if not callable(v):d[k]=v if isinstance(v,(str,int,float,bool,list)) else str(v)
    return d
class ObservedHighs:
    def __init__(self):self.inner=original_class()
    def __getattr__(self,name):return getattr(self.inner,name)
    def run(self):
        global calls
        assert calls==0;calls+=1
        lp=self.inner.getLp();settings=attrs(self.inner.getOptions());write(out/'settings.json',settings)
        for k,v in load(f.parent.parent/'preflight.json')['options_accepted'].items():assert settings[k]==v,(k,settings[k],v)
        observed=sparse.csc_matrix((lp.a_matrix_.value_,lp.a_matrix_.index_,lp.a_matrix_.start_),shape=(lp.num_row_,lp.num_col_));dump_arrays(out,observed,lp.row_upper_,lp.col_cost_)
        assert load(out/'arrays.json')==load(f/'arrays.json')
        assert np.all(np.isneginf(lp.col_lower_)) and np.all(np.isposinf(lp.col_upper_)) and np.all(np.isneginf(lp.row_lower_))
        write(out/'model.json',dict(version=self.inner.version(),row_lower=lp.row_lower_,col_lower=lp.col_lower_,col_upper=lp.col_upper_,sense=str(lp.sense_),offset=lp.offset_,alpha=origin['alpha'],scipy_method='highs-ds'))
        write(out/'trace.jsonl',dict(event='solve',diagnostic_only=True,state='started',algorithm='highs-ds'))
        status=self.inner.run()
        solution=self.inner.getSolution();basis=self.inner.getBasis()
        write(out/'backend.json',dict(run_status=str(status),model_status=str(self.inner.getModelStatus()),info=attrs(self.inner.getInfo()),solution=attrs(solution),basis=attrs(basis)))
        return status
h._Highs=ObservedHighs
try:
    with warnings.catch_warnings(record=True) as messages:
        warnings.simplefilter('always');start=time.perf_counter();r=linprog(c,A_ub=A,b_ub=b,bounds=(None,None),method='highs-ds',options=OPTIONS);seconds=time.perf_counter()-start
        write(out/'warnings.json',[dict(category=w.category.__name__,message=str(w.message)) for w in messages])
finally:h._Highs=original_class
assert calls==1
write(out/'raw.json',dict(status=r.status,success=r.success,message=r.message,iterations=r.nit,x=r.x,objective=r.fun,slack=r.slack,marginals=r.ineqlin.marginals,lower_marginals=r.lower.marginals,upper_marginals=r.upper.marginals,seconds=seconds,options=OPTIONS))
