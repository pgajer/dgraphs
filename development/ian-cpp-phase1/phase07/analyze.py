"""Final no-solve census and direct vector checks across the two run batches."""
import itertools
import math
import sys
from pathlib import Path
import numpy as np
from scipy import sparse
from checks import load,write,sha,events,check_lp

root=Path(sys.argv[1]); output=Path(sys.argv[2]); output.mkdir(parents=True,exist_ok=False)
ledger=load(root/'ladder-v2/ledger.json'); assert ledger['complete'] and not ledger['expansion_gate']
total=valid=0; rejections=[]; rows=[]; maxima={}; checkpoints=0; kernel_checks=0
for name,item in ledger['runs'].items():
    child=Path(item['process']['command'][2] if name.endswith('/native') else item['process']['command'][4])
    calls=accepted=0
    for e in events(child/'trace.jsonl'):
        if e['event']!='solve': continue
        c=check_lp(e); total+=1; calls+=1
        ok=c['accepted'] and c['dual_valid']; valid+=ok; accepted+=ok
        if ok:
            for k,v in c.items():
                if type(v) is float: maxima[k]=max(maxima.get(k,0.),v)
        else:
            A=sparse.csr_matrix((e['A_data'],e['A_indices'],e['A_indptr']),shape=e['A_shape']); x=np.asarray(e['scales']);b=np.asarray(e['b'])
            residual=np.maximum(A@x-b,0)/np.maximum(1,np.maximum(abs(b),abs(A)@abs(x)))
            index=int(np.argmax(residual)); row=A.getrow(index)
            lhs=math.fsum(float(v)*float(x[j]) for j,v in zip(row.indices,row.data))
            denominator=max(1.,abs(float(b[index])),math.fsum(abs(float(v)*float(x[j])) for j,v in zip(row.indices,row.data)))
            fsum_residual=max(0.,lhs-float(b[index]))/denominator
            rejections.append(dict(run=name,number=e['number'],C=e['C'],phase=e['phase'],checks=c,
                solver_status=e['status'],worst_row=index,row_columns=row.indices.tolist(),row_coefficients=row.data.tolist(),rhs=float(b[index]),
                independent_fsum_residual=fsum_residual,internal_scale_range=[float(x.min()),float(x.max())]))
    assert calls==item['process']['observed_solves']
    c=item['checks']; checkpoints+=len(c.get('checkpoints',[])); kernel_checks+=len(c['kernels'])
    topology=c.get('topology',[])
    rows.append(dict(name=name,complete=c['complete'],passed=item['passed'],solves=calls,valid_solves=accepted,
        pruning=c['counts'].get('pruned',0),last_graph=topology[-1] if topology else None,
        maximum_edge_components=max((t['edge_components'] for t in topology),default=0),
        wall_seconds=item['process']['wall_seconds'],tree_peak_MiB=item['process']['sampled_tree_peak_rss_bytes']/2**20,
        root_peak_MiB=item['process']['root_peak_rss_bytes']/2**20,output_bytes=item['process']['output_bytes'],
        final_affinity_reconstruction=c['final_affinity_reconstruction'],native_resources=c['native_resources']))

vectors=[]
for name in ['regression_helix_120','helix_500','cloud_500','lobes_500','pressmat_500']:
    a=ledger['runs'][name+'/native']['process']['command'][2]
    b=ledger['runs'][name+'/evaluated']['process']['command'][4]
    solve_a=(e for e in events(Path(a)/'trace.jsonl') if e['event']=='solve')
    solve_b=(e for e in events(Path(b)/'trace.jsonl') if e['event']=='solve')
    fields=['A_shape','A_data','A_indices','A_indptr','b','c','upper','active','scales','dual','status','accepted','iterations']
    n=0; unequal={}
    for i,(x,y) in enumerate(itertools.zip_longest(solve_a,solve_b)):
        n+=1
        for f in fields:
            if x is None or y is None or x.get(f)!=y.get(f): unequal[f]=unequal.get(f,0)+1
    vectors.append(dict(input=name,paired_solves=n,exact_fields=fields,unequal=unequal,passed=not unequal))
    assert not unequal
warnings=[]
for folder in [root/'ladder-v1',root/'ladder-v2']:
    for f in folder.glob('*/*/stderr.log'):
        lines=[l for l in f.read_text().splitlines() if 'Warning' in l or 'warning' in l]
        if lines: warnings.append(dict(path=str(f),lines=lines))
result=dict(study_complete=True,implementation_acceptance='independent review pending',expansion_gate=False,
    total_solver_calls=total,numerically_valid_payloads=valid,rejected_payloads=rejections,
    valid_payload_maxima=maxima,runs=rows,native_evaluated_exact_vectors=vectors,
    checkpoint_count=checkpoints,kernel_check_count=kernel_checks,warning_logs=warnings,
    supervised_seconds=sum(p['wall_seconds'] for p in ledger['processes']),
    diagnostic_seconds=sum(p['wall_seconds'] for p in ledger['processes'] if any(str(c).endswith('/diagnose.py') for c in p['command'])),
    comparisons=ledger['comparisons'],gated=ledger['gated'],ledger_sha256=sha(root/'ladder-v2/ledger.json'))
assert total==1028 and valid==1025 and len(rejections)==3
assert all(r['independent_fsum_residual']>1e-7 for r in rejections)
write(output/'results.json',result)
print(dict(total=total,valid=valid,rejected=len(rejections),checkpoints=checkpoints,kernels=kernel_checks))
