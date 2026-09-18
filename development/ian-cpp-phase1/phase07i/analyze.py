from support import *
from exact import *
root=Path(sys.argv[1]);ledger=load(root/'ledger.json');e=load(root/'original.json');base=load(root/'bounds.json');q=list(map(decode,base['q']));L=decode(base['L']);U=decode(base['U']);A=rows(e);b=vector(e['b']);c=vector(e['c']);u=vector(e['upper']);z0=-np.array(load(root/'saved-highs.json')['marginals']);records=[];endpoints={};out=root/'certificates';out.mkdir(exist_ok=False)
for p in ledger['processes']:
    folder=root/'runs'/str(p['index'])/'child';case=load(root/'fixtures'/p['case']/'case.json');r=load(folder/'raw.json');T=F(case['T']);meta=load(root/'fixtures'/p['case']/'arrays.json')
    assert load(folder/'arrays.json')==meta and all(sha(folder/(k+'.bin'))==v for k,v in meta['arrays'].items())
    record=dict(case=p['case'],index=p['index'],solver_success=r['success'],status=r['status'],iterations=r['iterations'],endpoint_available=False)
    if r['x'] is None or r['marginals'] is None or not np.isfinite(r['x']).all() or not np.isfinite(r['marginals']).all():records.append(record);continue
    x=vector(r['x']);zraw=vector([-v for v in r['marginals']]);z=[max(F(0),v) for v in zraw];g=[F(0)]*len(c);g[717]=F(case['sign']);AA=A+[list(enumerate(c))];bb=b+[T];assert len(z)==len(bb)
    raw_obj=objective(c,x);raw_band=raw_obj<=T;raw_feasible=feasible(A,b,x,u);repaired,repair_record=repair(AA,bb,x,u,q);B,dualinfo=lower_bound(AA,bb,g,u,z);assert B<=objective(g,repaired)
    original_numeric=scalar_check(e,r['x'],z0,float(raw_obj),'Solved')
    aug=sparse.vstack([matrix(e),sparse.csr_matrix([e['c']])],format='csr');aug_e=dict(**pack(aug),b=e['b']+[case['T']],c=list(map(float,g)),active=e['active']);aug_numeric=scalar_check(aug_e,r['x'],list(map(float,zraw)),r['objective'],'Solved')
    record.update(endpoint_available=True,raw_original_numeric=original_numeric,raw_augmented_numeric=aug_numeric,raw_exact_original_feasible=raw_feasible,raw_exact_band_pass=raw_band,raw_exact_augmented_feasible=raw_feasible and raw_band,raw_band_excess=float(max(F(0),raw_obj-T)),raw_band_excess_exact=encode(max(F(0),raw_obj-T)),repair=repair_record,repaired_original_objective=float(objective(c,repaired)),repaired_band_margin=float(T-objective(c,repaired)),repaired_above_L=float(objective(c,repaired)-L),repaired_coordinates={str(j):float(repaired[j]) for j in [229,230,717]},coordinate_optimality_gap=float(objective(g,repaired)-B),dual_box_correction=dualinfo,negative_multipliers_clipped=sum(v<0 for v in zraw),dual_band_multiplier=float(z[-1]),minimum_objective_lower_bound=float(B))
    witness=dict(case=case,raw_sha256=sha(folder/'raw.json'),repaired_point=[encode(v) for v in repaired],exact_lower_bound=encode(B),dual=[encode(v) for v in z],repair=repair_record,original_objective=encode(objective(c,repaired)),coordinate_optimality_gap=encode(objective(g,repaired)-B),dual_details=dualinfo)
    write(out/(p['case']+'.json'),witness);endpoints[p['case']]=(repaired,B);records.append(record)
ranges=[]
for band in load(root/'schedule.json')['bands']:
    k=str(band['index']);lo=endpoints.get(k+'-min');hi=endpoints.get(k+'-max')
    if lo is None or hi is None:ranges.append(dict(band=band,complete=False));continue
    values=[q[717],lo[0][717],hi[0][717]];attmin=min(values);attmax=max(values);minlow=max(F(0),lo[1]);maxup=min(u[717],-hi[1]);assert minlow<=attmin<=attmax<=maxup
    data=dict(minimum_lower=minlow,minimum_upper=attmin,maximum_lower=attmax,maximum_upper=maxup,attained_span=attmax-attmin,span_upper_bound=maxup-minlow)
    ranges.append(dict(band=band,complete=True,**{key:float(v) for key,v in data.items()},exact={key:encode(v) for key,v in data.items()}))
write(root/'results.json',dict(complete=len(records)==6 and not ledger['gated'] and all(p['exit_code']==0 and p['reason'] is None for p in ledger['processes']),physical_attempts=sum(p['optimizer_calls'] for p in ledger['processes']),endpoints=records,ranges=ranges,strict_band_violation_allowance=0,wall_seconds=sum(p['wall_seconds'] for p in ledger['processes']),peak_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in ledger['processes']),resource_limits_hit=[p['reason'] for p in ledger['processes'] if p['reason']],policy_changed=False,scale_gate=False))
print(dict(endpoints=[{k:v for k,v in r.items() if k in ['case','solver_success','iterations','raw_exact_band_pass','raw_exact_original_feasible','raw_band_excess','repair','repaired_coordinates','coordinate_optimality_gap']} for r in records],ranges=ranges))
