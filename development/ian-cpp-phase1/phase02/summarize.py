"""Recheck raw vectors and derive tables; never executes an optimization."""
import argparse,json,sys,statistics,itertools,subprocess
from pathlib import Path
import numpy as np
from scipy import sparse
from validate_outputs import check_solution
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import sha,write_json

p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
for name in ['fixtures','diagnostics','measured']:p.add_argument('--'+name,type=Path)
a=p.parse_args();a.fixtures=a.fixtures or a.root/'fixtures-v2';a.diagnostics=a.diagnostics or a.root/'diagnostics-v1';a.measured=a.measured or a.root/'measured-v1'
a.output.mkdir(parents=True,exist_ok=False)
manifest=json.loads((a.fixtures/'manifest.json').read_text());cases={c['name']:c for c in manifest['cases']}
for case in cases.values():assert sha(case['source'])==case['source_sha256']
def read(path):return json.loads(path.read_text())
def stats(values):return dict(median=statistics.median(values),minimum=min(values),maximum=max(values),values=values)
def difference(x,y):return dict(max_absolute=float(abs(x-y).max(initial=0)),relative_l2=float(np.linalg.norm(x-y)/max(1,np.linalg.norm(y))),exact=bool(np.array_equal(x,y)))
def vectors(folder,step):return np.fromfile(folder/'child'/f'{step:02d}.x.bin',dtype='<f8')

diagnostics=[]
for folder in sorted(a.diagnostics.glob('[0-9][0-9]-*')):
    raw=read(folder/'child/result.json');process=read(folder/'process.json')
    x=np.fromfile(folder/'child/scales.bin',dtype='<f8');z=np.fromfile(folder/'child/canonical-z.bin',dtype='<f8')[:cases['001872']['rows']]
    check=check_solution(cases['001872']['source'],x,z,raw['objective'],raw['status'])
    diagnostics.append(dict(condition=folder.name,raw=raw,process=process,check=check,
        accepted=process['exit_code']==0 and check['accepted'] and check['dual_valid']))
assert len(diagnostics)==6
original=sparse.load_npz(a.fixtures/'reconstructed-canonical-A.npz').tocsc();gamma=original[:cases['001872']['rows'],-1]
assert gamma.nnz and np.min(gamma.data)>=0
projection=dict(auxiliary_column_nonzeros=gamma.nnz,minimum_nonzero_coefficient=float(gamma.data.min()),all_nonnegative=True,
   projected_matrix_equal=all(d['raw']['projected_A_differences']==0 and d['raw']['projected_b_differences']==0 for d in diagnostics),
   evaluated_and_saved_canonical_hash_equal=diagnostics[3]['raw']['canonical_data_sha256']==diagnostics[5]['raw']['canonical_data_sha256'])

schedule=read(a.measured/'schedule.json');jobs=[];bykey={};allchecks=[]
for number,cfg in enumerate(schedule):
    folder=a.measured/f'{number:02d}-{cfg["sequence"]}-{cfg["path"]}-{cfg["mode"]}-r{cfg["repetition"]}'
    prior=read(folder/'validated.json');process=read(folder/'process.json');summary=read(folder/'child/summary.json')
    ids=manifest['sequences'][cfg['sequence']];steps=[]
    assert len(list((folder/'child').glob('*.x.bin')))==len(ids)
    for step,identity in enumerate(ids):
        raw=read(folder/'child'/f'{step:02d}.json');x=vectors(folder,step);z=np.fromfile(folder/'child'/f'{step:02d}.z.bin',dtype='<f8')
        check=check_solution(cases[identity]['source'],x,z,raw['objective'],raw['status']);assert check==prior['steps'][step]['check']
        assert raw['reused_solver']==(cfg['mode']=='update' and step>0)
        assert raw['linear_solver']=='qdldl' and raw['linear_solver_threads']==1
        steps.append(dict(identity=identity,raw=raw,check=check));allchecks.append(check)
    accepted=process['exit_code']==0 and all(s['check']['accepted'] and s['check']['dual_valid'] for s in steps)
    assert accepted==prior['accepted']
    assert summary['steps']==len(ids) and summary['update_count']==(len(ids)-1 if cfg['mode']=='update' else 0)
    job=dict(**cfg,number=number,folder=str(folder),accepted=accepted,process=process,summary=summary,steps=steps)
    jobs.append(job);bykey[(cfg['sequence'],cfg['path'],cfg['mode'],cfg['repetition'])]=job
