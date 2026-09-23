#!/usr/bin/env python3
"""Build the optional IAN module from installed, pinned sources; never runs solves."""
import argparse, hashlib, json, os, platform, shutil, subprocess
from pathlib import Path
p=argparse.ArgumentParser(description=__doc__)
p.add_argument('--build-dir',required=True,type=Path)
p.add_argument('--install-dir',type=Path,help='Optional directory receiving dgraphs_ian.so (usually installed dgraphs/ian/native)')
p.add_argument('--rustc',default=os.environ.get('RUSTC','rustc'),help='Native arm64 Rust compiler; must match the selected Cargo toolchain')
p.add_argument('--cargo',default='cargo');p.add_argument('--r',default='R');p.add_argument('--rscript',default='Rscript');p.add_argument('--cxx',default='clang++')
p.add_argument('--offline',action='store_true');a=p.parse_args()
if platform.system()!='Darwin' or platform.machine()!='arm64':p.error('This bounded backend build supports macOS arm64 only; other platforms are unqualified.')
src=Path(__file__).resolve().parent/'backend';out=a.build_dir.resolve();out.mkdir(parents=True,exist_ok=False)
record={'commands':[],'complete':False,'platform':platform.platform(),'sources':{str(f.relative_to(src)):hashlib.sha256(f.read_bytes()).hexdigest() for f in src.rglob('*') if f.is_file()}}
def save(): (out/'build-record.json').write_text(json.dumps(record,indent=2)+'\n')
def call(name,cmd,env=None):
 with (out/(name+'.log')).open('w') as log:
  x=subprocess.run(list(map(str,cmd)),stdout=log,stderr=subprocess.STDOUT,env=env)
 record['commands'].append({'name':name,'command':list(map(str,cmd)),'returncode':x.returncode});save()
 print(name,x.returncode,flush=True)
 if x.returncode:raise SystemExit('Build failed; logs retained in '+str(out))
shutil.copytree(src,out/'sources');source=out/'sources'
env=os.environ.copy();env['CARGO_BUILD_JOBS']='2';env['RUSTC']=a.rustc
call('cargo-version',[a.cargo,'--version'])
call('rust-version',[a.rustc,'-vV'])
if 'host: aarch64-apple-darwin' not in (out/'rust-version.log').read_text():
 record['error']='Native macOS arm64 Rust is required; select --rustc and --cargo from the same arm64 toolchain.';save();raise SystemExit(record['error'])
call('solver',[a.cargo,'build','--locked','--release','--lib',*(['--offline'] if a.offline else []),'--manifest-path',source/'Clarabel.cpp/rust_wrapper/Cargo.toml','--target-dir',out/'target'],env)
rhome=Path(subprocess.check_output([a.r,'RHOME'],text=True).strip())
rcpp=Path(subprocess.check_output([a.rscript,'--vanilla','-e','cat(system.file("include",package="Rcpp"))'],text=True).strip())
identity=hashlib.sha256(json.dumps(record['sources'],sort_keys=True).encode()).hexdigest();config=hashlib.sha256((source/'core/config.json').read_bytes()).hexdigest()
module=out/'dgraphs_ian.so'
call('module',[a.cxx,'-std=c++17','-O2','-ffp-contract=off','-fno-fast-math','-fPIC','-shared','-undefined','dynamic_lookup','-Wl,-install_name,@rpath/dgraphs_ian.so',
 '-I'+str(rhome/'include'),'-I'+str(rcpp),'-I'+str(source/'core/include'),'-I'+str(source/'core/src'),'-I'+str(source/'Clarabel.cpp/include'),
 '-DSOURCE_HASH="'+identity+'"','-DCONFIG_HASH="'+config+'"',source/'core/src/core.cpp',source/'core/src/identity_json.cpp',source/'bridge.cpp',out/'target/release/libclarabel_c.a','-framework','Security','-framework','CoreFoundation','-o',module])
record['module_sha256']=hashlib.sha256(module.read_bytes()).hexdigest();record['core_source_identity']=identity
if a.install_dir:
 a.install_dir.mkdir(parents=True,exist_ok=True);shutil.copy2(module,a.install_dir/module.name)
record['complete']=True;save()
