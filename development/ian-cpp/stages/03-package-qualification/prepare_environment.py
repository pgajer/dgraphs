"""Prepare private libraries/launchers and inventory actual runtimes; zero IAN calls."""
import json,os,sys,shutil,subprocess,hashlib
from pathlib import Path
root=Path(sys.argv[1]).resolve();root.mkdir(exist_ok=True)
sha=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest()
pin=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/rustup/toolchains/1.85.1-aarch64-apple-darwin/bin')
cargo=root/'cargo-home';cargo.mkdir();(cargo/'config.toml').write_text('[source.crates-io]\nreplace-with = "vendored-sources"\n[source.vendored-sources]\ndirectory = "/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-17/worker/phase06a/clean-v2/vendor"\n')
manifest=dict(runtimes={},rustc=str(pin/'rustc'),cargo=str(pin/'cargo'),cargo_config_sha256=sha(cargo/'config.toml'))
for label in ['rdevel','r45']:
 folder=root/label;folder.mkdir();lib=folder/'library';lib.mkdir()
 env={k:os.environ[k] for k in ['PATH','R_LIBS','R_LIBS_USER','R_LIBS_SITE'] if k in os.environ}
 env.update(CARGO_HOME=str(cargo),RUSTC=str(pin/'rustc'),CARGO_BUILD_JOBS='2',MAKEFLAGS='-j2',OMP_NUM_THREADS='1',OPENBLAS_NUM_THREADS='1',VECLIB_MAXIMUM_THREADS='1',MKL_NUM_THREADS='1',RAYON_NUM_THREADS='1')
 if label=='r45':
  orig=Path('/Library/Frameworks/R.framework/Versions/4.5-arm64/Resources');home=folder/'rhome';home.mkdir();shutil.copytree(orig/'bin',home/'bin')
  for p in orig.iterdir():
   if p.name!='bin':(home/p.name).symlink_to(p,target_is_directory=p.is_dir())
  for p in (home/'bin').rglob('*'):
   if p.is_file():
    b=p.read_bytes()
    if b.startswith(b'#!') or p.name in ['INSTALL','Rcmd']:
     try:p.write_text(b.decode().replace('/Library/Frameworks/R.framework/Resources',str(home)))
     except UnicodeDecodeError:pass
  script=home/'bin/Rscript';script.unlink();script.write_text('#!/usr/bin/env python3\nimport os,sys\nargs=sys.argv[1:];prefix=[]\nwhile args and args[0].startswith("--"):prefix.append(args.pop(0))\nif args and args[0]=="-e":tail=args\nelse:tail=["--file="+args[0],"--args",*args[1:]]\nos.execv('+repr(str(home/'bin/exec/R'))+', ["R","--slave",*prefix,*tail])\n');script.chmod(0o755)
  dep=Path('/Users/pgajer/.codex/private/ZB/ian-cpp/2026-09-23/auditor/review-adapter-layout/r45/library/RcppEigen');shutil.copytree(dep,lib/'RcppEigen')
  manifest['reused_r45_dependency']=dict(source=str(dep),files={str(p.relative_to(dep)):sha(p) for p in dep.rglob('*') if p.is_file()})
  env.update(R_HOME=str(home),R_LIBS=str(lib),R_LIBS_USER=str(lib),R_LIBS_SITE=str(lib))
 else:
  home=Path('/Library/Frameworks/R.framework/Resources');env['R_LIBS']=str(lib)+(':'+env['R_LIBS'] if env.get('R_LIBS') else '')
 env['PATH']=str(home/'bin')+':'+str(pin)+':'+env['PATH'];R=home/'bin/R';Rs=home/'bin/Rscript'
 actual=os.environ.copy();actual.pop('R_HOME',None);actual.update(env)
 expression='cat(R.version.string,"\\n",R.version$arch,"\\n",R.home(),"\\n"); print(.libPaths()); for(p in c("Rcpp","RcppEigen","igraph","jsonlite","testthat","roxygen2","nloptr")) cat(p,if(requireNamespace(p,quietly=TRUE)) as.character(packageVersion(p)) else "MISSING","\\n"); print(sessionInfo())'
 result=subprocess.run([str(Rs),'--vanilla','-e',expression],env=actual,capture_output=True,text=True)
 (folder/'inventory.log').write_text(result.stdout+result.stderr);assert result.returncode==0,result.stderr
 assert ('R version 4.5.2' in result.stdout) if label=='r45' else ('R Under development' in result.stdout)
 manifest['runtimes'][label]=dict(r=str(R),rscript=str(Rs),library=str(lib),env=env)
(root/'environment.json').write_text(json.dumps(manifest,indent=2)+'\n');print('Two actual R runtimes inventoried; no IAN calls.')
