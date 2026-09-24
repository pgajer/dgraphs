"""Executed pinned IAN/adapter with observation hooks and two solve representations."""
import argparse,ast,hashlib,importlib.util,json,os,sys,time,traceback,types
from pathlib import Path
import numpy as np
import scipy as sp
from scipy import sparse
import cvxpy as cp
import clarabel
from cvxpy.reductions.solvers.conic_solvers.clarabel_conif import dims_to_solver_cones
FROZEN=Path('/Users/pgajer/.codex/private/ZB/exp038-full-cohorts/20260916-175755/source')
CYTHON=Path('/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry/build/venv/lib/python3.12/site-packages/ian/cutils.cpython-312-darwin.so')
POLICY='IAN evaluated-LP retry units11 0.1'
OPTIONS=dict(tol_gap_abs=1e-9,tol_gap_rel=1e-9,tol_feas=1e-9,max_iter=300,direct_solve_method='qdldl',max_threads=1,presolve_enable=False,chordal_decomposition_enable=False,input_sparse_dropzeros=False)
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def serial(x):
 if isinstance(x,np.ndarray):return x.tolist()
 if isinstance(x,np.generic):return x.item()
 if isinstance(x,(set,tuple)):return list(x)
 raise TypeError(type(x).__name__)
def write(p,d):Path(p).write_text(json.dumps(d,default=serial,allow_nan=False)+'\n')
def load(name,path):
 spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
def components(n,edges):
 labels=[-1]*n;neighbors=[[] for _ in range(n)]
 for i,j in edges:neighbors[i].append(j);neighbors[j].append(i)
 for i in range(n):
  if labels[i]>=0:continue
  lab=max(labels)+1;labels[i]=lab;q=[i]
  for v in q:
   for j in neighbors[v]:
    if labels[j]<0:labels[j]=lab;q.append(j)
 return labels
def preprocess(d):
 X=np.asarray(d['features'],dtype=float);D=np.asarray(d['distances'],dtype=float);ids=d['ids']
 if X.ndim!=2 or D.shape!=(len(X),len(X)) or len(ids)!=len(X) or len(set(ids))!=len(ids):raise ValueError('input_shape_or_identity')
 if not np.isfinite(X).all() or not np.isfinite(D).all() or np.any(D<0) or not np.array_equal(D,D.T) or np.any(np.diag(D)!=0):raise ValueError('invalid_distances_or_features')
 lookup={};reps=[];mapping=[]
 for i,row in enumerate(X):
  key=tuple(row)
  if key not in lookup:lookup[key]=len(reps);reps.append(i)
  mapping.append(lookup[key])
 mapping=np.asarray(mapping);reps=np.asarray(reps)
 U=D[np.ix_(reps,reps)]
 if not np.array_equal(D,U[np.ix_(mapping,mapping)]):raise ValueError('duplicate_distance_inconsistency')
 if len(reps)<2:raise ValueError('fewer_than_two_unique_profiles')
 if np.isclose(U[np.triu_indices(len(U),1)].min(),0):raise ValueError('nearly_identical_distinct_profiles')
 return U,dict(representatives=reps,member_to_profile=mapping,specimen_ids=ids,profile_ids=[ids[i] for i in reps])

class Recorder:
 def __init__(self,folder,condition,metadata):
  self.folder=folder;self.condition=condition;self.metadata=metadata;self.solves=0;self.phase='initial';self.it=0;self.degrees=None;self.converged=False;self.retune_caps=0;self.C=None;self.edges=[];self.upper=[];self.scl=1
  self.stream=(folder/'trace.jsonl').open('w');self.status=dict(graph=False,scales=False,affinity=False,complete=False,error=None)
 def emit(self,d):
  d=dict(iteration=self.it,phase=self.phase,**d) if 'iteration' not in d and 'phase' not in d else d
  self.stream.write(json.dumps(d,default=serial,allow_nan=False)+'\n');self.stream.flush()
 def checkpoint(self,stage,data):
  target=self.folder/(stage+'.json');payload=dict(stage=stage,status='validated',**self.metadata,**data)
  tmp=target.with_suffix('.tmp')
  with tmp.open('w') as f:f.write(json.dumps(payload,default=serial,allow_nan=False)+'\n');f.flush();os.fsync(f.fileno())
  os.replace(tmp,target);self.status[stage]=True
  self.status[stage+'_sha256']=sha(target)
 def graph_data(self):return dict(edges=self.edges,degrees=self.degrees,upper=self.upper,components=components(len(self.degrees),self.edges),isolates=np.flatnonzero(np.asarray(self.degrees)==0))

