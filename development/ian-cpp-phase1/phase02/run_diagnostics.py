"""Six prespecified one-factor diagnostic solves, serial, separately labeled."""
import argparse,json,os,sys
from pathlib import Path
from supervise import supervise
p=argparse.ArgumentParser();p.add_argument('--fixtures',required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
conditions=[('original','auto',0),('original','auto',1),('original','qdldl',1),('saved','auto',1),('saved','qdldl',1),('evaluated','auto',1)]
(a.output/'schedule.json').write_text(json.dumps(conditions,indent=2)+'\n')
# Same ambient environment for all diagnostics; solver max_threads is the only
# thread-control factor changed. Native thread telemetry is saved before solving.
for i,(expr,backend,nt) in enumerate(conditions):
    folder=a.output/f'{i:02d}-{expr}-{backend}-{nt}'
    cmd=[sys.executable,str(Path(__file__).with_name('diagnostic.py')),'--fixtures',a.fixtures,'--output',str(folder/'child'),'--expression',expr,'--backend',backend,'--threads',str(nt)]
    result=supervise(cmd,folder,dict(os.environ,PYTHONDONTWRITEBYTECODE='1'))
    print(f'{i+1}/6 {expr} {backend} threads={nt} exit={result["exit_code"]} wall={result["end_to_end_seconds"]:.3f}',flush=True)
