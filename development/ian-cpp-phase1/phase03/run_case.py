"""One frozen fixture across three conditions, with external trace comparisons."""
import argparse,json,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'phase02'))
from supervise import supervise,one_thread_environment
from reference import sha,write
from compare import compare,check_lp,traces
p=argparse.ArgumentParser();p.add_argument('fixture',type=Path);p.add_argument('output',type=Path);p.add_argument('--native',type=Path,required=True);a=p.parse_args()
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
a.output.mkdir(parents=True,exist_ok=False);src=Path(__file__).parent;env=one_thread_environment();env['MPLCONFIGDIR']=str(a.output/'mpl-cache')
write(a.output/'provenance.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),fixture_sha256=sha(a.fixture),native_sha256=sha(a.native),configuration_sha256=sha(src/'config.json')))
processes={}
for condition in ['original','evaluated','native']:
 folder=a.output/condition
 cmd=([str(a.native),str(a.fixture),str(folder/'child')] if condition=='native' else [sys.executable,'-B',str(src/'reference.py'),str(a.fixture),str(folder/'child'),condition])
 processes[condition]=supervise(cmd,folder,env)
 print(condition,'exit',processes[condition]['exit_code'],'seconds',processes[condition]['end_to_end_seconds'],flush=True)
comparisons={}
for label,left,right in [('representation','original','evaluated'),('implementation','evaluated','native')]:
 if all((a.output/c/'child/trace.jsonl').exists() for c in [left,right]):
  r=compare(a.output/left/'child',a.output/right/'child',a.output/label);comparisons[label]={k:r[k] for k in ['passed','events_a','events_b','first_divergence']}
validations={condition:[dict(number=e['number'],**check_lp(e)) for e in traces(a.output/condition/'child') if e['event']=='solve'] if (a.output/condition/'child/trace.jsonl').exists() else [] for condition in processes}
write(a.output/'summary.json',dict(processes=processes,comparisons=comparisons,raw_validations=validations))
print(json.dumps(comparisons,indent=2))
