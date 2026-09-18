from support import *
root=Path(sys.argv[1]);ledger=load(root/'ledger.json');rows=[];raws=[];comparisons=[]
for p in ledger['processes']:
    out=root/'runs'/str(p['index'])/'child';f=root/'fixtures'/p['input'];e=load(f/'original.json');r=load(out/'raw.json');raws.append(r);alpha=load(f/'origin.json')['alpha']
    assert all(sha(out/(k+'.bin'))==v for k,v in load(f/'arrays.json')['arrays'].items())
    cert=None;sign_wrong=None
    if r['x'] is not None and r['marginals'] is not None:
        x=alpha*np.array(r['x']);z=-np.array(r['marginals']);cert=scalar_check(e,x,z,alpha*r['objective'],'Solved');sign_wrong=scalar_check(e,x,-z,alpha*r['objective'],'Solved')['dual_stationarity']
        for source in ['native','python']:
            saved=load(root/'fixtures'/source/'original.json');y=np.array(saved['scales']);dif=abs(x-y);allowed=1e-7+1e-7*np.maximum(abs(x),abs(y))
            comparisons.append(dict(run=p['index'],saved_clarabel_input=source,scale_pass=bool(np.all(dif<=allowed)),failed_coordinates=int(np.sum(dif>allowed)),maximum_difference=float(max(dif)),objective_difference=float(cert['objective']-saved['objective'])))
    rows.append(dict(index=p['index'],input=p['input'],solver_success=r['success'],status=r['status'],iterations=r['iterations'],certificate=cert,wrong_dual_sign_stationarity=sign_wrong,diagnostic_certified=bool(r['success'] and cert and cert['accepted'])))
repeats={}
for a,b in [(0,2),(1,3)]:
    if len(raws)>b:repeats[str(a)]=all(raws[a][k]==raws[b][k] for k in raws[a] if k!='seconds')
cross=None
if len(raws)>=2 and all(r['x'] is not None for r in raws[:2]):
    alpha=load(root/'fixtures/native/origin.json')['alpha'];x=alpha*np.array(raws[0]['x']);y=alpha*np.array(raws[1]['x']);d=abs(x-y);limit=1e-7+1e-7*np.maximum(abs(x),abs(y));cross=dict(exact=x.tolist()==y.tolist(),scale_pass=bool(np.all(d<=limit)),failed_coordinates=int(np.sum(d>limit)),maximum_difference=float(max(d)),dual_exact=raws[0]['marginals']==raws[1]['marginals'])
write(root/'results.json',dict(complete=len(rows)==4 and not ledger['gated'] and all(p['exit_code']==0 and p['reason'] is None for p in ledger['processes']),reserved_invocations=ledger['reserved_invocations'],physical_attempts=sum(p['optimizer_calls'] for p in ledger['processes']),runs=rows,repeat_exact=repeats,cross_input=cross,clarabel_comparisons=comparisons,wall_seconds=sum(p['wall_seconds'] for p in ledger['processes']),peak_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in ledger['processes']),resource_limits_hit=[p['reason'] for p in ledger['processes'] if p['reason']],policy_changed=False,scale_gate=False))
print(load(root/'results.json'))