assert len(jobs)==18 and len(allchecks)==96

groups=[]
for key in sorted(set((j['sequence'],j['path'],j['mode']) for j in jobs)):
    selected=[j for j in jobs if (j['sequence'],j['path'],j['mode'])==key]
    assert len(selected)==3
    rows=dict(sequence=key[0],path=key[1],mode=key[2],jobs=len(selected),accepted=sum(j['accepted'] for j in selected))
    for name in ['sequence_seconds','startup_seconds']:
        rows[name]=stats([j['summary'][name] for j in selected])
    for name in ['end_to_end_seconds','root_peak_rss_bytes','sampled_tree_peak_rss_bytes']:
        rows[name]=stats([j['process'][name] for j in selected])
    for name in ['input_seconds','assembly_seconds','setup_update_seconds','solve_seconds','output_seconds','step_seconds']:
        rows[name]=stats([j['summary']['sums'][name] for j in selected])
    rows['total_iterations']=stats([sum(s['raw']['iterations'] for s in j['steps']) for j in selected])
    rows['step_iterations']=[[s['raw']['iterations'] for s in j['steps']] for j in selected]
    groups.append(rows)
groupmap={(g['sequence'],g['path'],g['mode']):g for g in groups}
comparisons=[]
for sequence,mode in [('late_pruning','fresh'),('final_retuning','fresh'),('final_retuning','update')]:
    py=groupmap[(sequence,'python',mode)];native=groupmap[(sequence,'native',mode)]
    pairs=[]
    for rep in [1,2,3]:
        pj=bykey[(sequence,'python',mode,rep)];nj=bykey[(sequence,'native',mode,rep)]
        for step,identity in enumerate(manifest['sequences'][sequence]):
            pairs.append(dict(repetition=rep,identity=identity,**difference(vectors(Path(pj['folder']),step),vectors(Path(nj['folder']),step))))
    comparisons.append(dict(sequence=sequence,mode=mode,all_jobs_accepted=py['accepted']==native['accepted']==3,
       median_sequence_ratio_python_over_native=py['sequence_seconds']['median']/native['sequence_seconds']['median'] if py['accepted']==native['accepted']==3 else None,
       median_root_memory_reduction=1-native['root_peak_rss_bytes']['median']/py['root_peak_rss_bytes']['median'],
       median_sampled_tree_memory_reduction=1-native['sampled_tree_peak_rss_bytes']['median']/py['sampled_tree_peak_rss_bytes']['median'],scale_pairs=pairs))
updates=[]
for path in ['python','native']:
    fresh=groupmap[('final_retuning',path,'fresh')];updated=groupmap[('final_retuning',path,'update')];pairs=[]
    for rep in [1,2,3]:
        fj=bykey[('final_retuning',path,'fresh',rep)];uj=bykey[('final_retuning',path,'update',rep)]
        for step,identity in enumerate(manifest['sequences']['final_retuning']):
            pairs.append(dict(repetition=rep,identity=identity,**difference(vectors(Path(fj['folder']),step),vectors(Path(uj['folder']),step))))
    updates.append(dict(path=path,median_fresh_over_update=fresh['sequence_seconds']['median']/updated['sequence_seconds']['median'] if fresh['accepted']==updated['accepted']==3 else None,scale_pairs=pairs))
repeat_pairs=[]
for key in sorted(groupmap):
    first=bykey[(*key,1)]
    for rep in [2,3]:
        other=bykey[(*key,rep)]
        for step,identity in enumerate(manifest['sequences'][key[0]]):repeat_pairs.append(dict(sequence=key[0],path=key[1],mode=key[2],repetition=rep,identity=identity,**difference(vectors(Path(first['folder']),step),vectors(Path(other['folder']),step))))
