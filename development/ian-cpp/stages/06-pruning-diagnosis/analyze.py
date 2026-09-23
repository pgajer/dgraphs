"""Reconstruct saved helix pruning; zero optimizer or engine calls."""
import json, math, sys, time, hashlib, subprocess, platform
from pathlib import Path
import numpy as np
from scipy.special import ndtri
from scipy import sparse
from scipy.sparse.csgraph import shortest_path


def load(p): return json.loads(Path(p).read_text())
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def write(p, x): Path(p).write_text(json.dumps(x, indent=2, allow_nan=False)+'\n')
def eset(edges): return {tuple(sorted(map(int, e))) for e in edges}

def partition(n, edges):
    neighbors=[[] for _ in range(n)]
    for i,j in edges: neighbors[i].append(j); neighbors[j].append(i)
    unseen=set(range(n)); groups=[]
    while unseen:
        stack=[min(unseen)]; unseen.remove(stack[0]); group=[]
        while stack:
            i=stack.pop(); group.append(i)
            for j in neighbors[i]:
                if j in unseen: unseen.remove(j); stack.append(j)
        groups.append(sorted(group))
    # Separate union-find cross-check, labels need not agree.
    parent=list(range(n))
    def root(i):
        while parent[i]!=i: i=parent[i]
        return i
    for i,j in edges: parent[root(i)]=root(j)
    union={}
    for i in range(n): union.setdefault(root(i),[]).append(i)
    assert sorted(groups)==sorted(union.values())
    return groups

def check_labels(n, edges, labels):
    groups={}
    for i,label in enumerate(labels): groups.setdefault(label,[]).append(i)
    assert sorted(groups.values())==partition(n,edges)

def degree(n, edges):
    d=np.zeros(n,dtype=int)
    for i,j in edges: d[i]+=1; d[j]+=1
    return d

def metrics(D, truth, edges):
    n=len(D); es=np.array(sorted(edges),dtype=int).reshape(-1,2)
    a=sparse.csr_matrix((D[es[:,0],es[:,1]],(es[:,0],es[:,1])),shape=(n,n));a=a+a.T
    paths=shortest_path(a,directed=False);ij=np.triu_indices(n,1);est=paths[ij];finite=np.isfinite(est)
    err=np.abs(est[finite]/truth[ij][finite]-1);loss=np.ones(len(est));loss[finite]=np.minimum(1,err)
    recall=[]
    for i in range(n):
        t=np.argsort(truth[i],kind='stable');t=t[t!=i][:10]
        p=np.argsort(paths[i],kind='stable');p=p[(p!=i)&np.isfinite(paths[i,p])][:10]
        recall.append(len(set(t)&set(p))/10)
    return dict(edges=len(edges),components=len(partition(n,edges)),finite_pair_fraction=float(finite.mean()),finite_mean_relative_error=float(err.mean()),bounded_distance_loss=float(loss.mean()),neighbor_recall=float(np.mean(recall)))

def decision(stats):
    positive=stats[stats>0];n=len(positive);q1,m,q3=np.quantile(positive,[.25,.5,.75]);mu=float(m)
    loc=.333*((q1+m)+q3);sd=(q3-q1)/(2*ndtri((.75*n-.125)/(n+.25)))
    raw=loc+4.5*sd;floor=max(2.75,raw);cap=6-mu;usecap=bool(np.all(positive<=floor) and cap<floor);threshold=cap if usecap else floor
    above=sorted(np.flatnonzero(stats>threshold).tolist(),key=lambda i:-stats[i]);candidates=above.copy()
    needed=n-2*int(np.sum(positive<1.1));expanded=bool(mu-1>.1 and needed>len(above))
    if expanded: candidates=np.argsort(stats)[-needed:][::-1].tolist()
    selected=candidates[:max(1,int(.1*len(candidates)))]
    return dict(location=float(loc),dispersion=float(sd),raw_threshold=float(raw),floored_threshold=float(floor),cap=float(cap),threshold=float(threshold),median_residual=mu-1,candidates=candidates,selected=selected,above_threshold=above,cap_used=usecap,median_expansion=expanded,needed_for_median=needed)

