"""Streaming checks using unchanged Phase03 numerical comparison rules."""
import hashlib
import itertools
import json
import math
import sys
from collections import Counter
from pathlib import Path
import numpy as np
from scipy import sparse
from scipy.sparse.csgraph import connected_components
sys.path.insert(0,str(Path(__file__).resolve().parent.parent/'phase03'))
from compare import DISCRETE, FLOATS, arrays, check_lp, kernel_checks

def write(path,value):
    Path(path).write_text(json.dumps(value,allow_nan=False)+'\n')

def load(path): return json.loads(Path(path).read_text())

def sha(path):
    with Path(path).open('rb') as f: return hashlib.file_digest(f,'sha256').hexdigest()

def events(path):
    with Path(path).open() as f:
        for line in f:
            # A killed process may leave one incomplete terminal record.
            if not line.endswith('\n'): break
            yield json.loads(line)

def compare(left,right,out):
    out=Path(out); out.mkdir(parents=True,exist_ok=False)
    first=None; first_discrete=None; scl=1.; maxima={}; count=0; states=[{},{}]
    exact=True; failures=Counter()
    with (out/'rows.jsonl').open('w') as rows:
        for i,(x,y) in enumerate(itertools.zip_longest(events(left),events(right))):
            count+=1; bad=[]; discrete=[]; numeric={}
            if x is None or y is None: bad=discrete=['trace_length']
            else:
                if x['event']=='processed': scl=x['scl']
                discrete=[k for k in DISCRETE if (k in x or k in y) and x.get(k)!=y.get(k)]
                bad.extend(discrete)
                for k,(at,rt) in FLOATS.items():
                    if k not in x and k not in y: continue
                    if k not in x or k not in y: bad.append(k); continue
                    if k=='scales' and x['event']=='complete': at/=scl
                    c=arrays(x[k],y[k],at,rt); numeric[k]=c
                    maxima[k]=max(maxima.get(k,0.),c.get('max_absolute',0.))
                    if not c['pass_limit']: bad.append(k)
                    if k=='affinity' and not np.array_equal(np.asarray(x[k])==0,np.asarray(y[k])==0): bad.append('affinity_zero_support')
                exact = exact and {k:v for k,v in x.items() if k!='seconds'}=={k:v for k,v in y.items() if k!='seconds'}
            if bad:
                failures.update(bad)
                if first is None:
                    first=i
                    write(out/'first-divergence.json',dict(index=i,fields=bad,event_a=x,event_b=y,preceding_states=states))
            rows.write(json.dumps(dict(index=i,event=(x or y)['event'],bad=bad,numeric=numeric))+'\n')
            if discrete:
                first_discrete=i
                break
            if x: states[0][x['event']]=x
            if y: states[1][y['event']]=y
    result=dict(passed=first is None,compared_events=count,first_divergence=first,
        first_discrete_divergence=first_discrete,failures=dict(failures),maxima=maxima,exact_except_seconds=exact,
        left=str(left),right=str(right),endpoint_comparison=None)
    # Endpoint checks are separate if branching made later event pairs incomparable.
    lp=Path(left).parent/'affinity.json'; rp=Path(right).parent/'affinity.json'
    if lp.exists() and rp.exists(): result['endpoint_comparison']=arrays(load(lp)['affinity'],load(rp)['affinity'],1e-7,1e-7)
    write(out/'summary.json',result); return result

def inspect(child,fixture,out):
    child=Path(child); out=Path(out); out.mkdir(parents=True,exist_ok=False)
    count=Counter(); maximum={}; valid=True; topology=[]; kernels=[]; deg=None; timing=0.; raw=[]
    with (out/'lp-checks.jsonl').open('w') as f:
        for i,e in enumerate(events(child/'trace.jsonl')):
            count[e['event']]+=1
            if e['event']=='solve':
                c=check_lp(e); valid &= c['accepted'] and c['dual_valid']; raw.append(c)
                f.write(json.dumps(dict(event=i,number=e['number'],**c))+'\n')
                timing+=e['seconds']
                for k,v in c.items():
                    if type(v) is float: maximum[k]=max(maximum.get(k,0.),v)
            if 'degrees' in e: deg=e['degrees']
            if all(k in e for k in ['edges','degrees','components','isolates']):
                n=len(deg); edges=np.asarray(e['edges'],dtype=int).reshape(-1,2)
                degrees=np.bincount(edges.ravel(),minlength=n)
                ok=degrees.tolist()==deg and np.flatnonzero(degrees==0).tolist()==e['isolates']
                ok=ok and e['edges']==sorted(e['edges']) and len(set(map(tuple,edges)))==len(edges) and bool(np.all(edges[:,0]<edges[:,1]))
                G=sparse.coo_matrix((np.ones(2*len(edges)),(np.r_[edges[:,0],edges[:,1]],np.r_[edges[:,1],edges[:,0]])),shape=(n,n))
                components,labels=connected_components(G,directed=False)
                ok=ok and labels.tolist()==e['components']; valid &= ok
                topology.append(dict(event=i,iteration=e['iteration'],edges=len(edges),isolates=int(sum(degrees==0)),
                    components=int(components),edge_components=len(set(labels[degrees>0])),valid=bool(ok)))
            if 'affinity' in e:
                k=kernel_checks([dict(degrees=deg),e])[0]; kernels.append(k); valid &= k['valid']
    status=load(child/'status.json') if (child/'status.json').exists() else dict(complete=False,error='missing_status')
    hashes=[]
    for stage in ['graph','scales','affinity']:
        f=child/(stage+'.json')
        if status.get(stage):
            ok=f.exists() and sha(f)==status[stage+'_sha256']; valid &= ok; hashes.append(dict(stage=stage,valid=ok))
    reconstruction=None
    if status.get('complete'):
        graph=load(child/'graph.json'); scale=load(child/'scales.json'); final=load(child/'affinity.json')
        source=load(fixture); reps=graph['mapping']['representatives']; D=np.asarray(source['distances'])[np.ix_(reps,reps)]
        sig=np.asarray(scale['scales']); degree=np.asarray(graph['degrees']); K=np.zeros(D.shape)
        active=degree>0
        for i in np.flatnonzero(active):
            for j in np.flatnonzero(active):
                power=(float(D[i,j])/float(sig[i]))*(float(D[i,j])/float(sig[j]))
                value=math.exp(-power)
                K[i,j]=value if value>=1e-8 else 0.
        K=np.maximum(K,K.T); actual=np.asarray(final['affinity'])
        reconstruction=arrays(K,actual,1e-7,1e-7)
        reconstruction['zero_support_equal']=bool(np.array_equal(K==0,actual==0))
        valid &= reconstruction['pass_limit'] and reconstruction['zero_support_equal']
    result=dict(valid=bool(valid),complete=bool(status.get('complete')),status=status,counts=dict(count),
        lp_maxima=maximum,aggregate_solve_seconds=timing,topology=topology,kernels=kernels,stage_hashes=hashes,
        final_affinity_reconstruction=reconstruction,
        native_resources=load(child/'resources.json') if (child/'resources.json').exists() else None)
    write(out/'summary.json',result); return result
