import shutil,subprocess,importlib.metadata,platform
import clarabel,cvxpy as cp
from support import *
root=Path(sys.argv[1]);root.mkdir(parents=True,exist_ok=False);fixtures=root/'fixtures';fixtures.mkdir();checks={}
for label,name in [('native','helix_1000-native-terminal-problem.json'),('python','matched-python-terminal-problem.json')]:
    source=WORKER/'phase07f/analysis-v1'/name;out=fixtures/label;out.mkdir();shutil.copyfile(source,out/'original.json');e=load(source);A=matrix(e);b=np.array(e['b']);c=np.array(e['c']);alpha=max(e['upper']);rhs=b/alpha
    assert alpha==e['solver_units'] and rhs.tolist()==e['backend_rhs']
    y=cp.Variable(len(c));problem=cp.Problem(cp.Minimize(c@y),[A@y<=b]);data=problem.get_problem_data(cp.CLARABEL)[0]
    assert data['dims'].nonneg==len(b) and data['dims'].zero==0 and not data['dims'].soc
    canonical=out/'canonical';canonical.mkdir();dump_arrays(canonical,data['A'],data['b']/alpha,data['c']);dump_arrays(out,A,rhs,c)
    assert load(canonical/'arrays.json')==load(out/'arrays.json')
    write(out/'origin.json',dict(source=str(source),sha256=sha(source),alpha=alpha,tolerance=e['solver_tolerance']))
    checks[label+'_canonical_exact']=True
n=load(fixtures/'native/original.json');p=load(fixtures/'python/original.json');bn=np.array(n['b']);bp=np.array(p['b']);assert np.flatnonzero(bn!=bp).tolist()==[882];assert np.nextafter(bn[882],np.inf)==bp[882]
A,b,c=read_arrays(fixtures/'native');original=(fixtures/'native/A_data.bin').read_bytes();v=A.data.copy();v[0]=np.nextafter(v[0],np.inf);checks['one_step_detected']=v.astype('<f8').tobytes()!=original
v=A.indices.copy();v[0]+=1;checks['index_change_detected']=v.astype('<u8').tobytes()!=(fixtures/'native/A_rows.bin').read_bytes()
checks['status_separate']=not scalar_check(n,n['scales'],n['dual'],n['objective'],'AlmostSolved')['accepted'] and scalar_check(n,n['scales'],n['dual'],n['objective'],'Solved')['accepted'];assert all(checks.values())
write(root/'preflight.json',dict(checks=checks,solver_calls=0,passed=True))
deps=WORKER/'phase06a/clean-v2/dependencies/Clarabel.cpp';native=WORKER/'phase06a/clean-v2/prefix/lib/libclarabel_c.dylib'
modules={str(p):sha(p) for p in Path(clarabel.__file__).parent.rglob('*') if p.is_file() and p.suffix in ['.so','.py']}
files=[deps/'rust_wrapper/Cargo.lock',deps/'rust_wrapper/Cargo.toml',deps/'include/c/DefaultSettings.h',deps/'Clarabel.rs/src/solver/implementations/default/ffi/settings.rs',native,WORKER/'phase07e/build-v1/ian_engine']
write(root/'environment.json',dict(python=sys.version,platform=platform.platform(),packages={n:importlib.metadata.version(n) for n in ['numpy','scipy','cvxpy','clarabel']},python_modules=modules,files={str(p):sha(p) for p in files},dependency_heads={str(d):subprocess.check_output(['git','-C',str(d),'rev-parse','HEAD'],text=True).strip() for d in [deps,deps/'Clarabel.rs']},compiler=subprocess.check_output(['clang++','--version'],text=True),python_wheel=importlib.metadata.distribution('clarabel').read_text('WHEEL'),options=OPTIONS))
with (root/'python-buildinfo.txt').open('w') as f:subprocess.run([sys.executable,'-c','import clarabel; clarabel.buildinfo()'],stdout=f,stderr=subprocess.STDOUT,check=True)
write(fixtures/'manifest.json',{str(p.relative_to(fixtures)):sha(p) for p in fixtures.rglob('*') if p.is_file()})
