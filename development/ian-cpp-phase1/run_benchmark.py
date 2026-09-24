"""Serial fresh-process repetitions with common memory accounting and validation."""
import argparse,json,os,platform,subprocess,sys,time,threading
from pathlib import Path
import numpy as np
import psutil
from common import sha,load_lp,validate,dual_diagnostics,write_json,OPTIONS
p=argparse.ArgumentParser();p.add_argument('--fixtures',type=Path,required=True);p.add_argument('--native',type=Path,required=True)
p.add_argument('--output',type=Path,required=True);p.add_argument('--smoke',action='store_true');args=p.parse_args()
args.output.mkdir(parents=True,exist_ok=False)
revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
status=subprocess.check_output(['git','status','--porcelain'],text=True)
if status: raise RuntimeError('Commit all source before running')
manifest=json.loads((args.fixtures/'manifest.json').read_text());cases=[c['label'] for c in manifest['cases']]
env=dict(os.environ,PYTHONDONTWRITEBYTECODE='1',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',MKL_NUM_THREADS='1',VECLIB_MAXIMUM_THREADS='1',NUMEXPR_NUM_THREADS='1',RAYON_NUM_THREADS='1')
write_json(args.output/'environment.json',dict(revision=revision,cwd=os.getcwd(),python=sys.version,platform=platform.platform(),machine=platform.machine(),
    cpu_count=psutil.cpu_count(),physical_cpu_count=psutil.cpu_count(logical=False),memory=psutil.virtual_memory()._asdict(),
    manifest_sha256=sha(args.fixtures/'manifest.json'),native_sha256=sha(args.native),options=OPTIONS,
    thread_environment={k:v for k,v in env.items() if k.endswith('THREADS')},
    pip_freeze=subprocess.check_output([sys.executable,'-m','pip','freeze'],text=True),
    hardware=subprocess.check_output(['system_profiler','SPHardwareDataType'],text=True),
    memory_convention='10 ms sampled sum of RSS of child and recursive descendants; excludes harness; MiB=2^20 bytes; lower bound on peak'))
order=[]
for rep in range(1 if args.smoke else 3):
    ordered=cases[2*rep:]+cases[:2*rep]
    if args.smoke: ordered=cases[:1]
    for pos,case in enumerate(ordered):
        for backend in (['python','native'] if (rep+pos)%2==0 else ['native','python']): order.append((rep,case,backend))
write_json(args.output/'schedule.json',order)
for seq,(rep,case,backend) in enumerate(order):
    run=args.output/f'{seq:02d}-{case}-{backend}-r{rep+1}';run.mkdir();prefix=run/'result'
    fixture=args.fixtures/case/'problem.bin'
    expected=next(c['binary_sha256'] for c in manifest['cases'] if c['label']==case)
    assert sha(fixture)==expected
    cmd=([sys.executable,str(Path(__file__).with_name('python_replay.py'))] if backend=='python' else [str(args.native)])+[str(fixture),str(prefix)]
    load_before=os.getloadavg();psutil.cpu_percent(interval=None)
    started=time.perf_counter();peak=0;max_threads=0;max_processes=0;samples=[]
    with (run/'stdout.log').open('w') as stdout,(run/'stderr.log').open('w') as stderr:
        child=subprocess.Popen(cmd,env=env,stdout=stdout,stderr=stderr);proc=psutil.Process(child.pid)
        stop=threading.Event()
        def sample():
          global peak,max_threads,max_processes
          while not stop.is_set():
            rss=0;threads=0
            try: tree=[proc]+proc.children(recursive=True)
            except psutil.Error: tree=[]
            max_processes=max(max_processes,len(tree))
            for item in tree:
                try: rss+=item.memory_info().rss;threads+=item.num_threads()
                except psutil.Error: pass
            peak=max(peak,rss);max_threads=max(max_threads,threads)
            samples.append([time.perf_counter()-started,rss,threads]);stop.wait(.01)
        sampler=threading.Thread(target=sample);sampler.start()
        _,wait_status,usage=os.wait4(child.pid,0)
        code=os.waitstatus_to_exitcode(wait_status);child.returncode=code
        wall=time.perf_counter()-started
        stop.set();sampler.join()
    cpu=psutil.cpu_percent(interval=None)
    measurement=dict(sequence=seq,case=case,backend=backend,repetition=rep+1,source_revision=revision,
        command=cmd,cwd=os.getcwd(),exit_code=code,end_to_end_seconds=wall,peak_tree_rss_bytes=peak,
        root_peak_rss_bytes=int(usage.ru_maxrss*(1 if sys.platform=="darwin" else 1024)),
        max_observed_tree_processes=max_processes,peak_tree_threads=max_threads,load_before=load_before,load_after=os.getloadavg(),system_cpu_percent=cpu,
        sample_count=len(samples),fixture_sha256=expected,smoke=args.smoke)
    np.savetxt(run/'resource-samples.tsv',samples,delimiter='\t',header='seconds\trss_bytes\tthreads')
    validation_start=time.perf_counter()
    try:
        result=json.loads(prefix.with_suffix('.json').read_text());d=load_lp(fixture)
        x=np.fromfile(str(prefix)+'.x.bin',dtype='<f8');z=np.fromfile(str(prefix)+'.z.bin',dtype='<f8')
        check=validate(d,x,result['objective'],result['status']);dual=dual_diagnostics(d,x,z)
        old=np.load(args.fixtures/case/'historical.npz')['scales']
        result.update(validation=check,dual_diagnostics=dual,scale_historical_max_abs=float(abs(x-old).max()),
            scale_historical_relative_l2=float(np.linalg.norm(x-old)/max(1,np.linalg.norm(old))))
        measurement.update(result=result,accepted=bool(code==0 and check['accepted']))
    except Exception as exc: measurement.update(accepted=False,result_error=repr(exc))
    measurement['external_validation_seconds']=time.perf_counter()-validation_start
    write_json(run/'measurement.json',measurement)
    print(f'{seq+1}/{len(order)} {case} {backend} r{rep+1}: accepted={measurement["accepted"]} wall={wall:.3f}s RSS={peak/2**20:.1f}MiB',flush=True)
