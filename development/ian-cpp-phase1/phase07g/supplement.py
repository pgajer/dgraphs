"""No-solve settings reconstruction and precise build receipts after replay."""
import subprocess
from support import *
root=Path(sys.argv[1]).resolve();folder=root/'settings-supplement';folder.mkdir(exist_ok=False)
deps=WORKER/'phase06a/clean-v2';lib=deps/'prefix/lib/libclarabel_c.dylib'
command=['/usr/bin/clang++','-std=c++17','-O3','-DNDEBUG','-ffp-contract=off','-I'+str(deps/'dependencies/Clarabel.cpp/include'),'-I'+str(WORKER/'phase03/deps'),str(HERE/'settings_probe.cpp'),str(lib),'-o',str(folder/'settings_probe')]
with (folder/'build.log').open('w') as f:subprocess.run(command,stdout=f,stderr=subprocess.STDOUT,check=True)
with (folder/'settings.json').open('w') as f:subprocess.run([str(folder/'settings_probe')],stdout=f,check=True)
settings=load(folder/'settings.json');ps=load(root/'runs/1/child/settings.json');assert len(settings)==38;assert all(settings[k]==ps[k] for k in settings)
receipts=[deps/'build-record.json',deps/'toolchain/stdout.log',deps/'rust-target/.rustc_info.json',deps/'rust-target/release/.fingerprint/clarabel-f9045ad1f88ea9e6/lib-clarabel.json']
for p in receipts:assert p.exists(),p
files={str(p):sha(p) for p in receipts}
for d in [deps/'dependencies/Clarabel.cpp/include',deps/'dependencies/Clarabel.cpp/rust_wrapper',deps/'dependencies/Clarabel.cpp/Clarabel.rs/src']:
    for p in d.rglob('*'):
        if p.is_file():files[str(p)]=sha(p)
write(folder/'record.json',dict(compiler_command=command,solver_calls=0,settings_count=len(settings),all_match_python=True,origin='Post-run reconstruction using identical pinned default function and the same explicit assignments; not a full in-process settings capture.',omission='Original settings.inc generator omitted multiline matching, recording only method/time limit and ABI metadata. Original outputs and executed source preserved; no re-solves.',build_receipts=files,dependency_revision_correction='environment.json dependency_heads resolved enclosing repository because copied dependencies lack .git; those two values are not dependency revisions. Exact source hashes, frozen build receipts and shared-library hashes identify the native build.',native_backend_sha256=sha(lib),replay_executable_sha256=sha(root/'build/ian_fixed_replay')))
result=load(root/'results.json');result['settings_supplement']=dict(path=str(folder/'record.json'),reconstructed_shared_fields=38,all_match_python=True,solver_calls=0);write(root/'results-v2.json',result)