def close(actual,expected):
    a=np.asarray(actual);b=np.asarray(expected);assert np.allclose(a,b,rtol=1e-10,atol=1e-10),(np.max(np.abs(a-b)),a,b)
    return float(np.max(np.abs(a-b))) if a.size else 0.

def replay(n, edges, D, selected):
    nbr=[[] for _ in range(n)]
    for i,j in edges: nbr[i].append(j);nbr[j].append(i)
    seen=set();out=[]
    for i in selected:
        if i in seen: continue
        j=max(nbr[i],key=lambda j:(D[i,j],j))
        if j in seen: continue
        out.append(dict(edge=sorted([i,j]),trigger=i,neighbor=j));seen.update([i,j])
    return out

def controls():
    path={(0,1),(1,2)};assert len(partition(3,path))==1 and len(partition(3,path-{(1,2)}))==2
    cycle={(0,1),(1,2),(2,3),(0,3)};assert len(partition(4,cycle-{(0,1)}))==1
    assert len(partition(4,cycle-{(0,1),(2,3)}))==2
    assert partition(3,path)==partition(3,path-set())
    check_labels(3,path,[99,99,99]);check_labels(3,{(0,1)},[7,7,-2])
    return dict(path_bridge=True,cycle_nonbridge=True,sequential_joint_cut=True,no_removal=True,label_invariance=True,union_find_crosscheck=True)

