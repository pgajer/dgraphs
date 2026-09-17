"""Private fixture format and solver-independent acceptance (no solver imports)."""
import hashlib
import json
import math
import struct
from pathlib import Path
import numpy as np
from scipy import sparse

MAGIC = b'IANLP001'
OPTIONS = dict(tol_gap_abs=1e-9, tol_gap_rel=1e-9, tol_feas=1e-9,
               max_iter=300, max_threads=1, direct_solve_method='qdldl')

def sha(p):
    h=hashlib.sha256()
    with open(p,'rb') as f:
        for block in iter(lambda:f.read(1024*1024),b''): h.update(block)
    return h.hexdigest()

def write_json(p,x):
    Path(p).write_text(json.dumps(x,indent=2,allow_nan=False)+'\n')

def save_lp(p,d):
    m,n=map(int,d['A_shape']); nnz=len(d['A_data'])
    with open(p,'wb') as f:
        f.write(MAGIC+struct.pack('<QQQ',m,n,nnz))
        for k,t in [('A_data','<f8'),('A_indices','<u8'),('A_indptr','<u8'),
                    ('b','<f8'),('c','<f8'),('upper','<f8'),('active','u1')]:
            f.write(np.asarray(d[k],dtype=t).tobytes())

def load_lp(p):
    with open(p,'rb') as f:
        if f.read(8)!=MAGIC: raise ValueError('magic')
        m,n,z=struct.unpack('<QQQ',f.read(24))
        d={'A_shape':np.array([m,n])}
        for k,t,count in [('A_data','<f8',z),('A_indices','<u8',z),('A_indptr','<u8',m+1),
                          ('b','<f8',m),('c','<f8',n),('upper','<f8',n),('active','u1',n)]:
            a=np.fromfile(f,dtype=t,count=count)
            if len(a)!=count: raise ValueError('truncated')
            d[k]=a
        if f.read(1): raise ValueError('trailing bytes')
    d['active']=d['active'].astype(bool)
    d['A']=sparse.csr_matrix((d['A_data'],d['A_indices'].astype(np.int64),
                            d['A_indptr'].astype(np.int64)),shape=(m,n))
    return d

def validate(d,s,objective,status):
    errors=[]
    if status!='optimal': errors.append('solver_status')
    if s is None or objective is None:
        return dict(accepted=False,problems=errors+['nonfinite_or_missing_solution'])
    s=np.asarray(s)
    if s.shape!=d['c'].shape:
        return dict(accepted=False,problems=errors+['solution_shape'])
    if not np.isfinite(s).all() or not np.isfinite(objective):
        return dict(accepted=False,problems=errors+['nonfinite_or_missing_solution'])
    A,b,c,upper,active=[d[k] for k in ('A','b','c','upper','active')]
    residual=np.maximum(0,A@s-b)
    normalized=residual/np.maximum(1,np.maximum(abs(b),abs(A)@abs(s)))
    obj=math.fsum(float(a)*float(v) for a,v in zip(c,s))
    err=abs(obj-objective)/max(1,abs(obj),abs(objective))
    if not np.isfinite(residual).all() or not np.isfinite(normalized).all() or not math.isfinite(obj):
        errors.append('nonfinite_recomputed_diagnostics')
    if normalized.max(initial=0)>1e-7: errors.append('constraint_residual')
    if err>1e-7: errors.append('objective_mismatch')
    if np.any(s[active]<=0): errors.append('nonpositive_active_scale')
    return dict(accepted=not errors,problems=errors,recomputed_objective=obj,
        objective_relative_error=err,max_absolute_violation=float(residual.max(initial=0)),
        max_normalized_violation=float(normalized.max(initial=0)),
        lower_bound_violation=float(np.maximum(-s,0).max(initial=0)),
        upper_bound_violation=float(np.maximum(s-upper,0).max(initial=0)),
        min_active_scale=float(s[active].min()) if np.any(active) else None)

def dual_diagnostics(d,s,z):
    if z is None or np.shape(z)!=np.shape(d['b']) or not np.isfinite(z).all():
        return dict(available=False)
    primal=float(d['c']@s); dual=float(-d['b']@z)
    return dict(available=True,primal_objective=primal,dual_objective=dual,
        absolute_gap=abs(primal-dual),relative_gap=abs(primal-dual)/max(1,abs(primal),abs(dual)),
        stationarity_max=float(abs(d['c']+d['A'].T@z).max()),
        dual_negative_max=float(np.maximum(-z,0).max(initial=0)))
