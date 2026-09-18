import shutil,importlib.metadata,inspect
from scipy.optimize._highspy import _core as h
import scipy.optimize._highspy._highs_wrapper as wrapper
import scipy.optimize._linprog_highs as lpwrap
from support import *
root=Path(sys.argv[1]).resolve();root.mkdir(parents=True,exist_ok=False)
old=WORKER/'phase07g/fixtures';shutil.copytree(old,root/'fixtures')
for name,digest in load(old/'manifest.json').items():assert sha(root/'fixtures'/name)==digest
solver=h._Highs();solver.setOptionValue('output_flag',False);options=dict(solver='simplex',presolve='off',parallel='off',threads=1,simplex_strategy=1,simplex_scale_strategy=0,random_seed=0,small_matrix_value=1e-12,primal_feasibility_tolerance=1e-10,dual_feasibility_tolerance=1e-10,simplex_iteration_limit=100000,time_limit=60.,simplex_dual_edge_weight_strategy=-1)
checks={}
for k,v in options.items():assert solver.setOptionValue(k,v)==h.HighsStatus.kOk;assert solver.getOptionValue(k)[1]==v;checks[k]=v
rejected=solver.setOptionValue('primal_feasibility_tolerance',1e-11);assert rejected==h.HighsStatus.kError;assert solver.getOptionValue('primal_feasibility_tolerance')[1]==1e-10
magnitudes={}
for label in ['native','python']:
 A,b,c=read_arrays(root/'fixtures'/label);magnitudes[label]=float(min(abs(A.data)));assert magnitudes[label]>options['small_matrix_value']
# min x, -x<=-1 has x=1, marginal=-1, positive multiplier z=1.
e=dict(A_data=[-1.],A_indices=[0],A_indptr=[0,1],A_shape=[1,1],b=[-1.],c=[1.],active=[True])
assert scalar_check(e,[1.],[1.],1.,'Solved')['accepted'];assert not scalar_check(e,[1.],[-1.],1.,'Solved')['accepted']
files=[Path(h.__file__),Path(inspect.getsourcefile(wrapper)),Path(inspect.getsourcefile(lpwrap))]
write(root/'preflight.json',dict(passed=True,optimizer_calls=0,highs_version=solver.version(),options_accepted=checks,tolerance_1e11_rejected=str(rejected),minimum_matrix_magnitude=magnitudes,dual_sign_control=True,packages={n:importlib.metadata.version(n) for n in ['scipy','numpy']},backend_files={str(p):sha(p) for p in files},documentation=['https://docs.scipy.org/doc/scipy-1.15.3/reference/optimize.linprog-highs-ds.html','https://ergo-code.github.io/HiGHS/dev/options/definitions/']))
