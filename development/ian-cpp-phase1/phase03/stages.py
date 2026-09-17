"""Stage-specific executed-reference checks; original and evaluated solve conditions."""
import argparse,ast,collections,json,textwrap
from pathlib import Path
import numpy as np
from scipy import sparse
import cvxpy as cp
from reference import make_reference,preprocess,sha,write,components,FROZEN
p=argparse.ArgumentParser();p.add_argument('input',type=Path);p.add_argument('output',type=Path);p.add_argument('condition',choices=['original','evaluated']);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
inp=json.loads(a.input.read_text());module,audit,state=make_reference(a.output,a.condition,dict(input_sha256=sha(a.input),source_sha256=sha(__file__),configuration_sha256=sha(Path(__file__).with_name('config.json'))))
state.phase='stage';results={};_,mapping=preprocess(inp['duplicate']);results['duplicate']=mapping
results['gabriel']=[]
for case in inp['gabriel']:
 G=module.computeGabriel(np.array(case['D2'],dtype='float32'));edges=np.column_stack(sparse.triu(G,k=1).nonzero());assert bool(G[0,1])==case['edge01_expected'];results['gabriel'].append(dict(name=case['name'],edges=edges))
source=(FROZEN/'build/source-evidence/ian/ian/ian.py').read_text();begin=source.index('        to_be_pruned = np.flatnonzero( stats > thresh )');end=source.index('        if len(to_be_pruned) == 0:\n',begin)
block=textwrap.dedent(source[begin:end]);results['decisions']=[]
for case in inp['decisions']:
 stats=np.asarray(case['stats']);mu=case['median'];loc,sd,threshold,_=module.computeThreshold(stats[stats>0],4.5,5-(mu-1),plot=False,stdev_method='C3')
 namespace=dict(np=np,stats=stats,thresh=threshold,extraVerbose=False,diffmu=mu-1,mu=mu,median_tol=.1,nonz_stats=stats[stats>0]);exec(block,namespace)
 results['decisions'].append(dict(name=case['name'],event='decision',location=loc,dispersion=sd,threshold=threshold,raw_threshold=loc+4.5*sd,floored_threshold=max(2.75,loc+4.5*sd),cap=5-(mu-1),stats=stats,candidates=np.asarray(namespace['to_be_pruned'],dtype=int),threshold_margins=stats-threshold,median_residual=mu-1))
# Execute the actual nested prune function extracted without rewriting its body.
ian=next(n for n in ast.parse(source).body if isinstance(n,ast.FunctionDef) and n.name=='IAN');prune=next(n for n in ian.body if isinstance(n,ast.FunctionDef) and n.name=='prune_edges')
case=inp['pruning'];D=np.asarray(case['distances']);weighted={tuple(e):D[tuple(e)] for e in case['edges']};n=len(D);nbr=[[] for _ in range(n)]
for i,j in case['edges']:nbr[i].append(j);nbr[j].append(i)
ordered={i:collections.deque(sorted(nbr[i],key=lambda j:(D[i,j],j),reverse=True)) for i in range(n)};deg=np.array([len(x) for x in nbr]);upper=np.array([max(D[i,j] for j in nbr[i]) for i in range(n)])
namespace=dict(np=np,D1=D,extraVerbose=False,debugStatsPts=[],obj='l1');exec(compile(ast.Module(body=[prune],type_ignores=[]),'pinned_prune','exec'),namespace)
out=namespace['prune_edges'](case['candidates'],weighted,ordered,deg,upper,None,None,[1]*len(case['candidates']),None);assert [list(e) for e in out[0]]==case['expected_removed'];results['pruning']=dict(removed=out[0],edges=sorted(out[2]))
case=inp['disconnected'];D=np.asarray(case['distances'],dtype=float);D2=D*D;n=len(D);weighted={tuple(e):D[tuple(e)] for e in case['edges']};deg=np.bincount(np.asarray(case['edges']).ravel(),minlength=n);u=np.zeros(n)
for i,j in weighted:u[i]=max(u[i],D[i,j]);u[j]=max(u[j],D[i,j])
state.degrees=deg;state.upper=u;state.edges=sorted(weighted);state.C=case['C'];x,obj,cons,C,Ct=module.buildOptimizationProblem(weighted,u);C.value=case['C'];Ct.value=1/C.value;audit.solve(cp.Problem(cp.Minimize(obj),cons),x,'parameterized');solve=[json.loads(l) for l in (a.output/'trace.jsonl').read_text().splitlines() if json.loads(l)['event']=='solve'][-1]
K=module.getSparseMultiScaleK(D2,x.value,degrees=deg,disc_pts=np.flatnonzero(deg==0));r=module.getVolumeRatios(deg,D2,x.value,sig2scl=1);wr=module.getVolumeRatios(deg,D2,x.value,wG=K,sig2scl=1)
results['disconnected']=dict(solve=solve,components=components(n,case['edges']),ratios=r,affinity=K.toarray(),weighted_ratios=wr)
cut=inp['affinity_cutoffs'];results['affinity_cutoffs']=module.getSparseMultiScaleK(np.array(cut['D2']),np.array(cut['scales']),degrees=np.array(cut['degrees'])).toarray()
# Upstream's one-point empty minimum fails before any solve; retain that limitation.
try:
 module.IAN('exact-precomputed',np.zeros((1,1)),plot_final_stats=False,verbose=0,return_processed_inputs=True)
 results['upstream_single_point']='unexpected_success'
except Exception as exc:results['upstream_single_point']=dict(error=repr(exc),solves_added=0)
write(a.output/'stages.json',results)
print('Reference stages complete, including one explicit disconnected LP and a raw upstream degenerate-input refusal.')
