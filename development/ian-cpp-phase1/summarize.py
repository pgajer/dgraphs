"""Regenerate complete numerical and timing tables; failures cannot disappear."""
import csv,json,sys
from pathlib import Path
import numpy as np
from common import write_json,load_lp,validate,sha
fixtures,runs,out=map(Path,sys.argv[1:]);out.mkdir(parents=True,exist_ok=False)
schedule=json.loads((runs/'schedule.json').read_text());assert len(schedule)==36
manifest=json.loads((fixtures/'manifest.json').read_text());rows=[];vectors={}
for seq,(rep,case,backend) in enumerate(schedule):
    folder=runs/f'{seq:02d}-{case}-{backend}-r{rep+1}'
    m=json.loads((folder/'measurement.json').read_text());assert (m['sequence'],m['case'],m['backend'],m['repetition'])==(seq,case,backend,rep+1)
    r=m.get('result',{});v=r.get('validation',{});dual=r.get('dual_diagnostics',{})
    if r:
        d=load_lp(fixtures/case/'problem.bin');x=np.fromfile(folder/'result.x.bin',dtype='<f8')
        assert validate(d,x,r['objective'],r['status'])==v
        vectors[case,backend,rep]=x
    event=json.loads((fixtures/case/'event.json').read_text())
    historical_objective_error=abs(r['objective']-event['objective'])/max(1,abs(r['objective']),abs(event['objective'])) if r else None
    rows.append(dict(sequence=seq,case=case,path=backend,repetition=rep+1,accepted=m['accepted'],exit_code=m['exit_code'],
      end_to_end_seconds=m['end_to_end_seconds'],root_peak_rss_MiB=m['root_peak_rss_bytes']/2**20,
      sampled_tree_peak_rss_MiB=m['peak_tree_rss_bytes']/2**20,threads=m['peak_tree_threads'],
      tree_processes=m['max_observed_tree_processes'],load_1min=m['load_before'][0],system_cpu_percent=m['system_cpu_percent'],
      startup_seconds=r.get('startup_import_seconds'),input_seconds=r.get('input_seconds'),setup_seconds=r.get('setup_seconds'),
      solve_call_seconds=r.get('solve_call_seconds'),solver_seconds=r.get('solver_time'),iterations=r.get('iterations'),
      output_seconds=r.get('validation_output_seconds'),external_validation_seconds=m['external_validation_seconds'],
      objective=v.get('recomputed_objective'),constraint_residual=v.get('max_normalized_violation'),
      absolute_violation=v.get('max_absolute_violation'),objective_error=v.get('objective_relative_error'),
      lower_bound_violation=v.get('lower_bound_violation'),upper_bound_violation=v.get('upper_bound_violation'),
      historical_objective_relative_difference=historical_objective_error,
      historical_scale_max_abs=r.get('scale_historical_max_abs'),historical_scale_relative_l2=r.get('scale_historical_relative_l2'),
      dual_relative_gap=dual.get('relative_gap'),dual_stationarity=dual.get('stationarity_max'),dual_negative_max=dual.get('dual_negative_max'),
      error=m.get('result_error')))
assert len(set((r['case'],r['path'],r['repetition']) for r in rows))==36
summary=[];pairs=[]
for case in [c['label'] for c in manifest['cases']]:
    row={'case':case}
    for backend in ['python','native']:
        z=[r for r in rows if r['case']==case and r['path']==backend]
        assert len(z)==3
        row[backend+'_accepted']=sum(r['accepted'] for r in z)
        for key in ['end_to_end_seconds','root_peak_rss_MiB','solver_seconds','input_seconds','setup_seconds','solve_call_seconds','startup_seconds','external_validation_seconds']:
            vals=[r[key] for r in z]
            row[backend+'_'+key+'_median']=float(np.median(vals)) if all(v is not None for v in vals) else None
            row[backend+'_'+key+'_range']=[min(vals),max(vals)] if all(v is not None for v in vals) else None
    row['end_to_end_ratio_python_over_native']=row['python_end_to_end_seconds_median']/row['native_end_to_end_seconds_median'] if row['python_accepted']==row['native_accepted']==3 else None
    row['solver_ratio_python_over_native']=row['python_solver_seconds_median']/row['native_solver_seconds_median'] if row['python_accepted']==row['native_accepted']==3 else None
    summary.append(row)
    for rep in range(3):
        p=next(r for r in rows if r['case']==case and r['path']=='python' and r['repetition']==rep+1)
        n=next(r for r in rows if r['case']==case and r['path']=='native' and r['repetition']==rep+1)
        both=p['accepted'] and n['accepted'];a=vectors.get((case,'python',rep));b=vectors.get((case,'native',rep))
        pairs.append(dict(case=case,repetition=rep+1,both_accepted=both,
            objective_relative_difference=abs(p['objective']-n['objective'])/max(1,abs(p['objective']),abs(n['objective'])) if both else None,
            scale_max_abs=float(abs(a-b).max()) if both else None,
            scale_relative_l2=float(np.linalg.norm(a-b)/max(1,np.linalg.norm(a),np.linalg.norm(b))) if both else None))
for name,data in [('attempts',rows),('case-summary',summary),('paired-numerics',pairs)]:
    write_json(out/(name+'.json'),data)
    if name!='case-summary':
        with (out/(name+'.tsv')).open('w') as f:
            w=csv.DictWriter(f,fieldnames=list(data[0]),delimiter='\t');w.writeheader();w.writerows(data)
lines=['# All measured attempts','',
'| Case | Path | Repeat | Accepted | Wall s | Solver s | Root peak MiB | Normalized violation | Historical max scale change |',
'|---|---|---:|---|---:|---:|---:|---:|---:|']
for r in rows:
    fmt=lambda v: 'unavailable' if v is None else f'{v:.6g}'
    lines.append(f"| {r['case']} | {r['path']} | {r['repetition']} | {r['accepted']} | {fmt(r['end_to_end_seconds'])} | {fmt(r['solver_seconds'])} | {fmt(r['root_peak_rss_MiB'])} | {fmt(r['constraint_residual'])} | {fmt(r['historical_scale_max_abs'])} |")
(out/'all-attempts.md').write_text('\n'.join(lines)+'\n')
write_json(out/'source-manifest.json',dict(fixtures_sha256=sha(fixtures/'manifest.json'),schedule_sha256=sha(runs/'schedule.json'),
    measurements={str(p):sha(p) for p in sorted(runs.glob('*/measurement.json'))},
    accepted=sum(r['accepted'] for r in rows),total=len(rows)))
print(json.dumps(summary,indent=2))
