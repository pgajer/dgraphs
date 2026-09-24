from support import *
root=Path(sys.argv[1]);ledger=load(root/'ledger.json');results=[];raws=[]
def without_timing(v):
    if isinstance(v,dict):return {k:without_timing(x) for k,x in v.items() if k not in ['seconds','solve_time']}
    if isinstance(v,list):return list(map(without_timing,v))
    return v
for p in ledger['processes']:
    f=root/'fixtures'/p['input'];out=root/'runs'/str(p['index'])/'child';e=load(f/'original.json');r=load(out/'raw.json');raws.append(r);meta=load(f/'arrays.json')
    assert all(sha(out/(k+'.bin'))==v for k,v in meta['arrays'].items());assert load(out/'arrays.json')==meta
    alpha=load(f/'origin.json')['alpha'];x=alpha*np.array(r['x']);obj=alpha*r['objective'];certificate=scalar_check(e,x,r['z'],obj,r['status']);numeric=scalar_check(e,x,r['z'],obj,'Solved')['accepted']
    baseline={k:r[k]==e[v] for k,v in [('status','solver_status'),('iterations','iterations'),('x','backend_primal'),('z','backend_dual'),('s','backend_slack'),('objective','backend_objective'),('r_prim','backend_res_primal'),('r_dual','backend_res_dual')]}
    results.append(dict(index=p['index'],interface=p['interface'],input=p['input'],status=r['status'],iterations=r['iterations'],certificate=certificate,numeric_pass=numeric,own_baseline=baseline if p['interface']==p['input'] else None,arrays_exact=True,history_entries=len(r['history'])))
repeat={str(i):without_timing(raws[i])==without_timing(raws[7-i]) for i in range(4)}
comparisons=[]
for a,b,label in [(0,2,'same native input, different interfaces'),(1,3,'same Python input, different interfaces'),(0,3,'native interface, different inputs'),(2,1,'Python interface, different inputs')]:
    x=np.array(raws[a]['x'])*load(root/'fixtures/native/origin.json')['alpha'];y=np.array(raws[b]['x'])*load(root/'fixtures/python/origin.json')['alpha']
    comparisons.append(dict(label=label,cells=[a,b],raw_exact=without_timing(raws[a])==without_timing(raws[b]),vectors_exact=all(raws[a][k]==raws[b][k] for k in ['x','z','s']),scale_tolerance_pass=bool(np.all(abs(x-y)<=1e-7+1e-7*np.maximum(abs(x),abs(y)))),maximum_scale_difference=float(max(abs(x-y)))))
ns=load(root/'runs/0/child/settings.json');ps=load(root/'runs/1/child/settings.json');shared=set(ns)&set(ps);settings=dict(shared_equal=all(ns[k]==ps[k] for k in shared),differences={k:[ns[k],ps[k]] for k in shared if ns[k]!=ps[k]},native_only={k:ns[k] for k in ns.keys()-ps.keys()},python_only={k:ps[k] for k in ps.keys()-ns.keys()})
write(root/'results.json',dict(complete=ledger['solver_calls']==8 and not ledger['gated'],solver_calls=ledger['solver_calls'],results=results,own_baseline_gate=all(all(r['own_baseline'].values()) for r in results if r['own_baseline'] is not None),repeat_exact=repeat,comparisons=comparisons,settings=settings,wall_seconds=sum(p['wall_seconds'] for p in ledger['processes']),peak_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in ledger['processes']),resource_limits_hit=[p['reason'] for p in ledger['processes'] if p['reason']],policy_changed=False,scale_gate=False))
print(load(root/'results.json'))
