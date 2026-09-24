"""Use the actual Phase07E small runs for matching-policy baseline comparisons.

The fixture manifest links older pre-retry runs. Those numerical comparisons pass,
but lack the added retry metadata and therefore correctly fail the full contract.
Preserve that result and add the matching-policy comparisons separately. No solves.
"""
from common import *
root=Path(sys.argv[1]);out=root/'baseline-supplement';out.mkdir(exist_ok=False)
summary=load(root/'analysis-v1/summary.json');results={}
for i in range(6,14):
 cell=summary['runs'][i];baseline=W/f"phase07e/trajectory-v1/{cell['name']}/{cell['interface']}/child/trace.jsonl"
 folder=out/str(i);folder.mkdir()
 cmd=[sys.executable,'-B',str(E/'validate.py'),'compare',str(baseline),str(root/f'runs/{i}/child/trace.jsonl'),str(folder/'checks')]
 with (folder/'stdout.log').open('w') as f:subprocess.run(cmd,stdout=f,stderr=subprocess.STDOUT,check=True)
 results[str(i)]=load(folder/'checks/summary.json')
 assert results[str(i)]['passed']
write(out/'summary.json',dict(passed=True,comparisons=results,optimizer_calls=0,original_analysis_sha256=sha(root/'analysis-v1/summary.json'),explanation=__doc__))
print('All eight matching-policy small baseline comparisons pass; zero solves.')
