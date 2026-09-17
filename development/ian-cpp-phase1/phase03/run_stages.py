"""Bounded boundary checks and input refusals; preserves all attempts."""
import argparse,json,subprocess,sys
from pathlib import Path
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'phase02'))
from supervise import supervise,one_thread_environment
from reference import sha,write
from compare import arrays,check_lp
p=argparse.ArgumentParser();p.add_argument('fixtures',type=Path);p.add_argument('output',type=Path);p.add_argument('--native',type=Path,required=True);a=p.parse_args();assert not subprocess.check_output(['git','status','--porcelain'],text=True)
a.output.mkdir(parents=True,exist_ok=False);src=Path(__file__).parent;env=one_thread_environment();results={};processes={}
write(a.output/'provenance.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),native_sha256=sha(a.native),fixture_manifest_sha256=sha(a.fixtures/'manifest.json')))
for cond in ['original','evaluated','native']:
 folder=a.output/cond;cmd=[str(a.native),str(a.fixtures/'stages.json'),str(folder/'child')] if cond=='native' else [sys.executable,'-B',str(src/'stages.py'),str(a.fixtures/'stages.json'),str(folder/'child'),cond]
 processes[cond]=supervise(cmd,folder,env)
 if (folder/'child/stages.json').exists():results[cond]=json.loads((folder/'child/stages.json').read_text())
checks=[]
if len(results)==3:
 for cond in ['original','native']:
  x,y=results['evaluated'],results[cond]
  for name in ['duplicate','gabriel','pruning']:checks.append(dict(condition=cond,check=name,passed=x[name]==y[name]))
  for i in range(len(x['decisions'])):
   checks.append(dict(condition=cond,check=x['decisions'][i]['name'],passed=x['decisions'][i]['candidates']==y['decisions'][i]['candidates'] and all(arrays(x['decisions'][i][k],y['decisions'][i][k],1e-7,1e-7)['pass_limit'] for k in ['location','dispersion','threshold']),evaluated=x['decisions'][i],other=y['decisions'][i]))
  for name in ['affinity','ratios','weighted_ratios']:
   checks.append(dict(condition=cond,check='disconnected_'+name,**arrays(x['disconnected'][name],y['disconnected'][name],1e-7,1e-7)))
  checks.append(dict(condition=cond,check='disconnected_components',passed=x['disconnected']['components']==y['disconnected']['components']))
  checks.append(dict(condition=cond,check='cutoff_affinity',**arrays(x['affinity_cutoffs'],y['affinity_cutoffs'],1e-7,1e-7),same_support=np.array_equal(np.asarray(x['affinity_cutoffs'])==0,np.asarray(y['affinity_cutoffs'])==0)))
 for cond in results:checks.append(dict(condition=cond,check='disconnected_lp',**check_lp(results[cond]['disconnected']['solve'])))
# Refusal checks are input guards, separate from reference's own one-point probe.
refusals=[]
for fixture in sorted(a.fixtures.glob('refusal-*.json')):
 for cond in ['evaluated','native']:
  folder=a.output/(fixture.stem+'-'+cond);cmd=[str(a.native),str(fixture),str(folder/'child')] if cond=='native' else [sys.executable,'-B',str(src/'reference.py'),str(fixture),str(folder/'child'),cond]
  process=supervise(cmd,folder,env);status=json.loads((folder/'child/status.json').read_text());refusals.append(dict(fixture=fixture.name,condition=cond,exit_code=process['exit_code'],status=status,passed=process['exit_code']!=0 and not any(status[s] for s in ['graph','scales','affinity','complete'])))
write(a.output/'checks.json',dict(processes=processes,checks=checks,refusals=refusals))
print(json.dumps(dict(stage_process_exits={k:v['exit_code'] for k,v in processes.items()},checks=len(checks),refusal_checks=len(refusals)),indent=2))
