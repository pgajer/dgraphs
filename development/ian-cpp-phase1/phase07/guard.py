"""Bounded serial child supervisor; limits are sampled, not hard OS quotas."""
import json
import os
import re
import signal
import subprocess
import time
from pathlib import Path
import psutil
from checks import write

def tree_bytes(root): return sum(f.stat().st_size for f in Path(root).rglob('*') if f.is_file())

def run(command,folder,study,remaining_wall=900.,remaining_solves=10000):
    folder=Path(folder); folder.mkdir(parents=True,exist_ok=False)
    env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1')
    for k in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','NUMEXPR_NUM_THREADS','RAYON_NUM_THREADS']: env[k]='1'
    revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
    assert not subprocess.check_output(['git','status','--porcelain'],text=True)
    write(folder/'command.json',dict(command=list(map(str,command)),cwd=os.getcwd(),revision=revision,
        environment={k:v for k,v in env.items() if k.endswith('THREADS') or k=='PYTHONDONTWRITEBYTECODE'},
        load_average=os.getloadavg(),wall_limit_seconds=min(900.,remaining_wall),solve_limit=remaining_solves))
    start=time.monotonic(); reason=None; killed=False; rss=0; threads=0; solves=0; last_scan=-2.; offset=0; buffer=b''; output_bytes=0
    trace=folder/'child/trace.jsonl'
    with (folder/'stdout.log').open('wb') as stdout,(folder/'stderr.log').open('wb') as stderr,(folder/'samples.jsonl').open('w') as samples:
        child=subprocess.Popen(list(map(str,command)),stdout=stdout,stderr=stderr,env=env,start_new_session=True)
        process=psutil.Process(child.pid); stop_at=None
        while True:
            now=time.monotonic(); elapsed=now-start
            pid,status,usage=os.wait4(child.pid,os.WNOHANG)
            if pid:
                child.returncode=os.waitstatus_to_exitcode(status); break
            procs=[]
            try: procs=[process]+process.children(recursive=True)
            except psutil.NoSuchProcess: pass
            current=0; nth=0
            for proc in procs:
                try: current+=proc.memory_info().rss; nth+=proc.num_threads()
                except psutil.NoSuchProcess: pass
            rss=max(rss,current); threads=max(threads,nth)
            if elapsed-last_scan>=1:
                last_scan=elapsed
                if trace.exists():
                    with trace.open('rb') as f: f.seek(offset); chunk=f.read(); offset=f.tell()
                    pieces=(buffer+chunk).split(b'\n'); buffer=pieces.pop()
                    solves+=sum(bool(re.search(rb'"event"\s*:\s*"solve"',s)) for s in pieces)
                output_bytes=tree_bytes(folder)
                if output_bytes>2*2**30: reason=reason or 'run_output_limit'
                if tree_bytes(study)>16*2**30: reason=reason or 'study_output_limit'
                samples.write(json.dumps(dict(seconds=elapsed,tree_rss_bytes=current,threads=nth,observed_solves=solves,output_bytes=output_bytes))+'\n');samples.flush()
            if current>4*2**30: reason=reason or 'rss_limit'
            if elapsed>=min(900.,remaining_wall): reason=reason or 'wall_limit'
            if solves>=remaining_solves: reason=reason or 'study_solve_limit'
            if reason and stop_at is None:
                stop_at=now
                try: os.killpg(child.pid,signal.SIGTERM)
                except ProcessLookupError: pass
            if stop_at and now-stop_at>=5 and not killed:
                try: os.killpg(child.pid,signal.SIGKILL)
                except ProcessLookupError: pass
                killed=True
            time.sleep(.05)
    if trace.exists():
        with trace.open('rb') as f:
            solves=sum(line.endswith(b'\n') and bool(re.search(rb'"event"\s*:\s*"solve"',line)) for line in f)
    result=dict(command=list(map(str,command)),revision=revision,exit_code=child.returncode,
        wall_seconds=time.monotonic()-start,sampled_tree_peak_rss_bytes=rss,root_peak_rss_bytes=usage.ru_maxrss,
        max_tree_threads=threads,reason=reason,sigkill_sent=killed,observed_solves=solves,
        output_bytes=tree_bytes(folder),rss_convention='50 ms sampled process-tree RSS; Darwin wait4 root peak separately',load_average_end=os.getloadavg())
    write(folder/'process.json',result); return result
