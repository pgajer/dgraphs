"""Final native verification after a cap-telemetry fix; not timing repetitions."""
import argparse,json,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'phase02'))
from supervise import supervise,one_thread_environment
from reference import sha,write
from compare import compare,traces,check_lp
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('output',type=Path);p.add_argument('--native',type=Path,required=True);a=p.parse_args();assert not subprocess.check_output(['git','status','--porcelain'],text=True)
a.output.mkdir(parents=True,exist_ok=False);manifest=json.loads((a.root/'fixtures-v1/manifest.json').read_text());checks=[];env=one_thread_environment();src=Path(__file__).parent
for name in manifest['ordinary']:
 folder=a.output/name;process=supervise([str(a.native),str(a.root/'fixtures-v1'/(name+'.json')),str(folder/'child')],folder,env);assert process['exit_code']==0
 result=compare(a.root/'cases-v1'/name/'evaluated/child',folder/'child',folder/'comparison');assert result['passed'];assert all(r['accepted'] and r['dual_valid'] for r in result['raw_checks_b']);assert all(k['valid'] for k in result['kernel_checks_b'])
 old=traces(a.root/'cases-v1'/name/'native/child');new=traces(folder/'child');assert len(old)==len(new)
 for x,y in zip(old,new):
  for key in ['scales','dual','affinity']:
   if key in x:assert x[key]==y[key]
 checks.append(dict(case=name,process=process,passed=True,bitwise_reproduced_primal_dual_affinity=True))
# A cap is an intentionally changed stopping bound, not an ordinary run.
cap=a.output/'cap';cap.mkdir();capprocess={}
for cond in ['original','evaluated','native']:
 folder=cap/cond;fixture=a.root/'fixtures-v1/pressmat_hellinger_subset.json'
 cmd=[str(a.native),str(fixture),str(folder/'child'),'pruning_cap'] if cond=='native' else [sys.executable,'-B',str(src/'reference.py'),str(fixture),str(folder/'child'),cond,'--pruning-cap']
 process=supervise(cmd,folder,env);status=json.loads((folder/'child/status.json').read_text());assert process['exit_code']!=0 and not any(status[k] for k in ['graph','scales','affinity','complete']);events=traces(folder/'child');assert events[-1]['event']=='graph_stop' and events[-1]['iteration']==0 and events[-1]['reason']=='pruning_iteration_cap';capprocess[cond]=dict(process=process,status=status)
for left,right in [('original','evaluated'),('evaluated','native')]:
 r=compare(cap/left/'child',cap/right/'child',cap/(left+'-'+right));assert r['passed']
write(cap/'checks.json',dict(controlled_override=dict(max_iters=1),results=capprocess,passed=True))
fixture=a.output/'empty-input.json';write(fixture,dict(kind='full',name='empty',features=[],distances=[],ids=[]));empty=[]
for cond in ['evaluated','native']:
 folder=a.output/('empty-'+cond);cmd=[str(a.native),str(fixture),str(folder/'child')] if cond=='native' else [sys.executable,'-B',str(src/'reference.py'),str(fixture),str(folder/'child'),cond]
 process=supervise(cmd,folder,env);status=json.loads((folder/'child/status.json').read_text());assert process['exit_code']!=0 and not any(status[k] for k in ['graph','scales','affinity','complete']);empty.append(dict(condition=cond,process=process,status=status,passed=True))
write(a.output/'checks.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),native_sha256=sha(a.native),cases=checks,cap_passed=True,empty_refusals=empty))
print('Final native runs exactly reproduce prior vectors and affinities; three forced-cap traces and two empty-input refusals passed.')
