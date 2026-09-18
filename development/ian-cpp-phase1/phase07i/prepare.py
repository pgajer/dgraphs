import shutil,subprocess
from support import *
from exact import *
root=Path(sys.argv[1]).resolve();root.mkdir(parents=True,exist_ok=False)
source=WORKER/'phase07h/fixtures/python/original.json';rawsource=WORKER/'phase07h/runs/1/child/raw.json'
shutil.copyfile(source,root/'original.json');shutil.copyfile(rawsource,root/'saved-highs.json');e=load(source);raw=load(rawsource)
A=rows(e);b=vector(e['b']);c=vector(e['c']);u=vector(e['upper']);n=len(c)
assert A[-2*n:-n]==[[(j,F(1))] for j in range(n)] and A[-n:]==[[(j,F(-1))] for j in range(n)]
assert b[-2*n:-n]==u and b[-n:]==[F(0)]*n and feasible(A,b,u,u)
x=vector([e['solver_units']*v for v in raw['x']]);z=vector([-v for v in raw['marginals']]);q,repair_info=repair(A,b,x,u,u);L,dual_info=lower_bound(A,b,c,u,z);U=objective(c,q);assert L<=U
reference=load(Path.cwd().parent/'auditor/review-7h/objective-bounds.json');audit=next(v for v in reference['results'] if v['input']=='python');assert L==decode(audit['lower_exact']) and U==decode(audit['upper_exact'])
write(root/'bounds.json',dict(L=encode(L),U=encode(U),width=encode(U-L),width_float=float(U-L),q=[encode(v) for v in q],repair=repair_info,dual=dual_info,original_sha256=sha(source),saved_highs_sha256=sha(rawsource),auditor_bounds_sha256=sha(Path.cwd().parent/'auditor/review-7h/objective-bounds.json'),auditor_agreement=True,optimizer_calls=0))
fixtures=root/'fixtures';fixtures.mkdir();schedule=[];bands=[]
for index,delta in enumerate(['1e-8','1e-6','1e-4']):
    T=ceil64(U+F(delta));band=dict(index=index,nominal_delta=delta,T=T,T_hex=T.hex(),T_exact=encode(F(T)),above_U=encode(F(T)-U),above_L=encode(F(T)-L),above_U_float=float(F(T)-U),above_L_float=float(F(T)-L));bands.append(band)
    for direction,sign in [('min',1),('max',-1)]:
        name=str(index)+'-'+direction;folder=fixtures/name;folder.mkdir();g=np.zeros(n);g[717]=sign;AA=sparse.vstack([matrix(e),sparse.csr_matrix([e['c']])],format='csc');bb=np.r_[e['b'],T];dump_arrays(folder,AA,bb,g)
        write(folder/'case.json',dict(**band,name=name,direction=direction,sign=sign,coordinate=717,alpha=1.,original=str(root/'original.json')));schedule.append(name)
# This truly feasible original point is outside the band by a known positive amount.
T=F(bands[0]['T']);target=T+F('1e-9');weight=(target-U)/(objective(c,u)-U);bad=[(1-weight)*v+weight*w for v,w in zip(q,u)];assert feasible(A,b,bad,u)
excess=objective(c,bad)-T;assert excess>0 and excess/max(F(1),abs(T))<F('1e-7')
Ar=A+[list(enumerate(c))];br=b+[T];fixed,ri=repair(Ar,br,bad,u,q);assert objective(c,fixed)<=T and ri['weight_float']>0
# Analytic dual-sign and maximization-direction controls.
a=[[(0,F(-1))],[(0,F(1))]];bb=[F(-1),F(3)];uu=[F(3)]
lo,_=lower_bound(a,bb,[F(1)],uu,[F(1),F(0)]);neg,_=lower_bound(a,bb,[F(-1)],uu,[F(0),F(1)]);assert lo==1 and -neg==3
old=load(WORKER/'phase07h/preflight.json')
for path,digest in old['backend_files'].items():assert sha(path)==digest
write(root/'preflight.json',dict(**old,range_controls=dict(strict_band_rejects=True,normalized_check_would_accept=True,excess=encode(excess),repair_pass=True,dual_sign_pass=True,max_direction_pass=True,cutoff_rounding_pass=True),original_bound_rows_verified=True))
# Saved-data direction diagnosis, no solve, with separate exact feasible repair.
cl=vector(e['scales']);qc,rc=repair(A,b,cl,u,u);direction=[a-v for a,v in zip(cl,x)];res=violations(A,b,cl);derivative=[dot(a,direction) for a in A]
write(root/'saved-direction.json',dict(optimizer_calls=0,raw_clarabel_exact_feasible=feasible(A,b,cl,u),raw_highs_exact_feasible=feasible(A,b,x,u),raw_objective_change=encode(objective(c,direction)),maximum_coordinate=int(np.argmax([abs(float(v)) for v in direction])),coordinates={str(j):dict(highs=float(x[j]),clarabel=float(cl[j]),difference=float(direction[j])) for j in [229,230,717]},clarabel_positive_rows=[dict(row=i,violation=encode(v),direction_change=encode(derivative[i])) for i,v in enumerate(res) if v>0],clarabel_repair=rc,clarabel_feasible_point=[encode(v) for v in qc],clarabel_feasible_objective=encode(objective(c,qc)),clarabel_feasible_band_membership=[objective(c,qc)<=F(v['T']) for v in bands]))
write(root/'schedule.json',dict(schedule=schedule,bands=bands,call_budget=6,variable_units='original',coordinate=717,revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()))
write(root/'fixtures-manifest.json',{str(p.relative_to(root)):sha(p) for p in [root/'original.json',root/'saved-highs.json',root/'bounds.json',root/'schedule.json']+list(fixtures.rglob('*')) if p.is_file()})
