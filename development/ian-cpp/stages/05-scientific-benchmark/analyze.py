"""Prespecified geometry and transductive conditional-mean evaluation. No IAN calls."""
import sys,json,math,hashlib,subprocess,time
from pathlib import Path
import numpy as np
from scipy import sparse
from scipy.sparse.csgraph import shortest_path,connected_components
from scipy.spatial.distance import pdist,squareform
load=lambda p:json.loads(Path(p).read_text())
def write(p,x):Path(p).write_text(json.dumps(x,indent=2,allow_nan=False)+'\n')
def sha(p):return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def distances(D,edges):
 e=np.asarray(edges,dtype=int).reshape(-1,2);n=len(D)
 a=sparse.csr_matrix((D[e[:,0],e[:,1]],(e[:,0],e[:,1])),shape=(n,n));a=a+a.T
 return shortest_path(a,directed=False),int(connected_components(a,directed=False)[0])
def knn_edges(D,k):
 order=np.argsort(D,axis=1,kind='stable');out=set()
 for i,row in enumerate(order):
  for j in row[row!=i][:k]:out.add(tuple(sorted([i,int(j)])))
 return sorted(out)
def geometry_scores(estimated,truth,edges,components):
 n=len(truth);ij=np.triu_indices(n,1);a=estimated[ij];b=truth[ij];finite=np.isfinite(a);error=np.abs(a[finite]/b[finite]-1);penalty=np.ones(len(a));penalty[finite]=np.minimum(1,error)
 k=min(10,n-1);recall=[]
 for i in range(n):
  true=np.argsort(truth[i],kind='stable');true=true[true!=i][:k]
  pred=np.argsort(estimated[i],kind='stable');pred=pred[(pred!=i)&np.isfinite(estimated[i,pred])][:k]
  recall.append(len(set(true)&set(pred))/k)
 return dict(edges=len(edges),components=components,finite_pair_fraction=float(finite.mean()),finite_mean_relative_error=float(error.mean()) if len(error) else None,bounded_distance_loss=float(penalty.mean()),neighbor_recall=float(np.mean(recall)))
def bandwidth(D):
 radii=[]
 for i,row in enumerate(D):
  d=np.sort(row[(np.arange(len(row))!=i)&np.isfinite(row)&(row>0)])
  if len(d):radii.append(d[min(9,len(d)-1)])
 return float(np.median(radii)) if radii else None
def weighted(W,Y,train,target):
 w=W[np.ix_(target,train)];s=w.sum(axis=1);ok=s>0;pred=np.full(len(target),float(np.mean(Y[train])))
 pred[ok]=(w[ok]*Y[train]).sum(axis=1)/s[ok]
 assert np.isfinite(pred).all()
 return pred,int((~ok).sum())
def fit(method,candidates,D,Y,order):
 train,val,test=order[:50],order[50:100],order[100:];losses=[];preds=[];fallbacks=[]
 for value,W in candidates:
  if method=='training_mean':vp=np.full(len(val),Y[train].mean());tp=np.full(len(test),Y[train].mean());fallback=0
  elif method=='euclidean_knn':
   def predict(target):return Y[train[np.argsort(D[np.ix_(target,train)],axis=1,kind='stable')[:,:value]]].mean(axis=1)
   vp=predict(val);tp=predict(test);fallback=0
  else:vp,_=weighted(W,Y,train,val);tp,fallback=weighted(W,Y,train,test)
  losses.append(float(np.mean((vp-Y[val])**2)));preds.append(tp);fallbacks.append(fallback)
 selected=int(np.argmin(losses))
 return dict(selected_index=selected,selected_parameter=candidates[selected][0],validation_losses=losses,prediction=preds[selected].tolist(),fallback_count=fallbacks[selected])
def controls():
 true=np.abs(np.arange(3)[:,None]-np.arange(3)[None,:]).astype(float);d,c=distances(true,[(0,1),(1,2)]);assert np.array_equal(d,true)
 d,c=distances(true,[(0,1)]);m=geometry_scores(d,true,[(0,1)],c);assert c==2 and m['finite_pair_fraction']==1/3 and m['bounded_distance_loss']==2/3 and m['neighbor_recall']==1/3
 for W in [np.zeros((4,4)),np.ones((4,4)),np.eye(4)]:
  pred,fallback=weighted(W,np.full(4,2.5),np.array([0,1]),np.array([2,3]));assert np.array_equal(pred,np.full(2,2.5))
 return dict(path_metric=True,disconnected_penalty=True,constant_response_and_zero_weight_fallback=True)
