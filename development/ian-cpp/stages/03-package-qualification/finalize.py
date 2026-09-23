"""Read-only package evidence census, full-payload certificates and identities."""
import json,sys,hashlib,subprocess,collections
from pathlib import Path
HERE=Path(__file__).resolve().parent;REPO=HERE.parents[3]
sys.path.insert(0,str(REPO/'development/ian-cpp-phase1/phase07e'));import validate as v
root=Path(sys.argv[1]);load=lambda p:json.loads(Path(p).read_text());sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
out=root/'final-checks-v1';out.mkdir(exist_ok=False)
ledgers=[load(root/('numerical-v'+str(n))/'ledger.json') for n in [1,2]]
processes=sum([j['processes'] for j in ledgers],[])
assert all(j['complete'] and all(j['checks'].values()) for j in ledgers)
assert all(p['state']=='reaped' and p['reason'] is None and p['exit_code']==0 for p in processes)
assert sum(p['engine_entries'] for p in processes)==64 and sum(p['optimizer_calls'] for p in processes)==628
files=[]
for num in [1,2]:
 for runtime in (['rdevel','r45'] if num==1 else ['rdevel-v2','r45-v2']):
  base=root/('numerical-v'+str(num))/runtime
  for case in base.iterdir():
   if case.name=='interface':continue
   child=case/'child'
   if case.name in ['candidate-controls','relocation']:files += sorted(child.glob('*.jsonl'))
   else:files.append(child/'trace.jsonl')
# Batched controls also contain a compact aggregate trace; only complete payloads count.
files += [root/r/'result-checks-v2/strict-duplicates.jsonl' for r in ['rdevel-v2','r45-v2']]
seen=set();counts=collections.Counter();checks=[]
with (out/'certificates.jsonl').open('w') as stream:
 for path in files:
  for e in v.events(path):
   if e['event']!='solve' or 'A_data' not in e:continue
   key=(str(path),e['number']);assert key not in seen;seen.add(key)
   c=v.scalar_check(e,e['scales'],e['dual'],e['objective'],'Solved' if e['status']=='optimal' else e['status'])
   assert c['accepted']==e['accepted'],(path,e['number'])
   if 'attempt' in e:v.check_units(e)
   counts['payloads']+=1;counts['accepted' if e['accepted'] else 'rejected']+=1;counts['retries']+=e.get('attempt',0)==1
   stream.write(json.dumps(dict(path=str(path),number=e['number'],**c),default=lambda x:x.tolist())+'\n')
assert counts['payloads']==504,counts
for runtime in ['rdevel','r45','rdevel-v2','r45-v2']:
 result=load(root/runtime/('result-checks-v2' if runtime.endswith('-v2') else 'result-checks-v1')/'summary.json');assert result['passed'];checks.append(result)
for runtime in ['rdevel-v2','r45-v2']:
 module=root/runtime/'library/dgraphs/ian/native/dgraphs_ian.so'
 result=subprocess.run(['otool','-L',str(module)],capture_output=True,text=True,check=True);(out/(runtime+'-linkage.txt')).write_text(result.stdout)
 assert not any(x in result.stdout.split('\n',1)[1] for x in ['/.codex/','/current_projects/'])
 result=subprocess.run(['file',str(module)],capture_output=True,text=True,check=True);(out/(runtime+'-architecture.txt')).write_text(result.stdout);assert 'arm64' in result.stdout
 result=subprocess.run([sys.executable,str(REPO/'dev/artifact-provenance.py'),'verify',str(root/runtime/'library')],capture_output=True,text=True)
 (out/(runtime+'-provenance.txt')).write_text(result.stdout+result.stderr);assert result.returncode==0
summary=dict(execution_complete=True,independent_audit='pending',engine_entries=64,solver_attempts=628,process_launches=len(processes),full_payload_certificates=dict(counts),settings_snapshots_checked=sum(x['attempts'] for x in checks),read_only_checks=checks,child_wall_seconds=sum(p['wall_seconds'] for p in processes),sampled_tree_peak_rss_bytes=max(p['sampled_tree_peak_rss_bytes'] for p in processes),archive_v2=load(root/'archive-v2.json'),reporting_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
(root/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print({k:v for k,v in summary.items() if k not in ['archive_v2','read_only_checks']})
