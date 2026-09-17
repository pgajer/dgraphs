"""One supervised child; exact exit timing and common resident-memory convention."""
import json,os,subprocess,threading,time,sys
from pathlib import Path
import psutil
import numpy as np
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import write_json

def supervise(command,folder,env=None):
    folder=Path(folder);folder.mkdir(parents=True,exist_ok=False)
    record=dict(command=command,cwd=os.getcwd(),revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),load_before=os.getloadavg())
    write_json(folder/'launch.json',record)
    samples=[];peak=0;threads_max=0;processes_max=0;stop=threading.Event();psutil.cpu_percent(None)
    with (folder/'stdout.log').open('w') as stdout,(folder/'stderr.log').open('w') as stderr:
        start=time.perf_counter();child=subprocess.Popen(command,env=env,stdout=stdout,stderr=stderr);proc=psutil.Process(child.pid)
        def sample():
            nonlocal peak,threads_max,processes_max
            while not stop.is_set():
                try:tree=[proc]+proc.children(recursive=True)
                except psutil.Error:tree=[]
                rss=0;nt=0
                for process in tree:
                    try:rss+=process.memory_info().rss;nt+=process.num_threads()
                    except psutil.Error:pass
                peak=max(peak,rss);threads_max=max(threads_max,nt);processes_max=max(processes_max,len(tree))
                samples.append([time.perf_counter()-start,rss,nt]);stop.wait(.02)
        thread=threading.Thread(target=sample);thread.start()
        _,status,usage=os.wait4(child.pid,0);child.returncode=os.waitstatus_to_exitcode(status)
        wall=time.perf_counter()-start;stop.set();thread.join()
    record.update(exit_code=child.returncode,end_to_end_seconds=wall,root_peak_rss_bytes=int(usage.ru_maxrss*(1 if sys.platform=='darwin' else 1024)),
      sampled_tree_peak_rss_bytes=peak,sampled_max_threads=threads_max,sampled_max_processes=processes_max,
      system_cpu_percent=psutil.cpu_percent(None),load_after=os.getloadavg(),sampling_seconds=.02)
    np.savetxt(folder/'resource-samples.tsv',samples,delimiter='\t',header='seconds\trss_bytes\tthreads')
    write_json(folder/'process.json',record);return record

def one_thread_environment():
    return dict(os.environ,PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',VECLIB_MAXIMUM_THREADS='1',NUMEXPR_NUM_THREADS='1',RAYON_NUM_THREADS='1')