validation=dict(raw_sequence_vectors_checked=len(allchecks),raw_diagnostic_vectors_checked=len(diagnostics),
    sequence_jobs_accepted=sum(j['accepted'] for j in jobs),sequence_vectors_accepted=sum(c['accepted'] and c['dual_valid'] for c in allchecks),
    diagnostics_accepted=sum(d['accepted'] for d in diagnostics),
    maxima={k:max(c[k] for c in allchecks) for k in ['normalized_primal','absolute_primal','objective_error','dual_relative_gap','dual_stationarity','dual_negative_violation','historical_scale_max_abs','historical_scale_relative_l2']},
    repeat_pairs=repeat_pairs)
result=dict(inputs=dict(fixtures=str(a.fixtures),diagnostics=str(a.diagnostics),measured=str(a.measured)),revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),validation=validation,projection=projection,diagnostics=diagnostics,jobs=jobs,groups=groups,comparisons=comparisons,updates=updates)
write_json(a.output/'results.json',result)
lines=['# Derived phase 2 tables','','All values below are generated from raw records; no optimization is run by this script.','',
 '| Diagnostic construction | Backend / threads | Solver seconds | Iterations | Max scale difference from historical | Accepted |',
 '|---|---:|---:|---:|---:|---|']
for d in diagnostics:
 r=d['raw'];lines.append(f'| {d["condition"]} | {r["actual_linear_solver"]} / {r["actual_linear_threads"]} | {r["solver_seconds"]:.3f} | {r["iterations"]} | {r["original_scale_max_abs"]:.9g} | {d["accepted"]} |')
lines+=['','Sequence time excludes imports; process time includes startup/shutdown. Memory is OS root-process peak RSS, MiB (2^20 bytes). Three repeats per row.','',
'| Sequence | Path | Mode | Sequence seconds median [min, max] | Process seconds median | Peak MiB median | Sum iterations | Accepted jobs |',
'|---|---|---|---:|---:|---:|---:|---:|']
for g in groups:
 s=g['sequence_seconds'];lines.append(f'| {g["sequence"]} | {g["path"]} | {g["mode"]} | {s["median"]:.3f} [{s["minimum"]:.3f}, {s["maximum"]:.3f}] | {g["end_to_end_seconds"]["median"]:.3f} | {g["root_peak_rss_bytes"]["median"]/2**20:.1f} | {g["total_iterations"]["median"]} | {g["accepted"]}/3 |')
lines+=['','| Sequence | Path | Mode | Input s | Assembly s | Setup/update s | Solve s | Vector output s |', '|---|---|---|---:|---:|---:|---:|---:|']
for g in groups:lines.append('| '+' | '.join([g['sequence'],g['path'],g['mode']]+[f'{g[k]["median"]:.4f}' for k in ['input_seconds','assembly_seconds','setup_update_seconds','solve_seconds','output_seconds']])+' |')
lines+=['','Individual process records (all attempts):','','| Job | Sequence | Path | Mode | Repeat | Sequence s | Process s | Peak MiB | Iterations | Accepted |','|---:|---|---|---|---:|---:|---:|---:|---:|---|']
for j in jobs:lines.append(f'| {j["number"]} | {j["sequence"]} | {j["path"]} | {j["mode"]} | {j["repetition"]} | {j["summary"]["sequence_seconds"]:.3f} | {j["process"]["end_to_end_seconds"]:.3f} | {j["process"]["root_peak_rss_bytes"]/2**20:.1f} | {sum(s["raw"]["iterations"] for s in j["steps"])} | {j["accepted"]} |')
(a.output/'tables.md').write_text('\n'.join(lines)+'\n')
print(json.dumps({k:validation[k] for k in validation if k!='repeat_pairs'},indent=2));print('All raw-vector recomputations completed.')
if not (validation['sequence_jobs_accepted']==18 and validation['sequence_vectors_accepted']==96 and validation['diagnostics_accepted']==6):raise SystemExit(2)
