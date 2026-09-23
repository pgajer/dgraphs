#!/usr/bin/env python3
"""Build the optional IAN module from installed, pinned sources; never runs solves."""
import argparse, hashlib, json, os, platform, shutil, subprocess, zipfile, signal, time
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--build-dir',required=True,type=Path)
p.add_argument('--install-dir',type=Path,help='Optional directory receiving dgraphs_ian.so (usually installed dgraphs/ian/native)')
p.add_argument('--rustc',default=os.environ.get('RUSTC','rustc'),help='Native arm64 Rust compiler; must match the selected Cargo toolchain')
p.add_argument('--cargo',default='cargo');p.add_argument('--r',default='R');p.add_argument('--rscript',default='Rscript');p.add_argument('--cxx',default='clang++')
p.add_argument('--offline',action='store_true');a=p.parse_args()
if platform.system()!='Darwin' or platform.machine()!='arm64':p.error('This bounded backend build supports macOS arm64 only; other platforms are unqualified.')
src=Path(__file__).resolve().parent/'backend';out=a.build_dir.resolve();out.mkdir(parents=True,exist_ok=False)
record={'commands':[],'complete':False,'platform':platform.platform(),'sources':{}}
def save():
 tmp=out/'build-record.tmp';tmp.write_text(json.dumps(record,indent=2)+'\n');os.replace(tmp,out/'build-record.json')
def call(name,cmd,env=None):
 row=dict(name=name,command=list(map(str,cmd)),state='reserved',timeout_seconds=1800);record['commands'].append(row);save()
 start=time.monotonic();proc=None
 try:
  with (out/(name+'.log')).open('w') as log:
   proc=subprocess.Popen(row['command'],stdout=log,stderr=subprocess.STDOUT,env=env,start_new_session=True)
   row.update(state='running',pid=proc.pid);save()
   proc.wait(timeout=1800)
 except BaseException as error:
  row['error']=repr(error)
  if proc is not None and proc.poll() is None:
   os.killpg(proc.pid,signal.SIGTERM)
   try:proc.wait(timeout=5)
   except subprocess.TimeoutExpired:os.killpg(proc.pid,signal.SIGKILL);proc.wait()
  raise
 finally:
  row.update(state='reaped' if proc is not None else 'launch_failed',returncode=proc.returncode if proc else None,seconds=time.monotonic()-start);save()
 print(name,row['returncode'],flush=True)
 if row['returncode']:raise SystemExit('Build failed; logs retained in '+str(out))
source=out/'sources'
if src.is_dir():
 shutil.copytree(src,source)
else:
 bundle=src.parent/'backend-sources.zip';manifest=src.parent/'backend-source-manifest.json'
 try:
  declared=json.loads(manifest.read_text())
  if hashlib.sha256(bundle.read_bytes()).hexdigest()!=declared['zip_sha256']:raise ValueError('source archive digest mismatch')
  with zipfile.ZipFile(bundle) as z:
   if len(z.namelist())!=len(declared['files']) or set(z.namelist())!=set(declared['files']):raise ValueError('source archive inventory mismatch')
   for name,digest in declared['files'].items():
    relative=Path(name)
    if relative.is_absolute() or '..' in relative.parts:raise ValueError('invalid source archive path')
    data=z.read(name)
    if hashlib.sha256(data).hexdigest()!=digest:raise ValueError('source member digest mismatch: '+name)
    target=source/relative;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(data)
  record['source_bundle']={'path':str(bundle),'sha256':declared['zip_sha256'],'manifest_sha256':hashlib.sha256(manifest.read_bytes()).hexdigest()}
 except Exception as error:
  record['error']='Invalid installed source bundle: '+str(error);save();raise SystemExit(record['error'])
record['sources']={str(f.relative_to(source)):hashlib.sha256(f.read_bytes()).hexdigest() for f in source.rglob('*') if f.is_file()}
save()
# Bind compilation to the selected R runtime before building the solver.
call('r-home',[a.r,'RHOME'])
call('rscript-info',[a.rscript,'--vanilla','-e',"cat(R.home(),R.version$arch,system.file('include',package='Rcpp'),sep='\\n')"])
rhome=Path((out/'r-home.log').read_text().strip()).resolve()
rinfo=(out/'rscript-info.log').read_text().strip().splitlines()
if len(rinfo)!=3 or Path(rinfo[0]).resolve()!=rhome or rinfo[1] not in ['aarch64','arm64'] or not Path(rinfo[2]).is_dir():
 record['error']='R and Rscript must select the same native arm64 R installation with Rcpp available.';save();raise SystemExit(record['error'])
rcpp=Path(rinfo[2]);record['R_runtime']=dict(home=str(rhome),arch=rinfo[1],rcpp_include=str(rcpp));save()
env=os.environ.copy();env['CARGO_BUILD_JOBS']='2';env['RUSTC']=a.rustc
call('cargo-version',[a.cargo,'--version'])
call('rust-version',[a.rustc,'-vV'])
if 'host: aarch64-apple-darwin' not in (out/'rust-version.log').read_text():
 record['error']='Native macOS arm64 Rust is required; select --rustc and --cargo from the same arm64 toolchain.';save();raise SystemExit(record['error'])
call('solver',[a.cargo,'build','--locked','--release','--lib',*(['--offline'] if a.offline else []),'--manifest-path',source/'Clarabel.cpp/rust_wrapper/Cargo.toml','--target-dir',out/'target'],env)
identity=hashlib.sha256(json.dumps(record['sources'],sort_keys=True).encode()).hexdigest();config=hashlib.sha256((source/'core/config.json').read_bytes()).hexdigest()
module=out/'dgraphs_ian.so'
call('module',[a.cxx,'-std=c++17','-O2','-ffp-contract=off','-fno-fast-math','-fPIC','-shared','-undefined','dynamic_lookup','-Wl,-install_name,@rpath/dgraphs_ian.so',
 '-I'+str(rhome/'include'),'-I'+str(rcpp),'-I'+str(source/'core/include'),'-I'+str(source/'core/src'),'-I'+str(source/'Clarabel.cpp/include'),
 '-DSOURCE_HASH="'+identity+'"','-DCONFIG_HASH="'+config+'"',source/'core/src/core.cpp',source/'core/src/identity_json.cpp',source/'bridge.cpp',out/'target/release/libclarabel_c.a','-framework','Security','-framework','CoreFoundation','-o',module])
record['module_sha256']=hashlib.sha256(module.read_bytes()).hexdigest();record['core_source_identity']=identity
if a.install_dir:
 a.install_dir.mkdir(parents=True,exist_ok=True);shutil.copy2(module,a.install_dir/module.name)
record['complete']=True;save()
