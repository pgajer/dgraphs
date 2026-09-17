"""Reconstruct diagnostic results from saved inputs/returns without solving."""
import math
import sys
from decimal import Decimal
from pathlib import Path
import numpy as np
from scipy import sparse
from common import load,write,sha,matrix,product,norm,scalar_check

root=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
ledger=load(root/'replays-v1/ledger.json');fixtures=load(root/'fixtures-v1/manifest.json')
assert ledger['complete'] and not ledger['gated'] and len(ledger['runs'])==33
rows=[];formula=[];rejected=[];histories={}
for item in ledger['runs']:
    assert item['exit_code']==0 and item['reason'] is None
    case,condition=item['case'],item['condition'];folder=root/'replays-v1'/case/condition/'child'
    result=load(folder/'result.json');raw=load(folder/'raw-solution.json');problem=load(folder/'problem.json')
    f=fixtures['cases'][case];e=load(f.get('saved',f['path']));original=matrix(e)
    A=matrix(problem);b=np.array(problem['b']);c=np.array(problem['c']);x=np.array(raw['x']);z=np.array(raw['z']);s=np.array(raw['s'])
    n=len(e['c']);m=len(e['b']);factor=np.array(problem['row_factor'])
    if case!='historical_first':
        expected=np.ones(m) if condition!='row_normalized' else 1/np.maximum(1,np.maximum(abs(np.asarray(e['b'])),abs(original).max(axis=1).toarray().ravel()))
        assert np.array_equal(expected,factor)
        assert (A-sparse.diags(factor)@original).nnz==0 and np.array_equal(b,factor*np.array(e['b']))
    check=scalar_check(e,x[:n],(factor*z)[:m],raw['objective'],raw['status'])
    assert check['accepted']==result['external']['accepted']
    for key in ['normalized_primal','dual_stationarity','dual_relative_gap','objective_error']:
        assert check[key]==result['external'][key]
    if condition=='baseline':assert all(result['baseline_exact'].values())
    r=product(A,x)+s-b;dual=c+product(A.T,z)
    rp=norm(r)/max(1.,max(abs(b))+norm(x)+norm(s))
    rd=norm(dual)/max(1.,max(abs(c))+norm(x)+norm(z))
    dp=abs(rp-result['backend']['res_primal']);dd=abs(rd-result['backend']['res_dual'])
    # Reconstruction uses returned unscaled floating-point vectors. This diagnostic
    # absolute allowance is not a solver/IAN acceptance tolerance.
    assert dp<5e-14 and dd<5e-14
    formula.append(dict(case=case,condition=condition,primal_error=dp,dual_error=dd))
    baseline_x=np.array(e['scales']);limit=1e-7+1e-7*np.maximum(abs(baseline_x),abs(x[:n]));ratios=abs(x[:n]-baseline_x)/limit
    hist=load(root/'replays-v1'/case/'baseline/child/result.json')['iteration_history']
    tol=1e-12 if condition=='all12' else 1e-11
    rows.append(dict(case=case,condition=condition,status=raw['status'],iterations=raw['iterations'],accepted=check['accepted'],
        normalized_primal=check['normalized_primal'],dual_stationarity=check['dual_stationarity'],dual_gap=check['dual_relative_gap'],
        backend_primal=result['backend']['res_primal'],backend_dual=result['backend']['res_dual'],backend_gap=result['backend']['gap_rel'],
        scale_difference_max=result['scale_difference_max'],scale_limit_exceedances=int(sum(ratios>1)),maximum_scale_limit_ratio=float(max(ratios)),
        objective_difference=result['objective_difference'],solve_seconds=result['wall_seconds']))
    if not check['accepted']:rejected.append(dict(case=case,condition=condition,check=check))
    if case=='historical_first':
        derived=b-product(A,x)
        cone=dict(returned_slack_violation=max(0.,norm(s[m+1:])-s[m]),
            derived_slack_violation=max(0.,norm(derived[m+1:])-derived[m]))
        histories[condition]=dict(**result['historical'],**cone,
            auxiliary_share_of_worst_violation=result['historical']['worst_row_induced_violation']/result['historical']['worst_row_projected_inequality'])

same_vectors=[]
for case in fixtures['cases']:
    ref=load(root/'replays-v1'/case/'feas11/child/raw-solution.json')
    equality=all(all(load(root/'replays-v1'/case/condition/'child/raw-solution.json')[key]==ref[key] for key in ['x','z','s','iterations']) for condition in ['gap11','all11'])
    same_vectors.append(dict(case=case,feas11_gap11_all11_exact=equality));assert equality

case='helix500_rejected';e=load(fixtures['cases'][case]['path']);v=load(root/'replays-v1'/case/'baseline/child/result.json')
s=np.array(v['slack']);A=matrix(e);n=len(e['c']);edge_rows=len(e['b'])-2*n;sq=math.fsum(float(a)*float(a) for a in s)
largest=np.argsort(s*s)[::-1][:10]
attribution=dict(denominators=v['reconstructed_backend'],external=v['external'],
    second_edge_row_slack_squared_fraction=math.fsum(float(a)*float(a) for a in s[1:edge_rows:2])/sq,
    first_edge_row_slack_squared_fraction=math.fsum(float(a)*float(a) for a in s[:edge_rows:2])/sq,
    bound_slack_squared_fraction=math.fsum(float(a)*float(a) for a in s[edge_rows:])/sq,
    top_slacks=[dict(row=int(i),slack=s[i],columns=A.getrow(i).indices,coefficients=A.getrow(i).data) for i in largest],
    backend_full_accuracy_criteria_met=bool(v['backend']['res_primal']<1e-9 and v['backend']['res_dual']<1e-9 and
        (v['backend']['gap_rel']<1e-9 or v['backend']['gap_abs']<1e-9) and v['backend']['ktratio']<=1))
assert attribution['backend_full_accuracy_criteria_met'] and Decimal(v['external']['worst_row_decimal_normalized'])>Decimal('1e-7')
warnings=[]
for p in (root/'replays-v1').glob('*/*/stderr.log'):
    if p.stat().st_size:warnings.append(dict(path=str(p),text=p.read_text()))
summary=dict(complete=True,solver_calls=33,accepted=sum(r['accepted'] for r in rows),rejected=rejected,rows=rows,
    formula_reconstruction=formula,shared_failure=attribution,historical_auxiliary=histories,tight_condition_equivalence=same_vectors,
    baseline_reproductions=5,warning_logs=warnings,ledger_sha256=sha(root/'replays-v1/ledger.json'),
    peak_sampled_child_rss=max(i['sampled_tree_peak_rss_bytes'] for i in ledger['runs']),
    execution_seconds=ledger['elapsed_seconds'],policy_adopted=False,full_engine_runs=0,expansion_authorized=False)
assert summary['accepted']==29 and len(rejected)==4
write(out/'results.json',summary)
print(dict(solves=33,accepted=summary['accepted'],rejected=len(rejected),baselines=5,max_formula_error=max(max(x['primal_error'],x['dual_error']) for x in formula)))
