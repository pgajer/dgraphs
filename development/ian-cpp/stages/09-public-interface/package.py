"""Bounded archive/install/build/check dispatch with durable separate command records."""
import sys,json,subprocess,shutil
from pathlib import Path
H=Path(__file__).resolve().parent;P=Path(sys.argv[1]);mode=sys.argv[2];runtime=sys.argv[3] if len(sys.argv)>3 else 'rdevel';M=json.loads((P/'environment.json').read_text());C=M['runtimes'][runtime];archive=P/'dgraphs_0.3.0.9000.tar.gz';ROOT=H.parents[3]
def call(label,args):subprocess.run([sys.executable,str(H/'command.py'),str(P),runtime,label,*map(str,args)],check=True)
if mode=='archive':
 call('archive',['make','build']);shutil.copy2(ROOT/'build/dgraphs_0.3.0.9000.tar.gz',archive)
elif mode=='install':
 call('install',[C['r'],'CMD','INSTALL','--library='+C['library'],archive])
 call('targeted-tests',[C['rscript'],'--vanilla','-e',f'.libPaths(c("{C["library"]}",.libPaths()));library(dgraphs);testthat::test_file("tests/testthat/test-ian-interface.R",stop_on_failure=TRUE)'])
 pin=Path(C['env']['RUSTC']).parent
 call('backend',[C['rscript'],'--vanilla',H/'build_backend.R',C['library'],Path(C['backend']).parent,sys.executable,pin/'cargo',pin/'rustc'])
 # Validate actual main-library linkage in the named runtime.
 call('linkage',['otool','-L',Path(C['library'])/'dgraphs/libs/dgraphs.so'])
elif mode=='check':
 folder=P/runtime/'check';folder.mkdir(exist_ok=False)
 # command.py executes from its cwd and records it.
 subprocess.run([sys.executable,str(H/'command.py'),str(P),runtime,'check',C['r'],'CMD','check','--as-cran',str(archive)],cwd=folder,check=True,env=__import__('os').environ|dict(R_PROFILE_USER=str(ROOT/'dev/check-profile.R'),R_TIDYCMD='/opt/homebrew/bin/tidy'))