def make_reference(folder,condition,metadata):
 audit=load('frozen_audit',FROZEN/'scripts/pilot_audit.py');generate=load('frozen_prepare',FROZEN/'scripts/prepare_ian_adapter.py')
 generated=generate.prepare(folder/'source');text=generated.read_text()
 state=Recorder(folder,condition,metadata);audit.STATE=state;audit.OPTIONS=OPTIONS
 original_register=audit.register;validator=audit.validate
 def iteration(it,wA,degrees,scl,upper):
  state.it=int(it);state.phase='initial' if it==0 else 'post_prune';state.scl=float(scl);state.edges=sorted(wA);state.degrees=degrees.copy();state.upper=upper.copy();state.emit(dict(event='iteration',**state.graph_data(),scl=scl))
 def processed(Adj,D1,D2,scl):
  degree=np.asarray(Adj.sum(axis=1)).ravel()
  state.emit(dict(event='processed',D1=D1,D2=D2,scl=scl,initial_edges=np.column_stack(sparse.triu(Adj,k=1).nonzero())))
  if np.any(degree==0):raise ValueError('unsupported_initial_isolate')
 def begin(C,use_wG,weighted_edges,upper,cinfo):
  if use_wG:state.phase='final_affinity_retuning'
  state.C=float(C);state.edges=sorted(weighted_edges);state.upper=upper.copy()
  state.emit(dict(event='tune_start',C=C,minC=min(C,.5),maxC=max(C,1),recycled=cinfo is not None,**state.graph_data()))
 def solve(prob,x,site,u=None,cinfo=None,c=None):
  if site=='recycled':
   add=cinfo['us']*u[cinfo['idxsJ']]+cinfo['u_1s']*cinfo['u_tilde'][cinfo['idxsI']]
   ii,jj=cinfo['idxsI'],cinfo['idxsJ'];slopes=add*cinfo['slopes'];b=cinfo['b1']*add+cinfo['b2'];C=state.C
  else:
   ii,jj,base,C1,Cm1,b1,C2,C0,b2,u,c,Cp,Ct=audit.PARAMETERS[x.id]
   C=float(Cp.value);slopes=base*(C* C1+Ct.value*Cm1);b=b1*(C**2*C2+C0)+b2*C
  A,b=audit.inequalities(len(u),ii,jj,slopes,b,u);active=np.asarray(state.degrees)>0
  if np.any((u==0)&active) or np.any((u>0)&~active):raise audit.InvalidSolve('adjacency_bounds_mismatch')
  if condition=='evaluated':
   y=cp.Variable(len(u));prob=cp.Problem(cp.Minimize(c@y),[A@y<=b])
  logical=state.solves
  for attempt,tolerance in enumerate([1e-9,1e-11]):
   t=time.perf_counter();data,chain,inverse=prob.get_problem_data(cp.CLARABEL)
   settings=clarabel.DefaultSettings()
   for k,v in OPTIONS.items():setattr(settings,k,v)
   settings.tol_feas=settings.tol_gap_abs=settings.tol_gap_rel=tolerance
   settings.verbose=False
   alpha=float(max(u)) if attempt else 1.
   assert np.isfinite(alpha) and alpha>0,'invalid_retry_units'
   rhs=data['b']/alpha if attempt else data['b']
   solver=clarabel.DefaultSolver(sparse.csc_matrix((len(data['c']),len(data['c']))),data['c'],data['A'],rhs,dims_to_solver_cones(data['dims']),settings)
   raw=solver.solve();status='optimal' if str(raw.status)=='Solved' else 'not_optimal'
   scales=np.array(raw.x[:len(u)])*alpha;z=np.array(raw.z[:len(b)])
   objective=float(raw.obj_val)*alpha
   backend=dict(solver_units=alpha,backend_rhs=rhs,backend_primal=raw.x,backend_dual=raw.z,backend_slack=raw.s,backend_objective=raw.obj_val,backend_res_primal=raw.r_prim,backend_res_dual=raw.r_dual) if attempt else {}
   report,_,_=validator(status,scales,objective,A,b,c,active,u)
   dual=dict(stationarity=float(abs(c+A.T@z).max()),negative=float(np.maximum(-z,0).max(initial=0)),relative_gap=float(abs(c@scales+b@z)/max(1,abs(c@scales),abs(b@z))))
   accepted=report['accepted'] and all(np.isfinite(v) and v<=1e-7 for v in dual.values())
   eligible=(not accepted and status=='optimal' and np.isfinite(scales).all() and np.isfinite(z).all() and np.isfinite(raw.obj_val)
     and bool(np.all(scales[active]>0)) and report['objective_relative_error']<=1e-7
     and all(np.isfinite(report[k]) for k in ['objective_relative_error','max_normalized_violation','max_absolute_violation'])
     and all(np.isfinite(v) for v in dual.values()))
   state.C=C;state.emit(dict(event='solve',number=state.solves,logical_solve=logical,attempt=attempt,numerical_policy=POLICY,solver_tolerance=tolerance,retry_eligible=bool(eligible),site=site,C=C,A_data=A.data,A_indices=A.indices,A_indptr=A.indptr,A_shape=A.shape,b=b,c=c,upper=u,active=active.astype(int),scales=scales,dual=z,status=status,solver_status=str(raw.status),objective=objective,iterations=raw.iterations,seconds=time.perf_counter()-t,accepted=bool(accepted),validation=report,dual_check=dual,canonical_shape=data['A'].shape,canonical_soc=data['dims'].soc,**backend))
   state.solves+=1
   if accepted:
    x.value=scales
    return objective
   if attempt:raise audit.InvalidSolve('retry_exhausted')
   if not eligible:raise audit.InvalidSolve('invalid_solver_result')

 def evaluation(C,mu,minC,maxC,nits):
  state.emit(dict(event='retune_eval',C=C,median=mu,minC=minC,maxC=maxC,bisection_index=nits,median_margin=abs(mu-1)-.1,lower_margin=abs(C-minC)-(1e-8+1e-5*abs(minC)),upper_margin=abs(C-maxC)-(1e-8+1e-5*abs(maxC))))
 def tuning(C,mu,minC,maxC,tol,nits):
  centered=abs(mu-1)<=tol;boundary=(mu-1>tol and np.isclose(C,minC)) or (mu-1 < -tol and np.isclose(C,maxC));cap=nits>=20
  state.emit(dict(event='retune_stop',C=C,median=mu,minC=minC,maxC=maxC,median_target_met=bool(centered),boundary_stop=bool(boundary),cap_reached=cap,bisection_updates=nits))
  if cap:raise audit.InvalidSolve('retuning_cap')
 def decision(it,mu,sd,thresh,mult,diff,stats,candidates):
  state.emit(dict(event='decision',location=mu,dispersion=sd,threshold=thresh,raw_threshold=mu+mult*sd,floored_threshold=max(2.75,mu+mult*sd),cap=5-diff,stats=stats,candidates=np.asarray(candidates,dtype=int),threshold_margins=stats-thresh,median_residual=diff))
  if len(candidates)==0:state.converged=True
 def pruned(it,selected,removed,wA,degrees,upper):
  state.edges=sorted(wA);state.degrees=degrees.copy();state.upper=upper.copy();state.emit(dict(event='pruned',selected=selected,removed=removed,**state.graph_data()))
 def final_phase(degrees):
  state.phase='final_affinity_retuning';state.degrees=degrees.copy();state.emit(dict(event='graph_stop',converged=state.converged,reason='no_pruning_candidates' if state.converged else 'pruning_iteration_cap',**state.graph_data()))
  if not state.converged:raise audit.InvalidSolve('pruning_iteration_cap')
  state.checkpoint('graph',state.graph_data())
 audit.iteration=iteration;audit.processed=processed;audit.begin=begin;audit.solve=solve;audit.evaluation=evaluation;audit.tuning=tuning;audit.decision=decision;audit.pruned=pruned;audit.final_phase=final_phase
 sys.modules['pilot_audit']=audit
 def replace(old,new,count=1):
  nonlocal text
  assert text.count(old)==count,(old,text.count(old));text=text.replace(old,new)
 replace('audit.iteration(it,wA,degrees,scl)','audit.iteration(it,wA,degrees,scl,FN_D1s)')
 replace('audit.pruned(it,to_be_pruned,pruned_edge_tups,wA,degrees)','audit.pruned(it,to_be_pruned,pruned_edge_tups,wA,degrees,FN_D1s)')
 replace('    Adj, D1, D2, scl = process_input(X, G0, method, metric, obj, max_nbrhood_size)','    Adj, D1, D2, scl = process_input(X, G0, method, metric, obj, max_nbrhood_size)\n    audit.processed(Adj,D1,D2,scl)')
 replace("    audit.STATE.degrees=stats_args['degrees'].copy()","    audit.STATE.degrees=stats_args['degrees'].copy()\n    audit.begin(curr_C,use_wG,weighted_edges,FN_D1s,cinfo)")
 old='        diffmu = mu - 1\n        if convergedC():'
 assert text.count(old)==2
 text=text.replace(old,'        diffmu = mu - 1\n        audit.evaluation(curr_C,mu,minC,maxC,-1)\n        if convergedC():',1)
 replace(old,'        diffmu = mu - 1\n        audit.evaluation(curr_C,mu,minC,maxC,nits)\n        if convergedC():')
 write(folder/'source/provenance.json',dict(ian=sha(FROZEN/'build/source-evidence/ian/ian/ian.py'),adapter=sha(FROZEN/'scripts/prepare_ian_adapter.py'),audit=sha(FROZEN/'scripts/pilot_audit.py'),cython=sha(CYTHON)))
 (folder/'source/observed.py').write_text(text)
 tree=ast.parse(text)
 tree.body=[node for node in tree.body if not (isinstance(node,ast.ImportFrom) and (node.module or '').startswith(('matplotlib','ian.'))) and not (isinstance(node,ast.Import) and any(x.name.startswith('matplotlib') for x in node.names))]
 cython=load('cutils',CYTHON);module=types.ModuleType('observed_ian');module.computeGabriel=cython.computeGabriel;module.greedySplitting=cython.greedySplitting
 exec(compile(tree,str(folder/'source/observed.py'),'exec'),module.__dict__)
 old_volume=module.getVolumeRatios;old_kernel=module.getSparseMultiScaleK
 import inspect
 def volume(*args,**kwargs):
  out=old_volume(*args,**kwargs);bound=inspect.signature(old_volume).bind(*args,**kwargs);bound.apply_defaults()
  state.emit(dict(event='volume',ratios=out,scales=bound.arguments['sigmas'],degrees=bound.arguments['degrees'],multiscale=bound.arguments['wG'] is not None))
  return out
 def kernel(*args,**kwargs):
  out=old_kernel(*args,**kwargs);bound=inspect.signature(old_kernel).bind(*args,**kwargs);bound.apply_defaults()
  state.emit(dict(event='kernel',affinity=out.toarray() if sparse.issparse(out) else out,scales=bound.arguments['optScales']))
  return out
 module.getVolumeRatios=volume;module.getSparseMultiScaleK=kernel
 return module,audit,state

