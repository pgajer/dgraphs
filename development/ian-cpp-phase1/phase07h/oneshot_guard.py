"""Versioned single-solve guard. Historical multi-solve engine guard is unchanged."""
import json,os,signal,subprocess,time
from pathlib import Path
import psutil

def write(p,v):
    p=Path(p);tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(json.dumps(v)+'\n');tmp.replace(p)
def tree_bytes(p):return sum(f.stat().st_size for f in Path(p).rglob('*') if f.is_file())
def reserve(path,budget,label):
    path=Path(path);state=json.loads(path.read_text()) if path.exists() else dict(budget=budget,reservations=[])
    assert state['budget']==budget
    if len(state['reservations'])>=budget:raise RuntimeError('invocation_budget_exhausted')
    state['reservations'].append(dict(label=label,state='reserved'));write(path,state)
def _signal_group(pid,sig):os.killpg(pid,sig)
def run(command,folder,study,wall_limit=120.,synthetic=False):
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=False);trace=folder/'child/trace.jsonl'
    env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1')
    for k in ['OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS','NUMEXPR_NUM_THREADS','RAYON_NUM_THREADS']:env[k]='1'
    assert not subprocess.check_output(['git','status','--porcelain'],text=True)
    record=dict(command=list(map(str,command)),revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cwd=os.getcwd(),wall_limit=wall_limit,expected_events=1,synthetic=synthetic,environment={k:v for k,v in env.items() if k.endswith('THREADS') or k=='PYTHONDONTWRITEBYTECODE'})
    write(folder/'command.json',record);start=time.monotonic();child=None;usage=None;reason=None;signals=[];rss=0;events=0;stop=None;killed=False;exit_code=None;exception=None
    def signal_child(sig):
        try:_signal_group(child.pid,sig);signals.append(dict(signal=int(sig),sent=True))
        except OSError as e:signals.append(dict(signal=int(sig),sent=False,error=type(e).__name__,errno=e.errno))
    try:
        with (folder/'stdout.log').open('wb') as stdout,(folder/'stderr.log').open('wb') as stderr,(folder/'samples.jsonl').open('w') as samples:
            child=subprocess.Popen(list(map(str,command)),stdout=stdout,stderr=stderr,env=env,start_new_session=True);proc=psutil.Process(child.pid);last=-1.
            write(folder/'process.json',dict(**record,pid=child.pid,state='running'))
            while True:
                now=time.monotonic();elapsed=now-start
                pid,status,u=os.wait4(child.pid,os.WNOHANG)
                if pid:exit_code=os.waitstatus_to_exitcode(status);child.returncode=exit_code;usage=u;break
                current=0
                try:procs=[proc]+proc.children(recursive=True)
                except psutil.NoSuchProcess:procs=[]
                for p in procs:
                    try:current+=p.memory_info().rss
                    except (psutil.NoSuchProcess,psutil.AccessDenied):pass
                rss=max(rss,current)
                if elapsed-last>=.1:
                    last=elapsed
                    if trace.exists():events=sum(json.loads(s).get('event')=='solve' for s in trace.read_text().splitlines() if s.endswith('}'))
                    if events>1:reason=reason or 'single_solve_contract_exceeded'
                    if tree_bytes(folder)>2*2**30:reason=reason or 'run_output_limit'
                    if tree_bytes(study)>16*2**30:reason=reason or 'study_output_limit'
                    samples.write(json.dumps(dict(seconds=elapsed,rss=current,events=events))+'\n');samples.flush()
                if current>4*2**30:reason=reason or 'rss_limit'
                if elapsed>=wall_limit:reason=reason or 'wall_limit'
                if reason and stop is None:stop=now;signal_child(signal.SIGTERM)
                if stop is not None and now-stop>=5 and not killed:killed=True;signal_child(signal.SIGKILL)
                if stop is not None and now-stop>=10:reason='unable_to_reap_after_termination';break
                time.sleep(.05)
    except Exception as e:
        exception=repr(e);reason=reason or 'supervisor_exception'
        if child is not None:
            signal_child(signal.SIGKILL)
            try:
                pid,status,usage=os.wait4(child.pid,os.WNOHANG)
                if pid:exit_code=os.waitstatus_to_exitcode(status);child.returncode=exit_code
            except OSError:pass
    finally:
        try:
            if trace.exists():events=sum(json.loads(s).get('event')=='solve' for s in trace.read_text().splitlines() if s.endswith('}'))
        except Exception as e:exception=exception or repr(e);reason=reason or 'invalid_trace'
        if events!=1:reason=reason or 'single_solve_contract_count'
        result=dict(**record,pid=child.pid if child else None,exit_code=exit_code,state='reaped' if exit_code is not None else 'unreaped',reason=reason,exception=exception,signals=signals,observed_events=events,optimizer_calls=0 if synthetic else events,wall_seconds=time.monotonic()-start,sampled_tree_peak_rss_bytes=rss,root_peak_rss_bytes=usage.ru_maxrss if usage else None,output_bytes=tree_bytes(folder))
        write(folder/'process.json',result)
    return result