def analyze(P,name,interface):
    inp=load(P/'fixtures'/name/'input.json');truth=np.load(P/'fixtures'/name/'truth.npz');t=truth['latent'][:,0];D=np.array(inp['distances']);n=len(t);rank=np.argsort(np.argsort(t));oracle=truth['oracle']
    trace=P/'runs'/name/interface/'child/trace.jsonl';events=[json.loads(l) for l in trace.read_text().splitlines()]
    processed=next(e for e in events if e['event']=='processed');scaled=np.array(processed['D1']);D2=np.array(processed['D2']);scl=processed['scl']
    close(scaled,D*scl);close(oracle,math.sqrt(1+.15**2)*np.abs(t[:,None]-t))
    edges=eset(processed['initial_edges']);initial=edges.copy();assert len(partition(n,edges))==1
    snapshots={'initial':metrics(D,oracle,edges)};history=[];splits=[];first=None;decision_checks=[];all_removals=[];lastsolve=None
    for event in events:
        kind=event['event']
        if kind=='solve' and event['accepted']: lastsolve=event
        if kind=='iteration':
            assert edges==eset(event['edges']);check_labels(n,edges,event['components']);assert degree(n,edges).tolist()==event['degrees']
        elif kind=='volume' and not event['multiscale']:
            vol=event;assert vol['scales']==lastsolve['scales']
        elif kind=='retune_stop' and event['phase']!='final_affinity_retuning': stop=event
        elif kind=='decision':
            dec=event;stats=np.array(dec['stats']);scales=np.array(vol['scales']);deg=degree(n,edges);calc=np.zeros(n)
            for i in range(n):
                if deg[i]:
                    power=D2[i]/(scales[i]*scales[i]);weights=np.exp(-power);weights[power>-math.log(2*np.finfo(float).eps)]=0
                    k=max(2,deg[i]);calc[i]=math.fsum(weights)/(k*(math.sqrt(math.pi)/2)**math.log2(k))
            err=close(calc,stats);close(stats,vol['ratios']);r=decision(calc)
            errors={k:close(r[k],dec[k]) for k in ['location','dispersion','raw_threshold','floored_threshold','cap','threshold','median_residual']}
            assert r['candidates']==dec['candidates'],(name,interface,event['iteration'],'candidate mismatch')
            close(stats-dec['threshold'],dec['threshold_margins']);close(np.median(calc[calc>0]),stop['median'])
            decision_checks.append(dict(iteration=dec['iteration'],volume_max_error=err,threshold_max_error=max(errors.values()),cap_used=r['cap_used'],median_expansion=r['median_expansion']))
        elif kind=='pruned':
            it=event['iteration'];before=edges.copy();nc=len(partition(n,edges));assert r['selected']==event['selected']
            removed=replay(n,edges,scaled,r['selected']);assert [a['edge'] for a in removed]==event['removed']
            records=[]
            for order,rem in enumerate(removed):
                edge=tuple(rem['edge']);i,j=edge;trigger=rem['trigger'];groupsbefore=partition(n,edges);oldc=len(groupsbefore)
                bridge_before_batch=len(partition(n,before-{edge}))>nc
                edges.remove(edge);groups=partition(n,edges);isbridge=len(groups)>oldc
                record=dict(iteration=it,removal_order=order,edge=list(edge),trigger=trigger,neighbor=rem['neighbor'],bridge_before_batch=bridge_before_batch,bridge_at_removal=isbridge,components_before=oldc,components_after=len(groups),component_sizes_after=sorted(map(len,groups),reverse=True),parameter_rank_gap=int(abs(rank[i]-rank[j])),consecutive_parameter_neighbors=bool(abs(rank[i]-rank[j])==1),euclidean_length=float(D[i,j]),intrinsic_length=float(oracle[i,j]),parameter_gap=float(abs(t[i]-t[j])),trigger_candidate_rank=r['candidates'].index(trigger)+1,trigger_above_threshold=bool(stats[trigger]>dec['threshold']),threshold=dec['threshold'],threshold_margin=float(stats[trigger]-dec['threshold']),cap_used=r['cap_used'],median_expansion=r['median_expansion'],C=stop['C'],median=stop['median'])
                records.append(record);all_removals.append(record)
                if isbridge:
                    record['endpoints']=[dict(row=v,id=inp['ids'][v],parameter=float(t[v]),parameter_rank_one_based=int(rank[v])+1,degree_before_batch=int(deg[v]),scale_original_units=float(scales[v]/scl),statistic=float(stats[v]),margin=float(stats[v]-dec['threshold']),incident_neighbors=[dict(row=w,length=float(D[v,w])) for w in range(n) if tuple(sorted([v,w])) in before]) for v in edge]
                    record['components']=[dict(rows=g,size=len(g),parameter_min=float(min(t[g])),parameter_max=float(max(t[g])),sorted_rank_min=int(min(rank[g]))+1,sorted_rank_max=int(max(rank[g]))+1,contiguous_in_parameter=bool(max(rank[g])-min(rank[g])+1==len(g))) for g in groups]
                    splits.append(record)
                    if first is None:
                        chain={tuple(sorted(map(int,p))) for p in zip(np.argsort(t)[:-1],np.argsort(t)[1:])}
                        gaps=np.diff(np.sort(t));trigger_weights=np.exp(-D2[trigger]/(scales[trigger]*scales[trigger]));trigger_weights[D2[trigger]/(scales[trigger]*scales[trigger])>-math.log(2*np.finfo(float).eps)]=0
                        other=rem['neighbor'];same_side=(t-t[trigger])*(t[other]-t[trigger])<0
                        mass=dict(total=float(math.fsum(trigger_weights)),self=float(trigger_weights[trigger]),toward_deleted_neighbor=float(math.fsum(trigger_weights[(t-t[trigger])*(t[other]-t[trigger])>0])),opposite_side=float(math.fsum(trigger_weights[same_side])),deleted_neighbor_weight=float(trigger_weights[other]),within_one_scale_other_points=int(np.sum((D[trigger]<=scales[trigger]/scl)&(np.arange(n)!=trigger))),degree_denominator=float(max(2,deg[trigger])*(math.sqrt(math.pi)/2)**math.log2(max(2,deg[trigger]))))
                        first=dict(chain_before_split=bool(before==chain),chain_edges=sorted(chain),parameter_gap_rank_descending=int(1+np.sum(gaps>abs(t[i]-t[j]))),consecutive_gap_count=len(gaps),trigger_weighted_mass=mass,iteration=it,first_split=record,decision=dec,reconstructed_decision=r,retune_stop=stop,last_accepted_solve={k:lastsolve[k] for k in ['number','solver_status','accepted','C','attempt','solver_tolerance']},edges_before=sorted(before),edges_after_first=sorted(edges),coordinates=inp['features'],parameter=t.tolist(),stats=stats.tolist(),selected=event['selected'])
                        snapshots['before_first_split_batch']=metrics(D,oracle,before)
                        snapshots['immediately_before_first_split_edge']=metrics(D,oracle,edges|{edge})
                        snapshots['after_first_split_edge']=metrics(D,oracle,edges)
            assert edges==eset(event['edges']);check_labels(n,edges,event['components']);assert degree(n,edges).tolist()==event['degrees']
            history.append(dict(iteration=it,pruning_step=it+1,edges_before=len(before),edges_after=len(edges),components_before=nc,components_after=len(partition(n,edges)),removed=len(removed),split_edges=sum(a['bridge_at_removal'] for a in records),candidate_count=len(r['candidates']),selected_count=len(r['selected']),cap_used=r['cap_used'],median_expansion=r['median_expansion']))
            if first is not None and first['iteration']==it:
                first.update(batch_removals=records,edges_after_batch=sorted(edges));snapshots['after_first_split_batch']=metrics(D,oracle,edges)
        elif kind=='graph_stop':
            assert event['converged'] and edges==eset(event['edges']);check_labels(n,edges,event['components'])
    assert first is not None
    complete=events[-1];assert complete['event']=='complete' and edges==eset(complete['edges'])
    snapshots['final']=metrics(D,oracle,edges)
    return dict(dataset=name,interface=interface,n=n,initial_edges=len(initial),pruning_batches=len(history),removal_count=len(all_removals),first=first,splits=splits,history=history,snapshots=snapshots,decision_checks=decision_checks,all_removals=all_removals)

