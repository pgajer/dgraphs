"""No-solve fixed-state replay of separately certified scale witnesses."""
import argparse,ast,collections,hashlib,importlib.util,json,os,platform,subprocess,sys,textwrap,time
from fractions import Fraction as F
from pathlib import Path
import numpy as np
import scipy as sp
from scipy.stats import norm as gauss, median_abs_deviation

HERE=Path(__file__).resolve().parent

def sha(p):
 h=hashlib.sha256()
 with Path(p).open('rb') as f:
  for chunk in iter(lambda:f.read(2**20),b''):h.update(chunk)
 return h.hexdigest()
def read(p):return json.loads(Path(p).read_text())
def serial(x):
 if isinstance(x,np.ndarray):return x.tolist()
 if isinstance(x,np.generic):return x.item()
 if isinstance(x,(set,tuple)):return list(x)
 raise TypeError(type(x).__name__)
def write(p,x):Path(p).write_text(json.dumps(x,default=serial,allow_nan=False,indent=2)+'\n')
def load_exact(path):
 spec=importlib.util.spec_from_file_location('frozen_exact',path);module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module);return module

def routines(path):
 source=path.read_text();tree=ast.parse(source);keep=['getVolumeRatios','getMuStdev','computeThreshold'];nodes=[n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name in keep];assert len(nodes)==3
 scope=dict(np=np,sp=sp,gauss=gauss,median_abs_deviation=median_abs_deviation)
 exec(compile(ast.Module(body=nodes,type_ignores=[]),str(path),'exec'),scope)
 ian=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='IAN');prune=next(n for n in ian.body if isinstance(n,ast.FunctionDef) and n.name=='prune_edges')
 start=source.index('        to_be_pruned = np.flatnonzero( stats > thresh )');end=source.index('        if len(to_be_pruned) == 0:\n',start);decision_block=textwrap.dedent(source[start:end])
 tuning=next(n for n in tree.body if isinstance(n,ast.FunctionDef) and n.name=='getSigmasTuneC');predicate=next(n for n in tuning.body if isinstance(n,ast.FunctionDef) and n.name=='convergedC')
 def evaluate(state,case):
  D=np.asarray(case.get('D1',state['D1']));D2=np.asarray(state['D2']);edges=case.get('edges',state['edges']);C=case['C']
  if 'stats' in case:stats=np.asarray(case['stats']);mu=case['median']
  else:
   stats=scope['getVolumeRatios'](np.asarray(state['degrees']),D2,np.asarray(case['scales']),sig2scl=1.);mu=scope['getMuStdev'](stats[stats>0],'median')
  loc,sd,thresh,_=scope['computeThreshold'](stats[stats>0],4.5,5-(mu-1),plot=False,stdev_method='C3')
  ds=dict(np=np,stats=stats,thresh=thresh,extraVerbose=False,diffmu=mu-1,mu=mu,median_tol=.1,nonz_stats=stats[stats>0]);exec(compile(decision_block,str(path)+':decision','exec'),ds)
  candidates=np.asarray(ds['to_be_pruned'],dtype=int);selected=candidates[:max(1,int(.1*len(candidates)))];n=len(D)
  weighted={tuple(e):D[tuple(e)] for e in edges};nbr=[[] for _ in range(n)]
  for i,j in edges:nbr[i].append(j);nbr[j].append(i)
  ordered={i:collections.deque(sorted(nbr[i],key=lambda j:(D[i,j],j),reverse=True)) for i in range(n)}
  degree=np.asarray([len(v) for v in nbr]);upper=np.asarray([max((D[i,j] for j in nbr[i]),default=0.) for i in range(n)])
  ps=dict(np=np,D1=D,extraVerbose=False,debugStatsPts=[],obj='l1');exec(compile(ast.Module(body=[prune],type_ignores=[]),str(path)+':prune','exec'),ps)
  pr=ps['prune_edges'](selected,weighted,ordered,degree,upper,None,None,stats[selected],None)
  cs=dict(np=np,curr_C=C,minC=case['minC'],maxC=case['maxC'],diffmu=mu-1,median_tol=.1);exec(compile(ast.Module(body=[predicate],type_ignores=[]),str(path)+':retuning','exec'),cs)
  dec=dict(location=loc,dispersion=sd,threshold=thresh,raw_threshold=loc+4.5*sd,floored_threshold=max(2.75,loc+4.5*sd),cap=5-(mu-1),stats=stats,candidates=candidates,threshold_margins=stats-thresh,median_residual=mu-1)
  return dict(name=case['name'],ratios=stats,median=mu,retune_stop=bool(cs['convergedC']()),decision=dec,selected=selected,removed=pr[0],remaining_edges=sorted(pr[2]))
 return evaluate,{'functions':keep+['IAN.prune_edges','getSigmasTuneC.convergedC'],'decision_block_sha256':hashlib.sha256(decision_block.encode()).hexdigest()}

