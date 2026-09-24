"""No-solve, cross-language tests of runtime classification helpers."""
import copy,json,math,subprocess,sys
from pathlib import Path
from support import *
sys.path.insert(0,str(HERE/'candidate'))
from retry_policy import usable_return,classify_return
root=Path(sys.argv[1]);binary=Path(sys.argv[2]);root.mkdir(parents=True,exist_ok=False)
base=dict(name='solved-valid',x=[1.,1.],z=[1.,1.],upper=[2.,2.],objective=2.,n=2,m=2,metrics=[0.]*6,status='Solved',expected=[True,False]);cases=[]
def add(name,expected,**kw):
 c=copy.deepcopy(base);c.update(name=name,expected=expected,**kw);cases.append(c)
for status in ['Solved','AlmostSolved','Unsolved','PrimalInfeasible','DualInfeasible','AlmostPrimalInfeasible','AlmostDualInfeasible','MaxIterations','MaxTime','NumericalError','InsufficientProgress','CallbackTerminated','Unknown']:
 add(status+'-valid',[status=='Solved',status=='AlmostSolved'],status=status)
 add(status+'-bad-certificate',[False,status in ['Solved','AlmostSolved']],status=status,metrics=[0,0,0,1e-6,0,0])
for status in ['Solved','AlmostSolved']:
 for label,change in [('short-primal',dict(x=[1.])),('long-primal',dict(x=[1.,1.,1.])),('short-dual',dict(z=[1.])),('long-dual',dict(z=[1.,1.,1.])),('short-upper',dict(upper=[2.])),('zero-active',dict(x=[0.,1.])),('negative-active',dict(x=[-1.,1.])),('nan-primal',dict(x=['nan',1.])),('infinite-dual',dict(z=['inf',1.])),('infinite-objective',dict(objective='inf')),('nan-upper',dict(upper=['nan',2.]))]:
  add(status+'-'+label,[False,False],status=status,**change)
 add(status+'-isolated-zero',[status=='Solved',status=='AlmostSolved'],status=status,x=[0.,1.],upper=[0.,2.])
 add(status+'-objective-mismatch',[False,False],status=status,metrics=[1e-6,0,0,0,0,0])
 for k in range(6):
  for v in ['nan','inf']:
   values=[0.]*6;values[k]=v;add(f'{status}-metric-{k}-{v}',[False,False],status=status,metrics=values)
 add(status+'-at-limits',[status=='Solved',status=='AlmostSolved'],status=status,metrics=[1e-7]*6)
 for k in [1,3,4,5]:
  values=[0.]*6;values[k]=math.nextafter(1e-7,math.inf);add(f'{status}-over-limit-{k}',[False,True],status=status,metrics=values)
write(root/'cases.json',cases)
def num(v):return float(v)
results=[]
for c in cases:
 args={k:list(map(num,c[k])) for k in ['x','z','upper','metrics']}
 usable=usable_return(args['x'],args['z'],args['upper'],num(c['objective']),c['n'],c['m'])
 result=classify_return(usable,c['status'],*args['metrics']);assert list(result)==c['expected'],c['name']
 results.append(dict(name=c['name'],accepted=result[0],retry_eligible=result[1]))
p=subprocess.run([str(binary),str(root/'cases.json')],capture_output=True,text=True)
(root/'native.stdout').write_text(p.stdout);(root/'native.stderr').write_text(p.stderr)
assert p.returncode==0,p.stderr
native=json.loads(p.stdout);assert native['cases']==results
write(root/'results.json',dict(passed=True,solver_calls=0,cases=len(cases),python=results,native=native,revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()))
print(len(cases),'cross-language eligibility cases passed; zero solves.')
