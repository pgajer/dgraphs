"""Freeze saved LPs and capture original canonical data without solving."""
import subprocess
import sys
from pathlib import Path
import numpy as np
import clarabel
from common import load,write,sha,events,matrix,pack,scalar_check

HERE=Path(__file__).resolve().parent;worker=Path(sys.argv[1]);out=Path(sys.argv[2]);out.mkdir(parents=True,exist_ok=False)
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
old=worker/'phase07'; cases={}
choices=[('helix120_first',old/'ladder-v1/regression_helix_120/evaluated/child/trace.jsonl',0),
    ('helix500_first',old/'ladder-v1/helix_500/evaluated/child/trace.jsonl',0),
    ('helix500_rejected',old/'ladder-v1/helix_500/evaluated/child/trace.jsonl',1),
    ('pressmat500_stress',old/'ladder-v2/pressmat_500/evaluated/child/trace.jsonl',None)]
for name,path,number in choices:
    best=None
    for index,e in enumerate(events(path)):
        if e['event']!='solve':continue
        if number is not None and e['number']==number:best=(0,e,index);break
        if number is None:
            check=scalar_check(e,e['scales'],e['dual'],e['objective'],'Solved')
            assert check['accepted']
            key=(check['normalized_primal'],-e['number'])
            if best is None or key>best[0]:best=(key,e,index)
    e=best[1];f=out/(name+'.json');write(f,e)
    cases[name]=dict(path=str(f),sha256=sha(f),source=str(path),source_sha256=sha(path),event=best[2],number=e['number'])

# The frozen adapter constructs the actual historical expression, including its SOC.
sys.path.insert(0,str(HERE.parent/'phase03'));import reference
canonical=out/'historical_canonical.json';captured=[];constructor=clarabel.DefaultSolver
class CapturedBeforeSolve(Exception):pass
def capture(P,q,A,b,cones,settings):
    assert not captured
    write(canonical,dict(**pack(A),b=b,c=q,P_nnz=P.nnz,cones=[dict(kind=type(c).__name__,dim=c.dim) for c in cones],settings=str(settings)))
    captured.append(True)
    raise CapturedBeforeSolve('intentional canonical capture; constructor and solve not called')
fixture=old/'fixtures-v1/helix_500.json'
try:
    clarabel.DefaultSolver=capture
    sys.argv=['reference.py',str(fixture),str(out/'capture-child'),'original']
    exitcode=reference.main()
finally:clarabel.DefaultSolver=constructor
assert captured and exitcode==1
trace=old/'ladder-v1/helix_500/original/child/trace.jsonl'
saved=next(e for e in events(trace) if e['event']=='solve')
j=load(canonical);A=matrix(j);n=len(saved['c']);m=len(saved['b']);C=saved['C']
assert A.shape==(m+3,n+1) and j['P_nnz']==0
assert j['cones']==[dict(kind='NonnegativeConeT',dim=m),dict(kind='SecondOrderConeT',dim=3)]
diff=A[:m,:n]-matrix(saved);projected=np.array(j['b'][:m])-A[:m,n].toarray().ravel()*(C*C)
assert diff.nnz==0 and np.allclose(projected,saved['b'],rtol=2e-14,atol=1e-12)
f=out/'historical_saved.json';write(f,saved)
cases['historical_first']=dict(path=str(canonical),sha256=sha(canonical),saved=str(f),source=str(trace),source_sha256=sha(trace),
    projection_A_exact=True,projection_b_max_absolute=float(max(abs(projected-np.array(saved['b'])))),captured_without_solver=True)
sources=worker/'phase06a/clean-v2/dependencies/Clarabel.cpp/Clarabel.rs'
paths=['src/solver/implementations/default/info.rs','src/solver/implementations/default/problemdata.rs',
    'src/solver/implementations/default/residuals.rs','src/solver/implementations/default/solution.rs','src/algebra/vecmath.rs','Cargo.toml']
wheel=Path(clarabel.__file__).parent
write(out/'manifest.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),cases=cases,
    plan_sha256=sha(HERE/'PLAN.md'),source_files={str(sources/p):sha(sources/p) for p in paths},
    clarabel_version=clarabel.__version__,python_module=str(wheel),wheel_files={str(p):sha(p) for p in wheel.glob('*') if p.is_file()},
    canonical_capture_exit=exitcode,new_solver_calls=0))
print('Four evaluated LPs and one historical canonical problem frozen; zero solver calls.')