def main():
 P=Path(sys.argv[1]);O=Path(sys.argv[2]);O.mkdir(parents=True,exist_ok=False);started=time.monotonic();M=load(P/'manifest.json');L=load(P/'ledger.json');assert L['complete'] and L['gate'];control=controls();geometry=[];replicates=[];truth_checks=[];unavailable=[]
 for case in M['cases']:
  assert sha(case['path'])==case['input_sha256'] and sha(case['truth'])==case['truth_sha256'];raw=load(case['path']);assert set(raw)=={'schema_version','numerical_policy','features','distances','ids'}
  X=np.array(raw['features']);D=np.array(raw['distances']);T=np.load(case['truth']);truth=T['oracle'];f=T['mean'];order=T['order'];responses=T['response'];latent=T['latent'];n=len(X)
  assert len(set(map(tuple,X)))==n and len(set(raw['ids']))==n
  assert np.array_equal(D,squareform(pdist(X))) and np.array_equal(responses,f+T['noise'])
  assert all(sorted(o)==list(range(n)) for o in order)
  # Independent scalar distance reconstruction, including analytic intrinsic truth.
  max_e=max_t=0.
  for i in range(n):
   for j in range(i+1,n):
    max_e=max(max_e,abs(math.dist(X[i],X[j])-D[i,j]))
    if case['geometry']=='square':t=math.dist(X[i],X[j])
    elif case['geometry']=='helix':t=math.sqrt(1+.15**2)*abs(float(latent[i,0])-float(latent[j,0]))
    else:t=math.acos(max(-1,min(1,math.fsum(float(a)*float(b) for a,b in zip(X[i],X[j])))))
    max_t=max(max_t,abs(t-truth[i,j]))
  assert max_e<1e-12 and max_t<1e-12
  expected=np.array([math.sin(math.pi*x[0])*math.cos(math.pi*x[1]/2) for x in X]) if case['geometry']=='square' else np.array([math.sin(t/2)+.3*t/(4*math.pi) for t in latent[:,0]]) if case['geometry']=='helix' else X[:,2]+.5*X[:,0]*X[:,1]
  assert np.max(np.abs(expected-f))<1e-14
  truth_checks.append(dict(dataset=case['name'],euclidean_max_error=max_e,intrinsic_max_error=max_t,known_mean_max_error=float(np.max(np.abs(expected-f)))))
  complete=L['cases'][case['name']]['results']['native']['complete'];child=P/'runs'/case['name']/'native/child';events=[json.loads(s) for s in (child/'trace.jsonl').read_text().splitlines()];initial=next(e['initial_edges'] for e in events if e['event']=='processed')
  graphs={'Gabriel':initial,**{f'knn_{k}':knn_edges(D,k) for k in [5,10,20]}}
  result=load(child/'result.json')
  if complete:graphs['IAN']=result['graph']['edges']
  paths={}
  for name,edges in graphs.items():
   ds,ncomp=distances(D,edges);paths[name]=ds;geometry.append(dict(dataset=case['name'],geometry=case['geometry'],seed=case['seed'],method=name,**geometry_scores(ds,truth,edges,ncomp)))
  methods={'training_mean':[(None,None)],'euclidean_knn':[(k,None) for k in [3,5,10,20,40]]};bases={}
  distance_methods={'euclidean_kernel':D,'oracle_kernel':truth}
  if complete:distance_methods['IAN_distance_kernel']=paths['IAN']
  for name,ds in distance_methods.items():
   h=bandwidth(ds);bases[name]=h
   if h is None:unavailable.append(dict(dataset=case['name'],method=name,reason='no_finite_geometry'));continue
   methods[name]=[(float(h*scale),np.exp(-.5*(ds/(h*scale))**2)) for scale in [.5,1,2,4,8]]
  if complete:
   K=np.asarray(result['affinity']);assert K.shape==(n,n) and np.isfinite(K).all() and np.all(K>=0) and np.array_equal(K,K.T)
   methods['IAN_affinity']=[(p,K**p) for p in [.25,.5,1,2,4]]
  else:unavailable.extend([dict(dataset=case['name'],method=name,reason='IAN_refusal') for name in ['IAN_distance_kernel','IAN_affinity']])
  folder=O/case['name'];folder.mkdir();write(folder/'parameters.json',dict(bandwidth_bases=bases,methods={name:[v for v,w in options] for name,options in methods.items()}))
  for rep in range(10):
   Y=responses[rep];o=order[rep];test=o[100:];record=dict(dataset=case['name'],replicate=rep,training=o[:50].tolist(),tuning=o[50:100].tolist(),evaluation=test.tolist(),mean=f.tolist(),noise=T['noise'][rep].tolist(),observed_response=Y.tolist(),methods={})
   for name,candidates in methods.items():
    fitted=fit(name,candidates,D,Y,o);pred=np.asarray(fitted['prediction']);mse=float(np.mean((pred-f[test])**2));observed=float(np.mean((pred-Y[test])**2));fitted.update(mean_squared_error=mse,observed_outcome_error=observed);record['methods'][name]=fitted
    replicates.append(dict(dataset=case['name'],geometry=case['geometry'],seed=case['seed'],replicate=rep,method=name,mean_squared_error=mse,observed_outcome_error=observed,fallback_count=fitted['fallback_count'],selected_index=fitted['selected_index']))
    if rep==0:
     changed=Y.copy();changed[test]+=1000;assert fit(name,candidates,D,changed,o)==fit(name,candidates,D,Y,o)
     const=fit(name,candidates,D,np.full(n,2.5),o);assert np.allclose(const['prediction'],2.5,atol=1e-14,rtol=0)
   write(folder/f'replicate-{rep:02}.json',record)
 control.update(evaluation_outcome_invariance=True,constant_response_all_estimators=True)
 write(O/'controls.json',dict(**control,truth_reconstruction=truth_checks))
 write(O/'geometry-rows.json',geometry);write(O/'replicate-rows.json',replicates)
 per_dataset=[]
 for c in M['cases']:
  methods=sorted({r['method'] for r in replicates if r['dataset']==c['name']})
  for method in methods:
   rows=[r for r in replicates if r['dataset']==c['name'] and r['method']==method];assert len(rows)==10
   per_dataset.append(dict(dataset=c['name'],geometry=c['geometry'],method=method,mean_squared_error=float(np.mean([r['mean_squared_error'] for r in rows])),fallback_fraction=float(np.sum([r['fallback_count'] for r in rows])/1000)))
 write(O/'dataset-means.json',per_dataset)
 summary=dict(source_revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),engine_entries=len(L['processes']),attempts=sum(r['optimizer_calls'] for r in L['processes']),numerical_child_seconds=sum(r['wall_seconds'] for r in L['processes']),paired_complete=sum(c['results']['native']['complete'] for c in L['cases'].values()),geometry={},mean_estimation={},paired_differences={},unavailable=unavailable,analysis_seconds=time.monotonic()-started)
 for g in ['square','helix','sphere']:
  summary['geometry'][g]={};summary['mean_estimation'][g]={};summary['paired_differences'][g]={}
  for method in sorted({r['method'] for r in geometry if r['geometry']==g}):
   rows=[r for r in geometry if r['geometry']==g and r['method']==method];summary['geometry'][g][method]={k:dict(mean=float(np.mean([r[k] for r in rows])),minimum=min(r[k] for r in rows),maximum=max(r[k] for r in rows)) for k in ['edges','components','finite_pair_fraction','bounded_distance_loss','neighbor_recall']}
  for method in sorted({r['method'] for r in per_dataset if r['geometry']==g}):
   rows=[r for r in per_dataset if r['geometry']==g and r['method']==method];v=[r['mean_squared_error'] for r in rows];summary['mean_estimation'][g][method]=dict(datasets=len(rows),mean=float(np.mean(v)),minimum=min(v),maximum=max(v),fallback_fraction=float(np.mean([r['fallback_fraction'] for r in rows])))
  for method in ['IAN_affinity','IAN_distance_kernel']:
   diff=[]
   for c in M['cases']:
    if c['geometry']!=g:continue
    a=[r for r in per_dataset if r['dataset']==c['name'] and r['method']==method];b=[r for r in per_dataset if r['dataset']==c['name'] and r['method']=='euclidean_knn']
    if a and b:diff.append(a[0]['mean_squared_error']-b[0]['mean_squared_error'])
   if diff:summary['paired_differences'][g][method]=dict(reference='euclidean_knn',differences=diff,mean=float(np.mean(diff)),minimum=min(diff),maximum=max(diff))
 write(O/'summary.json',summary);print(json.dumps(summary,indent=2))
if __name__=='__main__':main()
