"""Reuse accepted numerical rules and independently check checkpoint envelopes."""
import hashlib,subprocess,sys
from pathlib import Path
from support import *
sys.path.insert(0,str(E))
from validate import inspect,retry_checks
child,fixture,out,tool=map(Path,sys.argv[1:5])
r=inspect(child,fixture,out);r['retry_checks']=retry_checks(child,out/'retry',not r['complete'])
names=sorted(str(p.relative_to(CANDIDATE)) for d in ['include','src','tests'] for p in (CANDIDATE/d).rglob('*') if p.suffix in ['.hpp','.cpp','.inc'])
identity=hashlib.sha256((''.join(sha(CANDIDATE/n) for n in names)+sha(CANDIDATE/'CMakeLists.txt')).encode()).hexdigest()
checkpoints=[]
for cp in sorted((child/'checkpoints').glob('checkpoint-*.json')):
 j=load(cp);roundtrip=out/(cp.stem+'-roundtrip.json')
 proc=subprocess.run([str(tool),str(cp),str(roundtrip)],capture_output=True,text=True)
 assert proc.returncode==0,proc.stderr
 digest_ok=load(roundtrip)['payload_sha256']==j['payload_sha256']
 running=hashlib.sha256();size=0;count=0
 with (child/'trace.jsonl').open('rb') as f:
  for line in f:
   if count==j['trace_prefix_events']:break
   running.update(line);size+=len(line);count+=1
 prefix_ok=count==j['trace_prefix_events'] and size==j['trace_prefix_bytes'] and running.hexdigest()==j['trace_prefix_sha256']
 identity_ok=j['input_file_sha256']==sha(fixture) and j['payload']['policy']==POLICY
 if j['parent_checkpoint']:identity_ok &= sha(j['parent_checkpoint'])==j['parent_checkpoint_sha256']
 identity_ok &= j['payload']['source']==identity and j['payload']['configuration']==sha(CANDIDATE/'config.json')
 ok=digest_ok and prefix_ok and identity_ok
 checkpoints.append(dict(path=str(cp),valid=ok,payload_digest=digest_ok,trace_prefix=prefix_ok,input_parent=identity_ok,payload_source=j['payload']['source'],payload_configuration=j['payload']['configuration']))
 r['valid'] &= ok
r['checkpoints']=checkpoints;write(out/'summary.json',r)
print(dict(valid=r['valid'],complete=r['complete'],attempts=r['retry_checks']['attempts'],checkpoints=len(checkpoints)))