def main():
    P=Path(sys.argv[1]);O=Path(sys.argv[2]);O.mkdir(parents=True,exist_ok=False);start=time.monotonic();ctrl=controls();summary=[];identities={}
    expected=load(P/'evidence-identities.json');M=load(P/'manifest.json')
    for seed in [6101,6102,6103]:
        name=f'helix-{seed}';files=[P/'fixtures'/name/'input.json',P/'fixtures'/name/'truth.npz']+[P/'runs'/name/a/'child/trace.jsonl' for a in ['native','evaluated']]
        for p in files:
            h=sha(p);assert h==expected[str(p.relative_to(P))];identities[str(p)]=h
        native=analyze(P,name,'native');reference=analyze(P,name,'evaluated')
        for key in ['history','all_removals','snapshots']:
            # These fields depend on identical saved scales/graphs, not display timing.
            assert native[key]==reference[key],(name,key)
        for key in ['edges_before','edges_after_first','edges_after_batch','selected']:
            assert native['first'][key]==reference['first'][key]
        write(O/f'{name}-native.json',native);write(O/f'{name}-evaluated.json',reference)
        f=native['first'];summary.append(dict(dataset=name,first_iteration=f['iteration'],first_pruning_step=f['iteration']+1,first_edge=f['first_split'],chain_before_split=f['chain_before_split'],parameter_gap_rank_descending=f['parameter_gap_rank_descending'],trigger_weighted_mass=f['trigger_weighted_mass'],first_decision={k:f['reconstructed_decision'][k] for k in ['threshold','raw_threshold','floored_threshold','cap','cap_used','median_expansion','needed_for_median']},retune_stop=f['retune_stop'],snapshots=native['snapshots'],split_count=len(native['splits']),pruning_batches=native['pruning_batches'],removal_count=native['removal_count'],decision_checks=len(native['decision_checks']),maximum_volume_error=max(r['volume_max_error'] for r in native['decision_checks'])))
    for p,h in identities.items(): assert sha(p)==h
    write(O/'summary.json',dict(cases=summary,controls=ctrl,native_python_reconstructions_equal=True,new_engine_calls=0,new_solver_calls=0,seconds=time.monotonic()-start,arithmetic_tolerance=dict(atol=1e-10,rtol=1e-10),decisions_and_removal_ids='exact'))
    source=Path(__file__);write(O/'provenance.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),script_sha256=sha(source),plan_sha256=sha(source.with_name('PLAN.md')),input_identities=identities,python=sys.version,numpy=np.__version__,platform=platform.platform(),argv=sys.argv))
    print(json.dumps([dict(dataset=s['dataset'],step=s['first_pruning_step'],edge=s['first_edge']['edge'],threshold=s['first_edge']['threshold'],margin=s['first_edge']['threshold_margin'],cap=s['first_decision']['cap_used'],expansion=s['first_decision']['median_expansion'],component_sizes=s['first_edge']['component_sizes_after'],rankgap=s['first_edge']['parameter_rank_gap']) for s in summary],indent=2))

if __name__=='__main__':main()
