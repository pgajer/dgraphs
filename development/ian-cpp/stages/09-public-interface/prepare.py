"""Prepare private libraries and a frozen schedule from accepted evidence; no solves."""
from pathlib import Path
import sys,json,os,hashlib,subprocess,shutil
H=Path(__file__).resolve().parent;P=Path(sys.argv[1]).resolve();P.mkdir(exist_ok=False);B=P.parent
load=lambda p:json.loads(p.read_text());write=lambda p,v:p.write_text(json.dumps(v,indent=2)+'\n');sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
old=load(B/'stage03-package/environment.json');cargo=P/'cargo-home';cargo.mkdir();source=Path(old['runtimes']['r45-v3']['env']['CARGO_HOME'])/'config.toml';shutil.copy2(source,cargo/'config.toml')
config=dict(runtimes={},cargo_config_sha256=sha(cargo/'config.toml'),reused_environment=str(B/'stage03-package/environment.json'),revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip())
for label,previous in [('rdevel','rdevel-v2'),('r45','r45-v3')]:
 prior=old['runtimes'][previous];folder=P/label;folder.mkdir();lib=folder/'library';lib.mkdir();env=dict(prior['env']);env.update(CARGO_HOME=str(cargo),R_LIBS=str(lib)+':'+prior['library'],R_LIBS_USER=str(lib),R_LIBS_SITE=str(lib)+':'+prior['library'],MAKEFLAGS='-j2')
 if label=='r45':
  m=folder/'Makevars';shutil.copy2(env['R_MAKEVARS_USER'],m);env['R_MAKEVARS_USER']=str(m)
 config['runtimes'][label]=dict(r=prior['r'],rscript=prior['rscript'],library=str(lib),env=env,prior_dependency_library=prior['library'],backend=str(folder/'backend with spaces/dgraphs_ian.so'))
write(P/'environment.json',config)
schedule=[]
for name in ['nonuniform_curve','variable_density_patch','nearby_curved_arms','pressmat_hellinger_subset']:
 schedule.append(dict(name='strict-'+name,fixture=str(B/'stage01-policy/build-v1/fixtures'/(name+'-strict.json')),baseline=str(B/'stage01-policy/supplement-v1'/('R-strict-'+name)/'child/result.rds'),mode='strict',detail='full'))
for name in ['square-6101','helix-6101','sphere-6101']:
 schedule.append(dict(name='saved-'+name,fixture=str(B/'connected-pruning/fixtures'/(name+'-connected.json')),baseline=str(B/'connected-pruning/runs'/name/'R/child/result.rds'),mode='default',detail='full'))
for c in load(B/'r-size-qualification/fixtures.json')['cases']:
 if c['stage']=='conditional':continue
 baseline=(B/'r-size-qualification/panel-v2/runs'/(c['name']+'-connected')/'R/child/result.rds') if c['stage']=='main' else B/'r-size-qualification/supplement-v1/runs'/c['name']/'R/child/result.rds'
 schedule.append(dict(name=c['name'],metadata=c['metadata'],baseline=str(baseline),mode='default',detail='summary'))
 if c['name']=='helix_1000':schedule.append(dict(name='explicit-helix_1000',metadata=c['metadata'],baseline=str(baseline),mode='explicit',detail='full'))
assert len(schedule)==17
paths=set()
for c in schedule:
 paths.add(Path(c['baseline']));paths.add(Path(c.get('metadata',c.get('fixture'))))
 if 'metadata' in c:
  m=load(Path(c['metadata']));paths.update(Path(m[k]) for k in ['features','distances'])
write(P/'fixtures.json',dict(cases=schedule,files={str(p):sha(p) for p in sorted(paths)}))
print('Two private R environments and 17 frozen regression cases prepared; zero engine calls.')
