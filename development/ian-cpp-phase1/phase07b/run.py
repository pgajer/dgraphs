"""Run the 33 frozen diagnostic conditions serially with explicit resource bounds."""
import os
import json
import signal
import subprocess
import sys
import time
from pathlib import Path
import psutil
from common import load,write,sha

HERE=Path(__file__).resolve().parent;fixtures=Path(sys.argv[1]);root=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False)
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
record=dict(revision=revision,fixture_manifest_sha256=sha(fixtures/'manifest.json'),complete=False,runs=[],gated=[])
start=time.monotonic()
def save():write(root/'ledger.json',record)
conditions=['baseline','feas11','gap11','all11','all12','no_equilibration','row_normalized']
env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1')
for key in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','NUMEXPR_NUM_THREADS','RAYON_NUM_THREADS']:env[key]='1'
stop=False
for case in load(fixtures/'manifest.json')['cases']:
    case_stop=False
    for condition in conditions[:5] if case=='historical_first' else conditions:
        if stop or case_stop:
            record['gated'].append(dict(case=case,condition=condition,reason='resource_or_baseline_gate'));save();continue
        folder=root/case/condition;folder.mkdir(parents=True,exist_ok=False)
        command=[sys.executable,'-B',str(HERE/'replay.py'),str(fixtures),case,condition,str(folder/'child')]
        write(folder/'command.json',dict(command=command,cwd=os.getcwd(),revision=revision,load=os.getloadavg(),
            environment={k:v for k,v in env.items() if k.endswith('THREADS')}))
        begin=time.monotonic();reason=None;sent=None;killed=False;peak=0;threads=0
        with (folder/'stdout.log').open('wb') as stdout,(folder/'stderr.log').open('wb') as stderr,(folder/'samples.jsonl').open('w') as samples:
            p=subprocess.Popen(command,stdout=stdout,stderr=stderr,env=env,start_new_session=True);proc=psutil.Process(p.pid)
            while True:
                now=time.monotonic();pid,status,usage=os.wait4(p.pid,os.WNOHANG)
                if pid:p.returncode=os.waitstatus_to_exitcode(status);break
                rss=nthreads=0
                try:processes=[proc]+proc.children(recursive=True)
                except psutil.NoSuchProcess:processes=[]
                for child in processes:
                    try:rss+=child.memory_info().rss;nthreads+=child.num_threads()
                    except psutil.NoSuchProcess:pass
                peak=max(peak,rss);threads=max(threads,nthreads)
                samples.write(json.dumps(dict(seconds=now-begin,tree_rss_bytes=rss,threads=nthreads))+'\n')
                if rss>2**30:reason=reason or 'rss_limit'
                if now-begin>120 or now-start>1200:reason=reason or 'time_limit'
                if sum(f.stat().st_size for f in root.parent.rglob('*') if f.is_file())>4*2**30:reason=reason or 'study_output_limit'
                if reason and sent is None:
                    sent=now
                    try:os.killpg(p.pid,signal.SIGTERM)
                    except ProcessLookupError:pass
                if sent and now-sent>5 and not killed:
                    try:os.killpg(p.pid,signal.SIGKILL)
                    except ProcessLookupError:pass
                    killed=True
                time.sleep(.05)
        item=dict(case=case,condition=condition,command=command,exit_code=p.returncode,wall_seconds=time.monotonic()-begin,
            sampled_tree_peak_rss_bytes=peak,root_peak_rss_bytes=usage.ru_maxrss,max_threads=threads,reason=reason,sigkill_sent=killed)
        if (folder/'child/result.json').exists():item['result']=load(folder/'child/result.json')
        record['runs'].append(item);write(folder/'process.json',{k:v for k,v in item.items() if k!='result'});save()
        if reason:stop=True
        if p.returncode!=0:case_stop=True
        print(case,condition,p.returncode,item.get('result',{}).get('external',{}).get('normalized_primal'),flush=True)
record['complete']=True;record['elapsed_seconds']=time.monotonic()-start;save()