def main():
 p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('output',type=Path);p.add_argument('condition',choices=['evaluated']);p.add_argument('--pruning-cap',action='store_true');a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
 started=time.perf_counter();state=None
 try:
  d=json.loads(a.input.read_text());assert d.get('numerical_policy')==POLICY,'unsupported_policy';D,mapping=preprocess(d)
  meta=dict(numerical_policy=POLICY,input_sha256=sha(a.input),source_sha256=sha(__file__),configuration_sha256=sha(Path(__file__).with_name('config.json')),mapping=mapping)
  module,audit,state=make_reference(a.output,a.condition,meta)
  state.emit(dict(event='mapping',**mapping))
  G,K,scales,isolates,pruning,sigma_history,stats,wstats=module.IAN('exact-precomputed',D.copy(),obj='l1',n_stds=4.5,stdev_method='C3',max_prune=.1,plot_final_stats=False,interactive=False,solver='CLARABEL',max_iters=1 if a.pruning_cap else 2000,allowMSconvergence=False,tune_wG_method='median',return_stats=True,verbose=0)
  dense=K.toarray();assert np.isfinite(dense).all() and np.all(dense>=0) and np.array_equal(dense,dense.T)
  state.checkpoint('scales',dict(scales=scales,internal_scales=scales*state.scl,scl=state.scl,C=state.C))
  state.checkpoint('affinity',dict(affinity=dense,scales=scales,C=state.C))
  state.emit(dict(event='complete',edges=np.column_stack(sparse.triu(G,k=1).nonzero()),scales=scales,affinity=dense,stats=stats,wstats=wstats,isolates=np.flatnonzero(np.asarray(G.sum(axis=1)).ravel()==0)))
  state.status['complete']=True;state.status['solves']=state.solves;state.status['seconds']=time.perf_counter()-started;write(a.output/'status.json',state.status)
  return 0
 except Exception as exc:
  traceback.print_exc();status=state.status if state else dict(graph=False,scales=False,affinity=False,complete=False)
  status.update(error=repr(exc),seconds=time.perf_counter()-started);write(a.output/'status.json',status);return 1
if __name__=='__main__':raise SystemExit(main())
