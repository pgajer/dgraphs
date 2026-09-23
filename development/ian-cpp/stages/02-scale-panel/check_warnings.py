"""Recalculate saved certificate products with warning capture; no optimization."""
import sys,json,math,warnings,platform,io,contextlib,collections,hashlib
from pathlib import Path
import numpy as np
import scipy
from scipy import sparse
root=Path(sys.argv[1]);out=root/sys.argv[2];out.mkdir(exist_ok=False)
load=lambda p:json.loads(Path(p).read_text())
rows=[];totals=collections.Counter();maxerr=collections.defaultdict(float)
with (out/'products.jsonl').open('w') as f:
 for path in sorted((root/'panel-v1/runs').glob('*/evaluated/child/trace.jsonl')):
  for line in path.open():
   e=json.loads(line)
   if e['event']!='solve':continue
   c=np.array(e['c']);x=np.array(e['scales']);b=np.array(e['b']);z=np.array(e['dual']);A=sparse.csr_matrix((e['A_data'],e['A_indices'],e['A_indptr']),shape=e['A_shape']).tocsc()
   scalar={'primal':math.fsum(float(a)*float(v) for a,v in zip(c,x)),'dual':math.fsum(float(a)*float(v) for a,v in zip(b,z)),'transpose':np.array([math.fsum(float(A.data[k])*float(z[A.indices[k]]) for k in range(A.indptr[i],A.indptr[i+1])) for i in range(len(c))])}
   ops={'transpose':lambda:A.T@z,'primal_matmul':lambda:c@x,'dual_matmul':lambda:b@z,'primal_dot':lambda:np.dot(c,x),'dual_dot':lambda:np.dot(b,z),'primal_sum':lambda:np.sum(c*x),'dual_sum':lambda:np.sum(b*z)}
   record=dict(case=path.parents[2].name,number=e['number'],finite_inputs=all(np.isfinite(v).all() for v in [c,x,b,z,A.data]),operations={})
   for name,fn in ops.items():
    with warnings.catch_warnings(record=True) as caught:
     warnings.simplefilter('always');value=fn()
    target=scalar['transpose' if name=='transpose' else name.split('_')[0]];error=float(np.max(np.abs(value-target)));limit=1e-12*max(1.,float(np.max(np.abs(target))))
    messages=[str(w.message) for w in caught];finite=bool(np.isfinite(value).all());record['operations'][name]=dict(warnings=messages,finite=finite,max_absolute_error=error,relative_limit=limit,pass_limit=finite and error<=limit)
    totals[name]+=len(messages);maxerr[name]=max(maxerr[name],error)
   assert record['finite_inputs'] and all(x['pass_limit'] for x in record['operations'].values())
   rows.append(record);f.write(json.dumps(record)+'\n')
config=io.StringIO()
with contextlib.redirect_stdout(config):np.show_config()
(out/'numpy-config.txt').write_text(config.getvalue())
summary=dict(solves_recalculated=len(rows),optimizer_calls=0,numpy=np.__version__,scipy=scipy.__version__,python=sys.version,platform=platform.platform(),warnings_by_operation=dict(totals),maximum_absolute_errors=dict(maxerr),all_products_finite_and_match_scalar=True,warning_cases=sorted({r['case'] for r in rows if any(v['warnings'] for v in r['operations'].values())}),interpretation='Saved products agree with scalar calculations; this replay does not prove the low-level cause of original process warnings.')
(out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n');print(json.dumps(summary))
