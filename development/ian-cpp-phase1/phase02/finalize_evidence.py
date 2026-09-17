"""Freeze evidence and check provenance/coverage. Raw solutions: summarize.py."""
import argparse,json,subprocess,sys,hashlib
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from common import sha,write_json
from prepare import HISTORY,SOURCE
p=argparse.ArgumentParser();p.add_argument('--root',type=Path,required=True);p.add_argument('--analysis',type=Path,required=True);p.add_argument('--label',required=True);a=p.parse_args()
w=a.root.parent;repo=Path.cwd();phase=Path('development/ian-cpp-phase1/phase02');revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip()
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
assert repo==Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/implementation-worktree')
assert subprocess.check_output(['git','branch','--show-current'],text=True).strip()=='codex/ian-cpp-feasibility-20260917'
for filename in [f'final-checks-{a.label}.json',f'evidence-manifest-{a.label}.json']:assert not (a.root/filename).exists()
prior=json.loads((w/'evidence-manifest.json').read_text())
for path,item in prior['files'].items():assert sha(w/path)==item['sha256'],path
source_differences=[]
for path,item in prior['source_files'].items():
    # The original N1 wording correction is the only changed phase 1 source.
    expected=item['sha256'] if isinstance(item,dict) else item
    if sha(repo/path)!=expected:source_differences.append(path)
assert source_differences==['development/ian-cpp-phase1/verify_submission.py'],source_differences
frozen_sources=[]
for version,files in [('c334671',['prepare.py']),('cfa64f4',['diagnostic.py','run_diagnostics.py','supervise.py']),('20c3385',['CMakeLists.txt','sequence.cpp','sequence_python.py','validate_outputs.py','run_sequences.py','smoke.py'])]:
    for name in files:
        path=phase/name;expected=subprocess.check_output(['git','show',f'{version}:{path}']);assert path.read_bytes()==expected,str(path)
        frozen_sources.append(dict(path=str(path),revision=version,sha256=sha(path),unchanged=True))
measured=json.loads((a.root/'measured-v1/environment.json').read_text());assert measured['revision']=='38536577badda80fe151115614616ec9ef08bb68'
assert sha(a.root/'build-v1/ian_sequence')==measured['native_sha256']
assert sha(a.root/'fixtures-v2/manifest.json')==measured['fixtures_manifest_sha256']
for launch in (a.root/'measured-v1').glob('*/launch.json'):assert json.loads(launch.read_text())['revision']==measured['revision']
analysis=json.loads((a.analysis/'results.json').read_text());v=analysis['validation']
assert v['raw_sequence_vectors_checked']==96 and v['sequence_vectors_accepted']==96 and v['sequence_jobs_accepted']==18
assert v['raw_diagnostic_vectors_checked']==6 and v['diagnostics_accepted']==6
assert all(j['process']['sampled_max_processes']==1 for j in analysis['jobs'])
smoke=json.loads((a.root/'smoke-v1/checks.json').read_text());assert len(smoke)==14
assert sum('check' in s for s in smoke)==8 and sum('changed_shape_refused' in s for s in smoke)==2 and sum('adversary' in s for s in smoke)==4
assert len(list((a.root/'smoke-v1').glob('*/child/*.x.bin')))==10
reference_paths=[SOURCE,HISTORY/'trace.jsonl',HISTORY/'last_valid_graph.npz',HISTORY/'settings.json',HISTORY/'attempt-status.json',HISTORY/'phase-status.json',HISTORY/'resource-summary.json',HISTORY.parent/'combined_full_input.npz']
core=w/'deps/Clarabel.cpp/Clarabel.rs'
reference_paths += [core/'src/solver'/name for name in ['core/solver.rs','implementations/default/info.rs','implementations/default/data_updating.rs','core/kktsolvers/direct/quasidef/ldlsolvers/auto.rs','implementations/default/settings.rs','implementations/default/solver.rs']]
reference_paths += [w/'venv/lib/python3.12/site-packages/cvxpy/reductions/solvers/conic_solvers/clarabel_conif.py',w/'venv/lib/python3.12/site-packages/clarabel/clarabel.abi3.so',w/'build-v2/rust-target/release/libclarabel_c.dylib']
reference_paths += [Path(c['source']) for c in json.loads((a.root/'fixtures-v2/manifest.json').read_text())['cases']]
references={str(path):dict(sha256=sha(path),bytes=path.stat().st_size) for path in reference_paths}
check=dict(final_revision=revision,git_status='',cwd=str(repo),branch='codex/ian-cpp-feasibility-20260917',
   phase_base='1bcf77afb766fbb945595ce8c3326211bcfe0433',original_base='e7cde950dd86a411f1d41e707392789d33f5617c',
   measured_revision=measured['revision'],phase1_artifact_hashes_unchanged=len(prior['files']),phase1_source_differences=source_differences,
   execution_source_checks=frozen_sources,analysis_results_sha256=sha(a.analysis/'results.json'),
   coverage_checked=dict(measured_jobs=18,measured_solutions=96,diagnostics=6,smoke_optimizations=10,unsupported_update_refusals=2,adversarial_rejections=4),
   note='Coverage/summary and provenance checks here. Raw-vector revalidation is performed by phase02/summarize.py; its output is hashed above.',references=references)
write_json(a.root/f'final-checks-{a.label}.json',check)
files={str(path.relative_to(a.root)):dict(sha256=sha(path),bytes=path.stat().st_size) for path in sorted(a.root.rglob('*')) if path.is_file() and not path.name.startswith('evidence-manifest-')}
source_files={path:dict(sha256=sha(repo/path),bytes=(repo/path).stat().st_size) for path in subprocess.check_output(['git','ls-files','development/ian-cpp-phase1'],text=True).splitlines()}
write_json(a.root/f'evidence-manifest-{a.label}.json',dict(final_revision=revision,measured_revision=measured['revision'],files=files,source_files=source_files,
   note='Phase 2 raw/setup/analysis/build snapshot. Excludes this manifest and later handoff; preserves failed fixtures-v1 attempt. Phase 1 manifest verified separately.'))
print(json.dumps(dict(final_revision=revision,phase2_files=len(files),source_files=len(source_files),phase1_files_preserved=len(prior['files'])),indent=2))
