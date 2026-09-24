"""Original-expression-only bounded calibration; every attempt is retained."""
import argparse
import json
import subprocess
import sys
from pathlib import Path
from reference_probe import run

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'phase03'))
from reference import write, sha
from compare import traces, check_lp

p = argparse.ArgumentParser()
p.add_argument('fixtures', type=Path)
p.add_argument('output', type=Path)
a = p.parse_args()
assert not subprocess.check_output(['git', 'status', '--porcelain'], text=True)
a.output.mkdir(parents=True, exist_ok=False)
cases = []
for name in ['known_256', 'known_300']:
    base = json.loads((a.fixtures / (name + '.json')).read_text())
    for label, factor in [('minus', 1 - 2.0 ** -24), ('center', 1.), ('plus', 1 + 2.0 ** -24)]:
        inp = dict(base, C=base['C'] * factor, action='solve', name=f'{name}_{label}')
        path = a.output / (inp['name'] + '.json')
        write(path, inp)
        cases.append(dict(name=inp['name'], input=str(path), sha256=sha(path), group=name, action='solve'))
calibrations = []
for name in ['pruning_boundary', 'retuning_boundary']:
    base = json.loads((a.fixtures / (name + '.json')).read_text())
    folder = a.output / name
    folder.mkdir()
    trials = []

    def evaluate(C):
        index = len(trials)
        inp = dict(base, C=C, action='solve')
        path = folder / f'input-{index:02}.json'
        write(path, inp)
        result = run(inp, folder / f'trial-{index:02}' / 'child', 'original', sha(path))
        raw = [check_lp(e) for e in traces(folder / f'trial-{index:02}' / 'child') if e['event'] == 'solve']
        assert len(raw) == 1 and raw[0]['accepted'] and raw[0]['dual_valid']
        margin = float(result['ratios'][base['target_vertex']] - result['decision']['threshold']) if name == 'pruning_boundary' else float(result['median'] - 1.1)
        trial = dict(C=C, margin=margin, median=float(result['median']), threshold=float(result['decision']['threshold']),
                     child=str(folder / f'trial-{index:02}' / 'child'), input=str(path), raw=raw)
        trials.append(trial)
        write(folder / 'progress.json', dict(trials=trials))
        print(name, index, C, margin, flush=True)
        return margin

    lo, hi = (.98 * base['C'], 1.02 * base['C']) if name == 'pruning_boundary' else (.5, 1.)
    flo, fhi = evaluate(lo), evaluate(hi)
    bracketed = flo * fhi <= 0
    if bracketed:
        for _ in range(24):
            mid = lo + .5 * (hi - lo)
            fm = evaluate(mid)
            if flo * fm <= 0:
                hi, fhi = mid, fm
            else:
                lo, flo = mid, fm
    for label, C in [('lower', lo), ('midpoint', lo + .5 * (hi - lo)), ('upper', hi)]:
        inp = dict(base, C=C, action='tune' if name == 'retuning_boundary' else 'solve', name=f'{name}_{label}')
        path = a.output / (inp['name'] + '.json')
        write(path, inp)
        cases.append(dict(name=inp['name'], input=str(path), sha256=sha(path), group=name, action=inp['action']))
    calibrations.append(dict(name=name, bracketed=bracketed, lower=lo, upper=hi,
                             lower_margin=flo, upper_margin=fhi, trials=trials))
write(a.output / 'manifest.json', dict(revision=subprocess.check_output(['git', 'rev-parse', 'HEAD'], text=True).strip(),
      original_only=True, cases=cases, calibrations=calibrations,
      fixtures_sha256=sha(a.fixtures / 'manifest.json'), total_calibration_solves=sum(len(x['trials']) for x in calibrations)))
print('Fixed probe inputs frozen; calibration solves:', sum(len(x['trials']) for x in calibrations))
