"""Exact rational feasibility of the saved upper-bound vector; no solver calls."""
import sys
from fractions import Fraction
from pathlib import Path
from common import load,write,matrix

fixtures=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
results=[]
for name,item in load(fixtures/'manifest.json')['cases'].items():
    e=load(item.get('saved',item['path']));A=matrix(e)
    x=[Fraction.from_float(float(v)) for v in e['upper']]
    largest=None;worst=None;strict=0
    for i,b in enumerate(e['b']):
        r=sum((Fraction.from_float(float(A.data[k]))*x[A.indices[k]] for k in range(A.indptr[i],A.indptr[i+1])),Fraction(0))-Fraction.from_float(float(b))
        if largest is None or r>largest:largest=r;worst=i
        strict+=r<0
    ok=largest<=0 and all(v>0 for v,a in zip(x,e['active']) if a)
    results.append(dict(case=name,feasible=ok,maximum_violation_numerator=largest.numerator,
        maximum_violation_denominator=largest.denominator,worst_row=worst,strict_inequalities=strict,total_inequalities=len(e['b']),
        construction='x=upper; Fraction.from_float for every supplied binary64 coefficient, bound and scale'))
    assert ok
write(out/'results.json',dict(cases=results,all_feasible=True,solver_calls=0,
    scope='Original projected LPs; no assertion that historical auxiliary/slack variables equal this witness.'))
print('All five represented LPs have an exactly feasible upper-bound witness.')
