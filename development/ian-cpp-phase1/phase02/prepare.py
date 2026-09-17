"""Freeze sequence exports and reconstruct final original CVXPY canonical LP; no solve."""
import ast,json,sys,subprocess,shutil,time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
import numpy as np
import scipy as sp
from scipy import sparse
import cvxpy as cp
from common import load_lp,save_lp,sha,write_json
HISTORY=Path('/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry/build/full-combined-hellinger-20260916-175755/combined_full_ian_4.5')
SOURCE=Path('/Users/pgajer/.codex/private/ZB/exp038-full-cohorts/20260916-175755/source/build/source-evidence/ian/ian/ian.py')

def events():return [json.loads(l) for l in (HISTORY/'trace.jsonl').read_text().splitlines()]
def original_functions():
    tree=ast.parse(SOURCE.read_text());names={'getParamConstraint','buildOptimizationProblem'}
    picked=[node for node in tree.body if isinstance(node,ast.FunctionDef) and node.name in names]
    assert {node.name for node in picked}==names
    module=ast.Module(body=picked,type_ignores=[])
    namespace=dict(np=np,cp=cp,sp=sp,time=time)
    exec(compile(module,str(SOURCE),'exec'),namespace)
    return namespace

def reconstruct():
    rows=events();final=[r for r in rows if r['event']=='solve' and r['phase']=='final_affinity_retuning'][-1]
    stop=[r for r in rows if r['event']=='retune_stop' and r['phase']=='final_affinity_retuning'][-1]
    scale=[r['rescaling_factor'] for r in rows if r['event']=='iteration_start' and r['iteration']==final['iteration']][0]
    raw=np.load(HISTORY/final['artifact']);upper=raw['upper'].copy()
    edges=np.load(HISTORY/'last_valid_graph.npz')['edges']
    with np.load(HISTORY.parent/'combined_full_input.npz') as f: distances=f['hellinger'].copy()
    distances*=scale
    weights={(int(i),int(j)):distances[i,j] for i,j in edges}
    degrees=np.bincount(edges.ravel(),minlength=len(upper));rebuilt=np.zeros_like(upper)
    np.maximum.at(rebuilt,edges[:,0],distances[edges[:,0],edges[:,1]])
    np.maximum.at(rebuilt,edges[:,1],distances[edges[:,0],edges[:,1]])
    assert np.array_equal(upper,rebuilt)
    assert np.array_equal(raw['active'],degrees>0)
    f=original_functions();x,objective,constraints,C,Ct=f['buildOptimizationProblem'](weights,upper,'l1')
    C.value=stop['C'];Ct.value=1/C.value
    problem=cp.Problem(cp.Minimize(objective),constraints)
    return problem,dict(final_C=stop['C'],rescaling_factor=scale,upper_exact_from_edges=True,
         active_exact_from_edges=True,edge_order='lexicographic; initial sparse upper-triangle extraction order retained by deletions',
         original_function_names=['getParamConstraint','buildOptimizationProblem'],source_sha256=sha(SOURCE),
         historical_event=final,final_retune_stop=stop),x

def main():
    out=Path(sys.argv[1]);out.mkdir(parents=True,exist_ok=False)
    es=events();solves=[r for r in es if r['event']=='solve'];post=sorted([r for r in solves if r['phase']=='post_prune'],key=lambda r:(r['iteration'],r['number']))[-8:]
    wholefinal=[r for r in solves if r['phase']=='final_affinity_retuning'];final=[r for r in wholefinal if r['site']=='parameterized']
    assert [r['number'] for r in post]==list(range(1860,1868)) and [r['number'] for r in final]==list(range(1869,1873))
    cases=[]
    for e in post+final:
        name=f"{e['number']:06d}";folder=out/name;folder.mkdir()
        source=HISTORY/e['artifact'];shutil.copyfile(source,folder/'historical.npz')
        with np.load(source) as f:d={k:f[k] for k in f.files}
        save_lp(folder/'problem.bin',d);loaded=load_lp(folder/'problem.bin')
        for k in ['A_data','A_indices','A_indptr','A_shape','b','c','upper','active']:assert np.array_equal(d[k],loaded[k])
        save_lp(folder/'roundtrip.bin',loaded);assert sha(folder/'roundtrip.bin')==sha(folder/'problem.bin');(folder/'roundtrip.bin').unlink()
        write_json(folder/'event.json',e)
        cases.append(dict(name=name,source=str(source),source_sha256=sha(source),binary_sha256=sha(folder/'problem.bin'),
            phase=e['phase'],iteration=e['iteration'],rows=int(d['A_shape'][0]),variables=int(d['A_shape'][1]),nnz=len(d['A_data'])))
    sequences=dict(late_pruning=[f"{r['number']:06d}" for r in post],final_retuning=[f"{r['number']:06d}" for r in final])
    for name,ids in sequences.items():
        (out/(name+'.txt')).write_text('\n'.join(str(out/i/'problem.bin') for i in ids)+'\n')
    write_json(out/'manifest.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cases=cases,sequences=sequences,
      original_trace=str(HISTORY/'trace.jsonl'),trace_sha256=sha(HISTORY/'trace.jsonl'),full_final_phase=wholefinal,
      settings_sha256=sha(HISTORY/'settings.json'),source_sha256=sha(SOURCE)))
    prob,info,x=reconstruct();canon,chain,inverse=prob.get_problem_data(cp.CLARABEL)
    saved=load_lp(out/'001872/problem.bin');A=canon['A'].tocsr();diff=A-saved['A']
    same_shape=A.shape==saved['A'].shape
    sparse.save_npz(out/'reconstructed-canonical-A.npz',canon['A'])
    np.savez(out/'reconstructed-canonical-vectors.npz',b=canon['b'],c=canon['c'])
    info.update(canonical_shape=list(A.shape),canonical_nnz=A.nnz,saved_nnz=saved['A'].nnz,
       shape_equal=same_shape,canonical_stored_zeros=int((A.data==0).sum()),
       coefficient_differences=diff.nnz,max_coefficient_difference=float(abs(diff.data).max(initial=0)),
       b_equal=np.array_equal(canon['b'],saved['b']),max_b_difference=float(abs(canon['b']-saved['b']).max()),
       c_equal=np.array_equal(canon['c'],saved['c']),cone_dimensions=str(canon['dims']),
       variable_count=len(canon['c']),fresh_problem_solver_cache_empty=not bool(prob._solver_cache),
       canonical_A_sha256=sha(out/'reconstructed-canonical-A.npz'),canonical_vectors_sha256=sha(out/'reconstructed-canonical-vectors.npz'))
    assert same_shape and info['c_equal']
    write_json(out/'reconstruction.json',info)
    print(json.dumps({k:v for k,v in info.items() if k not in ['historical_event','final_retune_stop']},indent=2))
if __name__=='__main__':main()
