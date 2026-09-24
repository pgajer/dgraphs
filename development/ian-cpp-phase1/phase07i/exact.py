"""Rational certificates for the stored LP; no optimizer imports or calls."""
from fractions import Fraction as F
import math

def encode(v):return [str(v.numerator),str(v.denominator)]
def decode(v):return F(int(v[0]),int(v[1]))
def vector(v):return list(map(F,v))
def dot(a,x):return sum((v*x[j] for j,v in a),F(0))
def objective(c,x):return sum((a*b for a,b in zip(c,x)),F(0))
def rows(e):return [[(e['A_indices'][k],F(e['A_data'][k])) for k in range(e['A_indptr'][i],e['A_indptr'][i+1])] for i in range(len(e['b']))]
def ceil64(target):
    v=float(target)
    if F(v)<target:v=math.nextafter(v,math.inf)
    assert F(v)>=target and F(math.nextafter(v,-math.inf))<target
    return v

def violations(A,b,x):return [dot(a,x)-rhs for a,rhs in zip(A,b)]
def feasible(A,b,x,u):return all(0<=v<=upper for v,upper in zip(x,u)) and all(v<=0 for v in violations(A,b,x))
def repair(A,b,x,u,q):
    assert feasible(A,b,q,u)
    clipped=[max(F(0),min(v,upper)) for v,upper in zip(x,u)]
    r=violations(A,b,clipped);rq=violations(A,b,q);weight=max([F(0)]+[v/(v-w) for v,w in zip(r,rq) if v>0])
    assert 0<=weight<=1
    p=[(1-weight)*v+weight*w for v,w in zip(clipped,q)]
    assert feasible(A,b,p,u)
    return p,dict(weight=encode(weight),weight_float=float(weight),maximum_change=float(max(abs(a-z) for a,z in zip(p,x))),maximum_clip=float(max(abs(a-z) for a,z in zip(clipped,x))),exact_feasible=True)

def lower_bound(A,b,c,u,z):
    assert all(v>=0 for v in z)
    d=c.copy()
    for a,mult in zip(A,z):
        for j,v in a:d[j]+=v*mult
    dual=-objective(b,z);correction=sum((min(F(0),v)*upper for v,upper in zip(d,u)),F(0))
    return dual+correction,dict(dual=encode(dual),box_correction=encode(correction),max_stationarity=float(max(map(abs,d))))
