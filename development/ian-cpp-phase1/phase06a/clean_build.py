"""Fresh private dependency build and installed-header consumer feasibility."""
import argparse
import os
import shutil
import subprocess
import sys
from pathlib import Path

HERE=Path(__file__).resolve().parent
sys.path.insert(0,str(HERE.parent/'phase04'))
from support import revision,write,sha

p=argparse.ArgumentParser()
p.add_argument('worker',type=Path)
p.add_argument('output',type=Path)
a=p.parse_args()
rev=revision()
a.output.mkdir(parents=True,exist_ok=False)
record=dict(revision=rev,commands=[],complete=False)
def save():write(a.output/'build-record.json',record)
def call(name,args,env,cwd=None):
    folder=a.output/name;folder.mkdir()
    with (folder/'stdout.log').open('w') as out,(folder/'stderr.log').open('w') as err:
        result=subprocess.run(list(map(str,args)),cwd=cwd or a.output,env=env,stdout=out,stderr=err)
    record['commands'].append(dict(name=name,command=list(map(str,args)),cwd=str(cwd or a.output),exit_code=result.returncode))
    save()
    print(name,'exit',result.returncode,flush=True)
    if result.returncode:raise SystemExit('Clean build stopped; failed logs retained.')

rust=a.worker/'rustup/toolchains/1.85.1-aarch64-apple-darwin/bin'
env=dict(PATH=str(rust)+':/usr/bin:/bin:/usr/sbin:/sbin',HOME=os.environ['HOME'],
    CARGO_HOME=str(a.output/'cargo-home'),TMPDIR=str(a.output/'tmp'),CARGO_BUILD_JOBS='2',
    OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',VECLIB_MAXIMUM_THREADS='1',MKL_NUM_THREADS='1',
    SDKROOT=subprocess.check_output(['/usr/bin/xcrun','--show-sdk-path'],text=True).strip())
(a.output/'cargo-home').mkdir();(a.output/'tmp').mkdir()
record['environment']=env
record['isolation']='Fresh Cargo home, vendored crates, copied source, target directory and install prefix; same host/compiler/SDK and OS account home. No development dependency binary reused.'
source=a.output/'source'
shutil.copytree(HERE,source)
deps=a.output/'dependencies'
shutil.copytree(a.worker/'deps/Clarabel.cpp',deps/'Clarabel.cpp',ignore=shutil.ignore_patterns('.git','target'))
(deps/'json').mkdir()
shutil.copy2(a.worker/'phase03/deps/json.hpp',deps/'json/json.hpp')
lock=deps/'Clarabel.cpp/rust_wrapper/Cargo.lock'
record['lock_sha256']=sha(lock)
record['source_files']={str(f.relative_to(source)):sha(f) for f in source.rglob('*') if f.is_file()}
record['dependency_sources']={str(f.relative_to(deps)):sha(f) for f in deps.rglob('*') if f.is_file()}
save()
call('toolchain',[rust/'rustc','--version','--verbose'],env)
call('vendor-command',[rust/'cargo','vendor','--locked','--versioned-dirs','--manifest-path',
    deps/'Clarabel.cpp/rust_wrapper/Cargo.toml',a.output/'vendor'],env)
(a.output/'cargo-home/config.toml').write_text('[source.crates-io]\nreplace-with = "vendored-sources"\n[source.vendored-sources]\ndirectory = "'+str(a.output/'vendor')+'"\n')
call('solver',[rust/'cargo','build','--frozen','--offline','--release','--manifest-path',
    deps/'Clarabel.cpp/rust_wrapper/Cargo.toml','--target-dir',a.output/'rust-target'],env)
assert sha(lock)==record['lock_sha256']
backend=a.output/'rust-target/release/libclarabel_c.dylib'
call('backend-id',['/usr/bin/install_name_tool','-id','@rpath/libclarabel_c.dylib',backend],env)
cmake='/opt/homebrew/bin/cmake'
prefix=a.output/'prefix'
call('configure',[cmake,'-S',source,'-B',a.output/'build','-DCMAKE_BUILD_TYPE=Release',
    '-DCMAKE_CXX_COMPILER=/usr/bin/clang++','-DCMAKE_INSTALL_PREFIX='+str(prefix),
    '-DCLARABEL_SOURCE='+str(deps/'Clarabel.cpp'),'-DCLARABEL_LIBRARY='+str(backend),
    '-DJSON_INCLUDE='+str(deps/'json')],env)
call('build-core',[cmake,'--build',a.output/'build','-j2'],env)
call('install',[cmake,'--install',a.output/'build'],env)
shutil.copy2(deps/'Clarabel.cpp/LICENSE.md',prefix/'share/ian/Clarabel-LICENSE.md')
rhome=Path(subprocess.check_output(['/usr/local/bin/R','RHOME'],text=True).strip())
call('configure-consumer',[cmake,'-S',source/'tests/consumer','-B',a.output/'consumer-build',
    '-DCMAKE_BUILD_TYPE=Release','-DCMAKE_CXX_COMPILER=/usr/bin/clang++','-DCMAKE_PREFIX_PATH='+str(prefix),
    '-DR_INCLUDE='+str(rhome/'include'),'-DR_LIBRARY='+str(rhome/'lib/libR.dylib'),
    '-DR_BRIDGE_SOURCE='+str(source/'src/r_bridge.cpp')],env)
call('build-consumer',[cmake,'--build',a.output/'consumer-build','-j2'],env)
for name,path in [('backend-links',backend),('engine-links',a.output/'build/ian_engine'),
                  ('consumer-links',a.output/'consumer-build/ian_consumer'),('r-links',a.output/'consumer-build/ian_bridge.so')]:
    call(name,['/usr/bin/otool','-L',path],env)
    text=(a.output/name/'stdout.log').read_text()
    assert '/worker/build-v2/' not in text and '/worker/deps/' not in text and '/worker/phase06a/build-v1' not in text
record['backend_sha256']=sha(backend)
record['installed_backend_sha256']=sha(prefix/'lib/libclarabel_c.dylib')
assert record['backend_sha256']==record['installed_backend_sha256']
record['vendor_packages']=len(list((a.output/'vendor').iterdir()))
record['complete']=True
save()
print('Fresh dependency build and external consumer/R bridge compilation complete.',flush=True)