def main():
 p=argparse.ArgumentParser();p.add_argument('--legacy',type=Path,required=True);p.add_argument('--worker',type=Path,required=True);p.add_argument('--original-source',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
 started=time.perf_counter();trace=a.worker/'phase07f/ladder-v1/helix_1000/evaluated/child/trace.jsonl';root=a.worker/'phase07i';exact=load_exact(a.legacy/'phase07i/exact.py')
 e=read(root/'original.json');bounds=read(root/'bounds.json');saved=read(root/'saved-direction.json');schedule=read(root/'schedule.json');T=F(schedule['bands'][0]['T']);L=exact.decode(bounds['L']);witnesses={'certified_highs':list(map(exact.decode,bounds['q'])),'certified_clarabel':list(map(exact.decode,saved['clarabel_feasible_point']))}
 # Only documented arithmetic function bodies are executed. No solver modules or executables are loaded.
 for forbidden in ['clarabel','cvxpy']:assert forbidden not in sys.modules
 state={};raw=None;rawvol=None;raweval=None;last_accepted=None;actual=None;actualeval=None
 with trace.open() as f:
  for number,line in enumerate(f,1):
   x=json.loads(line);event=x['event']
   if event=='mapping':state['mapping']=x
   if event=='processed':state.update({k:x[k] for k in ['D1','D2','scl']});state['edges']=x['initial_edges']
   if event=='iteration':state.update({k:x[k] for k in ['degrees','upper']});assert x['iteration']==0
   if event=='solve' and x.get('accepted'):last_accepted=x
   if event=='solve' and x['number']==25:raw=x;state['solve_line_1based']=number
   if raw is not None and rawvol is None and event=='volume':rawvol=x
   if event=='retune_eval':
    lasteval=x
    if raw is not None and raweval is None:raweval=x
   if event=='decision':actual={'decision':x,'solve':last_accepted};actualeval=lasteval
   if event=='pruned':actual['pruned']=x;break
 assert raw and rawvol and raweval and actual and actualeval
 for k in ['A_data','A_indices','A_indptr','A_shape','b','c','upper','active','scales','C']:assert raw[k]==e[k],k
 assert state['upper']==e['upper'] and state['degrees']==rawvol['degrees']
 state.update(C=e['C'],minC=raweval['minC'],maxC=raweval['maxC'],iteration=0,phase='initial',interpretation='Conditional pruning at an intermediate retuning solve; not an executed next pruning step')
 A=exact.rows(e);b=exact.vector(e['b']);c=exact.vector(e['c']);u=exact.vector(e['upper']);cert=[];cases=[]
 for name,x in witnesses.items():
  assert exact.feasible(A,b,x,u) and exact.objective(c,x)<=T
  rounded=list(map(float,x));xr=list(map(F,rounded));viol=exact.violations(A,b,xr)
  cert.append(dict(name=name,exact_feasible=True,exact_objective=exact.encode(exact.objective(c,x)),exact_objective_above_L=exact.encode(exact.objective(c,x)-L),exact_band_slack=exact.encode(T-exact.objective(c,x)),conversion='nearest binary64 per coordinate, no repair',maximum_rounding_error=float(max(abs(z-v) for z,v in zip(xr,x))),rounded_exact_feasible=exact.feasible(A,b,xr,u),rounded_maximum_positive_row_violation=float(max([F(0)]+viol)),rounded_objective_band_excess=float(max(F(0),exact.objective(c,xr)-T))))
  cases.append(dict(name=name,scales=rounded,C=state['C'],minC=state['minC'],maxC=state['maxC']))
 cases.append(dict(name='raw_solve25_control',scales=e['scales'],C=e['C'],minC=state['minC'],maxC=state['maxC']))
 cases.append(dict(name='actual_first_prune_control',scales=actual['solve']['scales'],C=actual['solve']['C'],minC=actualeval['minC'],maxC=actualeval['maxC']))
 stagespath=a.worker/'phase05/fixtures-v1/stage-probes.json';stages=read(stagespath)['cases'];assert len(stages)==6
 for row in stages:cases.append(dict(**row,C=.55,minC=.5,maxC=1.))
 inp=dict(**state,cases=cases);write(out/'input.json',inp);write(out/'exact-witness-checks.json',cert);write(out/'saved-controls.json',dict(volume25=rawvol,retune25=raweval,first_pruning=actual,first_pruning_retune=actualeval))
 inputs=[trace,root/'original.json',root/'bounds.json',root/'saved-direction.json',root/'schedule.json',stagespath,a.original_source,a.legacy/'phase07i/exact.py',a.legacy/'phase07e/candidate/src/numeric.hpp',a.worker/'phase03/deps/json.hpp']
 identity={str(f.resolve()):sha(f) for f in inputs};write(out/'input-manifest.json',identity)
 evaluate,extraction=routines(a.original_source);py=[evaluate(state,case) for case in cases];write(out/'python.json',dict(optimizer_calls=0,extraction=extraction,cases=py))
 command=['clang++','-std=c++17','-O2','-ffp-contract=off','-fno-fast-math','-I'+str(a.legacy/'phase07e/candidate/src'),'-I'+str(a.worker/'phase03/deps'),str(HERE/'probe.cpp'),'-o',str(out/'pruning_probe')]
 build=subprocess.run(command,capture_output=True,text=True);(out/'compile.stdout').write_text(build.stdout);(out/'compile.stderr').write_text(build.stderr);assert build.returncode==0,build.stderr
 run=subprocess.run([out/'pruning_probe',out/'input.json',out/'native.json'],capture_output=True,text=True);(out/'native.stdout').write_text(run.stdout);(out/'native.stderr').write_text(run.stderr);assert run.returncode==0,run.stderr
 native=read(out/'native.json')['cases'];checks=[]
 for x,y in zip(py,native):
  item=dict(name=x['name'],discrete_agreement=all(np.array_equal(x[k],y[k]) for k in ['retune_stop','selected','removed','remaining_edges']) and np.array_equal(x['decision']['candidates'],y['decision']['candidates']),continuous_pass=True,max_ratio_difference=float(np.max(abs(np.asarray(x['ratios'])-np.asarray(y['ratios'])))))
  for k in ['ratios','median']:item['continuous_pass'] &= bool(np.allclose(x[k],y[k],atol=1e-12,rtol=1e-12))
  for k in ['location','dispersion','threshold','raw_threshold','floored_threshold','cap','threshold_margins','median_residual']:item['continuous_pass'] &= bool(np.allclose(x['decision'][k],y['decision'][k],atol=1e-12,rtol=1e-12))
  checks.append(item)
 control=dict(solve25_volume_exact=np.array_equal(py[2]['ratios'],rawvol['ratios']),solve25_median_exact=py[2]['median']==raweval['median'],first_pruning_scales_solve_number=actual['solve']['number'],first_prune_candidates_exact=np.array_equal(py[3]['decision']['candidates'],actual['decision']['candidates']),first_prune_selected_exact=np.array_equal(py[3]['selected'],actual['pruned']['selected']),first_prune_removed_exact=np.array_equal(py[3]['removed'],actual['pruned']['removed']),first_prune_threshold_exact=py[3]['decision']['threshold']==actual['decision']['threshold'])
 def summarize(x):
  stats=np.asarray(x['ratios']);cand=list(map(int,x['decision']['candidates']));sel=list(map(int,x['selected']));threshold=x['decision']['threshold'];cut=len(sel);margin=np.asarray(x['decision']['threshold_margins'])
  return dict(name=x['name'],median=x['median'],retune_stop=x['retune_stop'],actual_next_action='prune' if x['retune_stop'] else 'continue_retuning',threshold=threshold,threshold_only_count=int(np.sum(stats>threshold)),below_1_1_count=int(np.sum((stats>0)&(stats<1.1))),final_candidate_count=len(cand),median_fallback_used=len(cand)>int(np.sum(stats>threshold)),selected_count=cut,removed_count=len(x['removed']),remaining_edge_count=len(x['remaining_edges']),minimum_absolute_threshold_margin=float(min(abs(margin))),minimum_absolute_1_1_margin=float(min(abs(stats[stats>0]-1.1))),selection_boundary_gap=float(stats[cand[cut-1]]-stats[cand[cut]]) if cut and cut<len(cand) else None,selected=sel,removed=x['removed'],coordinates={str(j):dict(profile_index_1based=j+1,profile_id=state['mapping']['profile_ids'][j],ratio=float(stats[j]),threshold_margin=float(margin[j]),candidate_rank_1based=(cand.index(j)+1 if j in cand else None),selected=j in sel) for j in [229,230,717]})
 x,y=py[:2];delta=np.asarray(y['ratios'])-np.asarray(x['ratios']);order=np.argsort(abs(delta))[-10:][::-1]
 diff=dict(maximum_absolute_scale_difference=float(max(abs(a-b) for a,b in zip(cases[0]['scales'],cases[1]['scales']))),maximum_absolute_ratio_difference=float(max(abs(delta))),ratio_changes_largest=[dict(coordinate_0based=int(j),difference=float(delta[j])) for j in order],median_difference=float(y['median']-x['median']),threshold_difference=float(y['decision']['threshold']-x['decision']['threshold']),candidate_order_equal=np.array_equal(x['decision']['candidates'],y['decision']['candidates']),selected_order_equal=np.array_equal(x['selected'],y['selected']),removed_order_equal=np.array_equal(x['removed'],y['removed']),remaining_graph_equal=np.array_equal(x['remaining_edges'],y['remaining_edges']),removed_only_highs=sorted(set(map(tuple,x['removed']))-set(map(tuple,y['removed']))),removed_only_clarabel=sorted(set(map(tuple,y['removed']))-set(map(tuple,x['removed']))))
 result=dict(study_complete=True,optimizer_calls=0,native_evaluations=len(cases),python_evaluations=len(cases),witnesses=[summarize(v) for v in py[:2]],comparison=diff,cross_implementation_checks=checks,saved_control_checks=control,all_checks_pass=all(v['discrete_agreement'] and v['continuous_pass'] for v in checks) and all(v for k,v in control.items() if k!='first_pruning_scales_solve_number'),fixed_context={k:state[k] for k in ['C','minC','maxC','iteration','phase','scl','interpretation']},limitations=['Only two certified witness endpoints, converted to binary64 for decision evaluation.','No invariance proof over the objective band or full trajectories.','Pruning is conditional at this state: both next-action predicates are reported without solving further.'],seconds=time.perf_counter()-started)
 write(out/'results.json',result)
 for f,h in identity.items():assert sha(f)==h,'Historical input changed: '+f
 write(out/'run.json',dict(command=sys.argv,cwd=str(Path.cwd()),revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),python=platform.python_version(),numpy=np.__version__,scipy=sp.__version__,platform=platform.platform(),compiler=subprocess.check_output(['clang++','--version'],text=True).splitlines()[0],compile_command=command,native_command=[str(out/'pruning_probe'),str(out/'input.json'),str(out/'native.json')],linked_libraries=subprocess.check_output(['otool','-L',out/'pruning_probe'],text=True),optimizer_calls=0,loaded_solver_modules=[k for k in ['clarabel','cvxpy'] if k in sys.modules],source_hashes={str(f):sha(f) for f in [Path(__file__),HERE/'probe.cpp',HERE.parent/'PLAN.md']},historical_inputs_unchanged=True))
 write(out/'manifest.json',{str(f.relative_to(out)):sha(f) for f in sorted(out.rglob('*')) if f.is_file()})
 print(json.dumps({k:result[k] for k in ['all_checks_pass','comparison','witnesses','saved_control_checks']},default=serial,indent=2))
 if not result['all_checks_pass']:raise SystemExit(1)
if __name__=='__main__':main()
