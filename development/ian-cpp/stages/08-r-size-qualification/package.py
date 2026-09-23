"""Private archive build/install/check with explicit command accounting."""
import sys,os,json,subprocess,time,shutil
from pathlib import Path
P=Path(sys.argv[1]);mode=sys.argv[2];R=Path.cwd();out=P/('package-'+mode);out.mkdir(exist_ok=False);record=dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),commands=[])
def call(name,cmd,cwd=R,extra=None,limit=1200):
 env=dict(os.environ,**(extra or {}));start=time.monotonic();row=dict(name=name,command=list(map(str,cmd)),cwd=str(cwd),environment=extra or {},timeout=limit,state='reserved');record['commands'].append(row);save()
 with (out/(name+'.log')).open('w') as log:
  try:p=subprocess.run(list(map(str,cmd)),cwd=cwd,env=env,stdout=log,stderr=subprocess.STDOUT,timeout=limit);row.update(exit_code=p.returncode,state='reaped',seconds=time.monotonic()-start);save();assert p.returncode==0,name
  except BaseException as e:row.update(error=repr(e),seconds=time.monotonic()-start);save();raise
 def_unused=None

def save():(out/'commands.json').write_text(json.dumps(record,indent=2)+'\n')
rb='/Library/Frameworks/R.framework/Resources/bin/'
if mode=='build':
 call('build',['make','build']);shutil.copy2(R/'build/dgraphs_0.3.0.9000.tar.gz',P/'dgraphs_0.3.0.9000.tar.gz');(P/'library').mkdir()
 call('install',[rb+'R','CMD','INSTALL','--library='+str(P/'library'),P/'dgraphs_0.3.0.9000.tar.gz'])
 call('tests',[rb+'Rscript','--vanilla','-e',f'.libPaths(c("{P}/library",.libPaths())); library(dgraphs); testthat::test_file("tests/testthat/test-ian-interface.R", stop_on_failure=TRUE)'])
else:
 call('check',[rb+'R','CMD','check','--as-cran',P/'dgraphs_0.3.0.9000.tar.gz'],cwd=out,extra=dict(R_PROFILE_USER=str(R/'dev/check-profile.R'),R_TIDYCMD='/opt/homebrew/bin/tidy'),limit=1800)
record['complete']=True;save()
