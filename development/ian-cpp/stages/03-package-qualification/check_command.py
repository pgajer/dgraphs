"""Bounded zero-optimizer overlap regression: three simultaneous logger clients."""
import hashlib,json,subprocess,sys
from pathlib import Path
root=Path(sys.argv[1]).resolve();root.mkdir(exist_ok=False)
for runtime in ['a','b']:(root/runtime).mkdir()
(root/'environment.json').write_text(json.dumps({'runtimes':{r:{'env':{}} for r in ['a','b']}}))
child=root/'child.py';child.write_text('import json,sys,time\nfrom pathlib import Path\np=Path(sys.argv[1]);start=time.monotonic_ns();time.sleep(0.2);p.write_text(json.dumps(dict(start=start,end=time.monotonic_ns())))\nraise SystemExit(int(sys.argv[2]))\n')
logger=Path(__file__).with_name('command.py');runs=[]
for runtime,label,code in [('a','first',0),('a','second',7),('b','third',0)]:
 cmd=[sys.executable,str(logger),str(root),runtime,label,sys.executable,str(child),str(root/(label+'.json')),str(code)]
 log=(root/(label+'-driver.log')).open('w');runs.append((label,code,cmd,log,subprocess.Popen(cmd,stdout=log,stderr=subprocess.STDOUT)))
result=[]
for label,code,cmd,log,proc in runs:
 actual=proc.wait(timeout=30);log.close();assert actual==code
 result.append(dict(label=label,command=cmd,expected_exit=code,actual_exit=actual))
records=[r for runtime in ['a','b'] for r in json.loads((root/runtime/'commands.json').read_text())]
assert len(records)==3 and {r['label'] for r in records}=={'first','second','third'}
assert all(r['state']=='reaped' and r['seconds']>=0.2 and 'returncode' in r for r in records)
intervals=sorted([json.loads((root/(r['label']+'.json')).read_text()) for r in records],key=lambda j:j['start'])
assert all(a['end']<=b['start'] for a,b in zip(intervals,intervals[1:]))
assert not list(root.rglob('*.tmp'))
(root/'summary.json').write_text(json.dumps(dict(passed=True,optimizer_calls=0,overlapping_clients=3,serialized_children=True,intervals=intervals,commands=result,records=records,logger_sha256=hashlib.sha256(logger.read_bytes()).hexdigest()),indent=2)+'\n')
print('Three simultaneous clients, three serialized/reaped children; all exit and timing records preserved.')
