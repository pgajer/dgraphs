"""Four operational failure injections, durable-stage assertions and raw checks."""
import argparse,json,subprocess,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'phase02'))
from supervise import supervise,one_thread_environment
from reference import sha,write
from compare import traces,check_lp
p=argparse.ArgumentParser();p.add_argument('fixture',type=Path);p.add_argument('output',type=Path);p.add_argument('--native',type=Path,required=True);a=p.parse_args();assert not subprocess.check_output(['git','status','--porcelain'],text=True)
a.output.mkdir(parents=True,exist_ok=False);checks=[];stage_hashes={}
for injection,expected in [('invalid_solver',[False,False,False]),('after_graph',[True,False,False]),('after_scales',[True,True,False]),('after_affinity',[True,True,True])]:
 folder=a.output/injection;process=supervise([str(a.native),str(a.fixture),str(folder/'child'),injection],folder,one_thread_environment());status=json.loads((folder/'child/status.json').read_text());events=traces(folder/'child');raw=[check_lp(e) for e in events if e['event']=='solve'];hashes={}
 assert process['exit_code']!=0 and not status['complete']
 assert [status[k] for k in ['graph','scales','affinity']]==expected
 assert bool(status['error'])
 for stage,completed in zip(['graph','scales','affinity'],expected):
  artifact=folder/'child'/(stage+'.json');assert artifact.exists()==completed
  if completed:
   digest=sha(artifact);assert digest==status[stage+'_sha256'];hashes[stage]=digest
   content=json.loads(artifact.read_text());assert content['status']=='validated' and content['stage']==stage
   assert content['input_sha256']==sha(a.fixture)
   assert all(k in content for k in ['source_sha256','configuration_sha256','mapping'])
   if stage in stage_hashes:assert stage_hashes[stage]==digest
   else:stage_hashes[stage]=digest
 if injection=='invalid_solver':
  assert len(raw)==1 and not raw[0]['accepted'];assert not any(e['event'] in ['volume','decision','pruned','graph_stop','complete'] for e in events)
 else:assert raw and all(r['accepted'] and r['dual_valid'] for r in raw)
 if injection=='after_graph':assert not any(e['event']=='tune_start' and e['phase']=='final_affinity_retuning' for e in events)
 assert not list((folder/'child').glob('*.tmp'))
 checks.append(dict(injection=injection,process=process,status=status,raw_checks=raw,checkpoint_hashes=hashes,passed=True))
write(a.output/'checks.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),checks=checks,all_passed=True))
print('Four failure injections passed; preceding stage hashes survive unchanged, invalid scales never drive ratios/pruning.')
