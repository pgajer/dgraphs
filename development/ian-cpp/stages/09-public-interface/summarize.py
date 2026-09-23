"""Reconstruct the public-interface census from durable submitted records; no solves."""
import hashlib,json,subprocess,sys
from pathlib import Path
P=Path(sys.argv[1]);H=Path(__file__).resolve().parent;ROOT=H.parents[3]
load=lambda p:json.loads(p.read_text());sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
L=load(P/'numerical-v2/ledger.json');assert L['complete'] and all(L['checks'].values())
processes=L['prior_processes']+L['processes'];assert len({p['pid'] for p in processes})==len(processes)
assert all(p['state']=='reaped' and p['exit_code']==0 and p['reason'] is None for p in processes)
counts={k:sum(c['certificate_counts'][k] for c in L['cases']) for k in ['full','accepted','rejected','summary']}
assert counts['full']+counts['summary']==sum(p['optimizer_calls'] for p in processes)
assert counts['accepted']+counts['rejected']==counts['full']
# The pinned backend includes native core, R bridge and dependency snapshot.
backend_diff=subprocess.check_output(['git','diff','1e769e1','--','inst/ian/backend','src'],cwd=ROOT,text=True)
assert not backend_diff
runtime={}
for name,c in load(P/'environment.json')['runtimes'].items():
 d=P/name;commands=load(d/'commands.json');assert all(x['state']=='reaped' for x in commands)
 b=load(Path(c['backend']).parent/'build-record.json');assert b['complete'] and all(x['state']=='reaped' and x['returncode']==0 for x in b['commands'])
 z=load(d/'zero-controls/checks.json');assert z['engine.calls']==0 and all(z['checks'].values())
 controls=load(P/'numerical-v2'/name/'controls/child/ledger.json');assert all(controls['checks'].values())
 runtime[name]=dict(commands=len(commands),command_failures=[x['label'] for x in commands if x['returncode']!=0],backend_commands=len(b['commands']),zero_controls=len(z['checks']),control_entries=len(controls['calls']),control_checks=len(controls['checks']),complete_control_entries=sum(x['complete'] for x in controls['calls'].values()),check_status=[x for x in (d/'check/dgraphs.Rcheck/00check.log').read_text().splitlines() if x.startswith('Status:')],package_archive_sha256=sha(P/'dgraphs_0.3.0.9000.tar.gz'))
summary=dict(entries=L['entries'],processes=len(processes),attempts=sum(p['optimizer_calls'] for p in processes),certificate_counts=counts,child_seconds=sum(p['wall_seconds'] for p in processes),peak_sampled_tree_MiB=max(p['sampled_tree_peak_rss_bytes'] for p in processes)/2**20,all_processes_reaped=True,case_comparisons=len(L['cases'])-2,runtimes=runtime,core_change_from_base=False,base='1e769e1',numerical_source_revisions=sorted({p['revision'] for p in processes}),interpretation='Regression and interface qualification; no new scientific or performance comparison')
(P/'study-summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary,indent=2))
