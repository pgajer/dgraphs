"""Persistent accepted evaluated-LP reference; observation only, no arithmetic edits."""
import sys,json,time,types,gc
from pathlib import Path
began=time.perf_counter();schedule=json.loads(Path(sys.argv[1]).read_text());out=Path(sys.argv[2]);out.mkdir(parents=True)
sys.path.insert(0,schedule['reference']);import reference as ref
import numpy as np
from scipy import sparse
cases=[json.loads(Path(c['path']).read_text()) for c in schedule['cases']]
account=(out/'account.jsonl').open('w');record=lambda d:(account.write(json.dumps(d)+'\n'),account.flush())
module,audit,state=ref.make_reference(out,'evaluated',{})
state.stream.close()
original_emit=ref.Recorder.emit
keys=['number','attempt','iterations','accepted','solver_status','objective']
def emit(self,d):
 event=d['event']
 if event=='processed':self.processed=time.perf_counter();self.initial=np.asarray(d['initial_edges']).copy()
 if event=='graph_stop':self.graph=time.perf_counter()
 if event=='solve':
  self.solver+=d['seconds'];self.history.append({k:d[k] for k in keys});record(dict(event='attempt',number=d['number']))
  if len(self.history)>=250:raise RuntimeError('profile_attempt_limit')
 if schedule['full']:original_emit(self,d)
def checkpoint(self,stage,data):self.status[stage]=True
state.emit=types.MethodType(emit,state);state.checkpoint=types.MethodType(checkpoint,state)
ref.write(out/'setup.json',dict(seconds=time.perf_counter()-began))
entry=0
for case,d in zip(schedule['cases'],cases):
 for rep in range(schedule['repeats']):
  folder=out/str(entry);folder.mkdir();record(dict(event='entry',entry=entry,fixture=case['name']))
  # Preserve the object captured by the accepted closures, reset its run state.
  state.solves=0;state.phase='initial';state.it=0;state.degrees=None;state.converged=False;state.retune_caps=0;state.C=None;state.edges=[];state.upper=[];state.scl=1;state.status={};state.history=[];state.solver=0;state.processed=state.graph=0
  audit.PARAMETERS.clear()
  state.stream=(folder/'trace.jsonl').open('w') if schedule['full'] else None
  start=time.perf_counter();D,mapping=ref.preprocess(d);state.emit(dict(event='mapping',**mapping))
  G,K,scales,isolates,pruning,sigma_history,stats,wstats=module.IAN('exact-precomputed',D.copy(),obj='l1',n_stds=4.5,stdev_method='C3',max_prune=.1,plot_final_stats=False,interactive=False,solver='CLARABEL',max_iters=2000,allowMSconvergence=False,tune_wG_method='median',return_stats=True,verbose=0)
  dense=K.toarray();assert np.isfinite(dense).all() and np.all(dense>=0) and np.array_equal(dense,dense.T)
  edges=np.column_stack(sparse.triu(G,k=1).nonzero())
  state.emit(dict(event='complete',edges=edges,scales=scales,affinity=dense,stats=stats,wstats=wstats,isolates=np.flatnonzero(np.asarray(G.sum(axis=1)).ravel()==0)))
  end=time.perf_counter()
  if state.stream:state.stream.close()
  ref.write(folder/'result.json',dict(complete=True,initial_edges=state.initial,edges=edges,scales=scales,affinity=dense,history=state.history))
  ref.write(folder/'timing.json',dict(fixture=case['name'],rep=rep,total=end-start,initialization=state.processed-start,pruning=state.graph-state.processed,final=end-state.graph,solver_recorded=state.solver,solves=state.solves))
  record(dict(event='returned',entry=entry,solves=state.solves,complete=True));entry+=1
  del G,K,scales,dense,stats,wstats,pruning,sigma_history
