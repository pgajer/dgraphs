"""Final consistency checks without solving or changing historical evidence."""
import json,subprocess,sys
from pathlib import Path
import numpy as np
from common import sha,write_json
w=Path(sys.argv[1]);output=Path(sys.argv[2]);assert not output.exists()
base=Path('/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry/build')
history=base/'full-combined-hellinger-20260916-175755/combined_full_ian_4.5'
review=json.loads((base/'combined-ian-failure-review.json').read_text())
hashes={k:dict(expected=v,actual=sha(history/k)) for k,v in review['evidence_sha256'].items()}
assert all(r['expected']==r['actual'] for r in hashes.values())
manifest=json.loads((w/'fixtures-v1/manifest.json').read_text())
for c in manifest['cases']:
    assert sha(c['source'])==c['source_sha256']
    assert sha(c['trace'])==c['trace_sha256']
    assert sha(w/'fixtures-v1'/c['label']/'problem.bin')==c['binary_sha256']
rows=json.loads((w/'results-v2/attempts.json').read_text())
assert len(rows)==36 and all(r['accepted'] and r['exit_code']==0 for r in rows)
assert all(r['tree_processes']==1 for r in rows)
assert all(r['constraint_residual']<=1e-7 and r['objective_error']<=1e-7 for r in rows)
checks=[]
# Confirm current source used by measurements/build has not drifted.
for file,revision in [('replay.cpp','7ab4268'),('CMakeLists.txt','7ab4268'),('common.py','cba3b90'),('python_replay.py','cba3b90'),('run_benchmark.py','cba3b90'),('test_validation.py','cba3b90')]:
    path=Path('development/ian-cpp-phase1')/file
    original=subprocess.check_output(['git','show',f'{revision}:{path}'])
    same=path.read_bytes()==original;assert same
    checks.append(dict(path=str(path),revision=revision,identical=same,sha256=sha(path)))
write_json(output,dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
    final_status=subprocess.check_output(['git','status','--short'],text=True),
    historic_failure_hashes=hashes,fixtures_preserved=6,measured_solutions_revalidated=36,
    executable_source_unchanged=checks,
    historical_objective_max_relative_difference=max(r['historical_objective_relative_difference'] for r in rows),
    native_executable_sha256=sha(w/'build-v2/ian_lp_replay'),
    native_library_sha256=sha(w/'build-v2/rust-target/release/libclarabel_c.dylib')))
print('Verified all 36 measurements, six fixtures, historical evidence hashes and frozen executable source.')
