"""Combine separately labeled, exactly feasible saved witnesses; zero new solves."""
from support import *
from exact import *
root=Path(sys.argv[1]);e=load(root/'original.json');A=rows(e);b=vector(e['b']);u=vector(e['upper']);c=vector(e['c']);bounds=load(root/'bounds.json');q=list(map(decode,bounds['q']));L=decode(bounds['L']);saved=load(root/'saved-direction.json');p=list(map(decode,saved['clarabel_feasible_point']));assert feasible(A,b,q,u) and feasible(A,b,p,u)
span=abs(p[717]-q[717]);records=[]
for row in load(root/'results.json')['ranges']:
    T=F(row['band']['T']);assert objective(c,p)<=T and objective(c,q)<=T
    k=str(row['band']['index']);fresh=[list(map(decode,load(root/'certificates'/(k+'-'+name+'.json'))['repaired_point'])) for name in ['min','max']]
    candidates=[q,p]+fresh;assert all(feasible(A,b,x,u) and objective(c,x)<=T for x in candidates)
    low=min(x[717] for x in candidates);high=max(x[717] for x in candidates);lower=decode(row['exact']['minimum_lower']);upper=decode(row['exact']['maximum_upper']);assert lower<=low<=high<=upper
    values=dict(minimum_lower=lower,minimum_upper=low,maximum_lower=high,maximum_upper=upper,attained_span=high-low,span_upper_bound=upper-lower)
    records.append(dict(band=row['band'],source='Combined exact witnesses from fresh repairs and separately repaired historical returns',**{key:float(v) for key,v in values.items()},exact={key:encode(v) for key,v in values.items()}))
write(root/'saved-span.json',dict(optimizer_calls=0,saved_witness_span=float(span),saved_witness_span_exact=encode(span),highs_objective=encode(objective(c,q)),clarabel_objective=encode(objective(c,p)),clarabel_above_L=float(objective(c,p)-L),clarabel_above_L_exact=encode(objective(c,p)-L),both_saved_witnesses_exactly_feasible=True,combined_ranges=records))
print(dict(saved_span=float(span),clarabel_above_L=float(objective(c,p)-L),combined=[{k:v for k,v in r.items() if k not in ['band','exact']} for r in records]))
