"""Bind unchanged indirect Python sources as observed during each actual entry."""
import sys,json,hashlib
from pathlib import Path
P=Path(sys.argv[1]);out=P/'indirect-source-checks.json';assert not out.exists()
base=P.parent/'stage04-performance/qual-evaluated-pressmat_hellinger_subset/child/source/provenance.json';expected=json.loads(base.read_text());rows=[]
for p in sorted(P.glob('runs/*/evaluated/child/source/provenance.json')):
 assert json.loads(p.read_text())==expected
 rows.append(dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest(),matches_accepted_reference=True))
assert len(rows)==9
out.write_text(json.dumps(dict(passed=True,baseline=str(base),baseline_sha256=hashlib.sha256(base.read_bytes()).hexdigest(),checks=rows),indent=2)+'\n');print('All nine original-source/adapter/audit/Cython provenance records match the accepted reference.')
