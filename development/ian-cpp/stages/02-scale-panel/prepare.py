"""Freeze the six remaining inputs and bind accepted runtime identities; no solves."""
import sys,json,hashlib,subprocess
from pathlib import Path
HERE=Path(__file__).resolve().parent
OLD=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase07f/fixtures-v1')
PRE=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/stage01-policy')
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
load=lambda p:json.loads(Path(p).read_text())
write=lambda p,v:Path(p).write_text(json.dumps(v,indent=2)+'\n')
out=Path(sys.argv[1]).resolve();out.mkdir(parents=True,exist_ok=False)
assert not subprocess.check_output(['git','status','--porcelain'],text=True)
build=PRE/'build-v1';ref=PRE/'reference-v2';bm=load(build/'manifest.json')
assert sha(build/'engine')==bm['binaries']['engine']
rmanifest=load(PRE/'reference-v2-manifest.json')
manifest=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),plan_sha256=sha(HERE/'PLAN.md'),build=str(build),engine_sha256=sha(build/'engine'),reference=str(ref),reference_sha256={p.name:sha(p) for p in ref.iterdir() if p.is_file()},accepted_reference_manifest=rmanifest,source_manifest=str(build/'manifest.json'),source_manifest_sha256=sha(build/'manifest.json'),original_manifest=str(OLD/'manifest.json'),original_manifest_sha256=sha(OLD/'manifest.json'),fixtures=[],prior_helix=dict(fresh=False,path=str(PRE/'qualification-v2/runs/helix_1000'),audit='/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-stage01-policy/audit.md'))
for c in load(OLD/'manifest.json')['cases'][1:]:
 p=Path(c['input']);assert sha(p)==c['sha256'];j=load(p);j['numerical_policy']='IAN evaluated-LP retry-power 0.1';target=out/(c['name']+'.json');write(target,j)
 assert {k:v for k,v in load(target).items() if k!='numerical_policy'}=={k:v for k,v in load(p).items() if k!='numerical_policy'}
 manifest['fixtures'].append(dict(name=c['name'],kind='scale',source=str(p),source_sha256=sha(p),path=str(target),sha256=sha(target),original=c))
write(out/'manifest.json',manifest)
print('Six original inputs frozen with the declared policy; no solves.')
