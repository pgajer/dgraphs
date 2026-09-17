"""Post-run numerical, graph, affinity and checkpoint checks. No optimization."""
import hashlib
import subprocess
import sys
from pathlib import Path
from checks import inspect, compare, load, write, sha

mode=sys.argv[1]
if mode=='inspect':
    child,fixture,out,tool=map(Path,sys.argv[2:6])
    result=inspect(child,fixture,out)
    checkpoints=[]
    for cp in sorted((child/'checkpoints').glob('checkpoint-*.json')):
        j=load(cp); roundtrip=out/(cp.stem+'-roundtrip.json')
        subprocess.run([str(tool),str(cp),str(roundtrip)],check=True)
        digest_ok=load(roundtrip)['payload_sha256']==j['payload_sha256']
        running=hashlib.sha256(); size=0; count=0
        with (child/'trace.jsonl').open('rb') as f:
            for line in f:
                if count==j['trace_prefix_events']: break
                running.update(line); size+=len(line); count+=1
        prefix_ok=count==j['trace_prefix_events'] and size==j['trace_prefix_bytes'] and running.hexdigest()==j['trace_prefix_sha256']
        identity_ok=j['input_file_sha256']==sha(fixture)
        if j['parent_checkpoint']: identity_ok &= sha(j['parent_checkpoint'])==j['parent_checkpoint_sha256']
        ok=digest_ok and prefix_ok and identity_ok
        checkpoints.append(dict(path=str(cp),valid=ok,payload_digest=digest_ok,trace_prefix=prefix_ok,input_parent=identity_ok))
        result['valid'] &= ok
    result['checkpoints']=checkpoints; write(out/'summary.json',result)
    print(dict(valid=result['valid'],complete=result['complete'],counts=result['counts'],checkpoints=len(checkpoints)))
elif mode=='compare':
    result=compare(*sys.argv[2:5]); print({k:result[k] for k in ['passed','compared_events','first_divergence','first_discrete_divergence']})
else: raise ValueError(mode)
