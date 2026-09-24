"""Capture primary historical evidence and local toolchain without running IAN."""
import json,subprocess,sys,platform
from pathlib import Path
import numpy as np
from common import sha,write_json
worker=Path(sys.argv[1]); exp=Path('/Users/pgajer/current_projects/ZB/experiments/038-ian-community-graph-geometry')
frozen=Path('/Users/pgajer/.codex/private/ZB/exp038-full-cohorts/20260916-175755/source')
run=exp/'build/full-combined-hellinger-20260916-175755'
files=[frozen/'scripts'/n for n in ['run_ian_pilot.py','pilot_audit.py','pilot_control.py','pilot_graphs.py','prepare_ian_adapter.py','run_full_cohort_background.py']]
files += [frozen/'config/pilot-plan.json',run/'status.json',run/'input-validation.json',exp/'build/combined-ian-failure-review.md',exp/'build/combined-ian-failure-review.json',Path('/Users/pgajer/current_projects/ZB/docs/project_aims.md')]
settings=json.loads((run/'combined_full_ian_4.5/settings.json').read_text())
checks={}
for relative,h in settings['execution_identity'].items():
    p=frozen/relative
    if p.exists(): checks[relative]=dict(expected=h,actual=sha(p),match=sha(p)==h)
assert all(r['match'] for r in checks.values())
upstream={}
for name in ['ian.py','cutils.pyx']:
    path=exp/'build/source-evidence/ian/ian'/name
    upstream[name]=dict(local_sha256=sha(path),download_sha256=sha(worker/'setup'/('upstream-'+name)))
    assert upstream[name]['local_sha256']==upstream[name]['download_sha256']
with np.load(run/'combined_full_input.npz') as z:
    input_schema={k:dict(shape=list(z[k].shape),dtype=str(z[k].dtype)) for k in z.files}
core=worker/'deps/Clarabel.cpp/Clarabel.rs'
def cmd(args):return subprocess.check_output(args,text=True).strip()
write_json(worker/'setup/provenance.json',dict(revision=cmd(['git','rev-parse','HEAD']),
  historical_identity_checks=checks,upstream_checks=upstream,source_hashes={str(p):sha(p) for p in files},
  controller_status=json.loads((run/'status.json').read_text()),input_schema=input_schema,
  cpp_commit=cmd(['git','-C',str(core.parent),'rev-parse','HEAD']),core_commit=cmd(['git','-C',str(core),'rev-parse','HEAD']),
  core_tag=cmd(['git','-C',str(core),'describe','--tags','--always']),
  python=sys.version,platform=platform.platform(),clang=cmd(['/usr/bin/clang++','--version']),cmake=cmd(['cmake','--version']),
  rust=cmd([str(worker/'rustup/toolchains/1.85.1-aarch64-apple-darwin/bin/rustc'),'--version']),
  cargo=cmd([str(worker/'rustup/toolchains/1.85.1-aarch64-apple-darwin/bin/cargo'),'--version'])))
