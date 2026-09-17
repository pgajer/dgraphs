"""One predeclared conditional-cap guard check; does not replace any fixture."""
import argparse,json,subprocess
from pathlib import Path
from reference import sha,write
p=argparse.ArgumentParser();p.add_argument('fixtures',type=Path);p.add_argument('output',type=Path);a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
d=json.loads((a.fixtures/'stages.json').read_text());d['decisions'].append(dict(name='smaller_cap_must_not_apply_with_outlier',stats=[1.]*15+[2.]*10+[9.]*6,median=1.))
write(a.output/'stages.json',d);write(a.output/'manifest.json',dict(revision=subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),source=sha(a.fixtures/'stages.json'),files={'stages.json':sha(a.output/'stages.json')},expected='threshold equals max(2.75, raw C3 threshold) > 5 despite cap 5, because max statistic 9 exceeds uncapped threshold'))
