"""Deterministic selection, provenance, schema/bounds checks, exact export."""
import sys,json,shutil,subprocess
from pathlib import Path
import numpy as np
from scipy import sparse
from scipy.sparse.csgraph import connected_components
from common import sha,save_lp,load_lp,write_json,validate
root=Path(sys.argv[1]); out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
rules=[('control_initial','controls/uniform_arc_ian_4.5','initial',False),
 ('control_pruning','controls/gap_observations_ian_4.5','post_prune',False),
 ('control_final','controls/gap_observations_ian_4.5','final_affinity_retuning',True),
 ('combined_early','combined_full_ian_4.5','post_prune',False),
 ('combined_late','combined_full_ian_4.5','post_prune',True),
 ('combined_final','combined_full_ian_4.5','final_affinity_retuning',True)]
manifest=[]
for label,folder,phase,last in rules:
    base=root/folder;trace=base/'trace.jsonl'
    events=[json.loads(l) for l in trace.read_text().splitlines()]
    matches=sorted((e for e in events if e['event']=='solve' and e['phase']==phase),key=lambda e:(e['iteration'],e['number']))
    e=matches[-1 if last else 0]; source=base/e['artifact']; dest=out/label; dest.mkdir()
    with np.load(source,allow_pickle=False) as z: d={k:z[k].copy() for k in z.files}
    expected={'scales','upper','active','c','b','A_data','A_indices','A_indptr','A_shape','residual','normalized'}
    assert set(d)==expected
    m,n=map(int,d['A_shape']);assert m>2*n
    assert all(np.isfinite(a).all() for a in d.values())
    assert d['scales'].shape==d['upper'].shape==d['active'].shape==d['c'].shape==(n,)
    assert d['active'].dtype==bool and np.array_equal(d['active'],d['upper']>0)
    assert np.all(d['c']==1)
    A=sparse.csr_matrix((d['A_data'],d['A_indices'],d['A_indptr']),shape=(m,n))
    assert A.has_canonical_format and len(d['b'])==m
    assert (A[-2*n:-n]!=sparse.eye(n)).nnz==0 and (A[-n:]!=-sparse.eye(n)).nnz==0
    assert np.array_equal(d['b'][-2*n:-n],d['upper']) and np.all(d['b'][-n:]==0)
    save_lp(dest/'problem.bin',d); loaded=load_lp(dest/'problem.bin')
    for k in loaded:
        if k!='A': assert np.array_equal(loaded[k],d[k]),k
    save_lp(dest/'roundtrip.bin',loaded); assert sha(dest/'roundtrip.bin')==sha(dest/'problem.bin')
    (dest/'roundtrip.bin').unlink()
    check=validate(loaded,d['scales'],e['objective'],e['status']);assert check['accepted']
    residual=np.maximum(0,A@d['scales']-d['b'])
    norm=residual/np.maximum(1,np.maximum(abs(d['b']),abs(A)@abs(d['scales'])))
    assert np.allclose(residual,d['residual'],rtol=1e-12,atol=1e-15)
    assert np.allclose(norm,d['normalized'],rtol=1e-12,atol=1e-15)
    shutil.copyfile(source,dest/'historical.npz');shutil.copyfile(base/'settings.json',dest/'settings.json')
    write_json(dest/'event.json',e)
    manifest.append(dict(label=label,source=str(source),trace=str(trace),phase=phase,
        iteration=e['iteration'],number=e['number'],site=e['site'],rows=m,variables=n,nnz=A.nnz,
        isolates=int((~d['active']).sum()),source_sha256=sha(source),trace_sha256=sha(trace),
        binary_sha256=sha(dest/'problem.bin'),settings_sha256=sha(dest/'settings.json'),
        schema={k:dict(shape=list(a.shape),dtype=str(a.dtype)) for k,a in d.items()},
        historical_validation=check,roundtrip_exact=True))
write_json(out/'manifest.json',dict(source_revision=revision,rule_source='PLAN.md',cases=manifest))
# Reproduce historical totals and graph structure from primary records.
base=root/'combined_full_ian_4.5';events=[json.loads(l) for l in (base/'trace.jsonl').read_text().splitlines()]
solves=[e for e in events if e['event']=='solve'];edges=np.load(base/'last_valid_graph.npz')['edges'];n=manifest[-1]['variables']
graph=sparse.csr_matrix((np.ones(len(edges)*2),(np.r_[edges[:,0],edges[:,1]],np.r_[edges[:,1],edges[:,0]])),shape=(n,n))
cc,labels=connected_components(graph);sizes=np.bincount(labels)
resources=json.loads((base/'resource-summary.json').read_text());phases=json.loads((base/'phase-status.json').read_text())
validation=json.loads((root/'input-validation.json').read_text())
files=['trace.jsonl','last_valid_graph.npz','resource-summary.json','phase-status.json','attempt-status.json','settings.json']
write_json(out/'historical-reconstruction.json',dict(source_revision=revision,
    solves=len(solves),accepted_solves=sum(e['accepted'] for e in solves),
    solver_seconds=sum(e['solver_time'] for e in solves),wrapper_seconds=sum(e['wall_seconds'] for e in solves),
    graph_stop=[e for e in events if e['event']=='graph_stop'],final_retuning=[e for e in events if e['event']=='retune_stop' and e['phase']=='final_affinity_retuning'],
    native_edges=len(edges),components=int(cc),component_sizes=sorted(map(int,sizes),reverse=True),
    isolates=int((np.diff(graph.indptr)==0).sum()),input_validation=validation,
    graph_saved=(base/'graph.npz').exists(),affinity_saved=(base/'affinity.npz').exists(),
    resource_summary=resources,phase_status=phases,evidence_hashes={k:sha(base/k) for k in files}))
print(json.dumps([{k:x[k] for k in ('label','number','iteration','rows','variables','nnz')} for x in manifest],indent=2))
