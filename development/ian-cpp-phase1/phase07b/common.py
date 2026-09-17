"""Serialization and independent scalar diagnostics; no optimization policy."""
import hashlib
import json
import math
from pathlib import Path
import numpy as np
from scipy import sparse

def sha(p):
    with Path(p).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def clean(v):
    if isinstance(v,np.ndarray):return clean(v.tolist())
    if isinstance(v,np.generic):return clean(v.item())
    if isinstance(v,float) and not math.isfinite(v):return str(v)
    if isinstance(v,dict):return {k:clean(x) for k,x in v.items()}
    if isinstance(v,(list,tuple)):return [clean(x) for x in v]
    return v
def write(p,v):Path(p).write_text(json.dumps(clean(v),allow_nan=False)+'\n')
def load(p):return json.loads(Path(p).read_text())
def events(p):
    with Path(p).open() as f:
        for line in f:yield json.loads(line)
def matrix(e):return sparse.csr_matrix((e['A_data'],e['A_indices'],e['A_indptr']),shape=e['A_shape'])
def pack(A):
    A=A.tocsr();return dict(A_data=A.data,A_indices=A.indices,A_indptr=A.indptr,A_shape=A.shape)
def product(A,x):
    A=A.tocsr()
    return np.array([math.fsum(float(v)*float(x[j]) for v,j in zip(A.data[A.indptr[i]:A.indptr[i+1]],A.indices[A.indptr[i]:A.indptr[i+1]])) for i in range(A.shape[0])])
def norm(x):return math.sqrt(math.fsum(float(v)*float(v) for v in x))
def scalar_check(e,x,z,obj,status):
    A=matrix(e);b=np.array(e['b']);c=np.array(e['c']);x=np.array(x);z=np.array(z)
    finite=all(np.isfinite(v).all() for v in [A.data,b,c,x,z]) and math.isfinite(obj)
    ax=product(A,x);den=np.maximum(1.,np.maximum(abs(b),product(abs(A),abs(x))))
    residual=np.maximum(ax-b,0.);normalized=residual/den;i=int(np.argmax(normalized))
    primal=math.fsum(float(a)*float(v) for a,v in zip(c,x));dual=-math.fsum(float(a)*float(v) for a,v in zip(b,z))
    station=max(abs(c+product(A.T,z)));negative=max(0.,float(np.max(-z)))
    gap=abs(primal-dual)/max(1.,abs(primal),abs(dual));error=abs(primal-obj)/max(1.,abs(primal),abs(obj))
    active=np.asarray(e['active'],dtype=bool)
    accepted=finite and status=='Solved' and max(normalized)<=1e-7 and np.all(x[active]>0) and max(station,negative,gap,error)<=1e-7
    row=A.getrow(i)
    from decimal import Decimal,localcontext
    with localcontext() as context:
        context.prec=80
        terms=[Decimal.from_float(float(v))*Decimal.from_float(float(x[j])) for v,j in zip(row.data,row.indices)]
        bd=Decimal.from_float(float(b[i]));dd=max(Decimal(1),abs(bd),sum(map(abs,terms),Decimal(0)))
        exact=max(Decimal(0),sum(terms,Decimal(0))-bd)/dd
    return dict(accepted=bool(accepted),finite=bool(finite),normalized_primal=float(max(normalized)),absolute_primal=float(max(residual)),
        objective=primal,dual_objective=dual,objective_error=error,dual_stationarity=float(station),dual_negative=negative,dual_relative_gap=gap,
        worst_row=i,worst_row_columns=row.indices,worst_row_coefficients=row.data,worst_row_x=x[row.indices],worst_row_rhs=b[i],
        worst_row_lhs=ax[i],worst_row_denominator=den[i],worst_row_decimal_normalized=str(exact))
