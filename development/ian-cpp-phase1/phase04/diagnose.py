"""Describe representation differences from retained traces; never changes a limit."""
import argparse
from pathlib import Path
import numpy as np
from support import load, write, traces, sha, revision
from compare import DISCRETE


def diagnose(left, right, comparison, output):
    a, b = traces(left), traces(right)
    comp = load(comparison / 'comparison.json')
    bad = [x for x in comp['checks'] if x['bad']]
    discrete_equal = len(a) == len(b) and all(
        all(x.get(k) == y.get(k) for k in DISCRETE) for x, y in zip(a, b))
    coefficients = ['A_data', 'A_indices', 'A_indptr', 'A_shape', 'b', 'c', 'upper', 'active', 'C']
    solve_pairs = [(x, y) for x, y in zip(a, b) if x['event'] == 'solve']
    coefficients_equal = all(all(x.get(k) == y.get(k) for k in coefficients) for x, y in solve_pairs)
    valid = all(x['accepted'] and x['dual_valid'] for x in comp['raw_checks_a'] + comp['raw_checks_b'])
    events = []
    for entry in bad:
        i = entry['index']
        x, y = a[i], b[i]
        fields = []
        for key in entry['bad']:
            if key not in entry['numeric']:
                fields.append(dict(field=key, non_array_difference=True))
                continue
            limits = entry['numeric'][key]
            vx, vy = np.asarray(x[key]), np.asarray(y[key])
            delta = abs(vx - vy)
            limit = limits['atol'] + limits['rtol'] * np.maximum(abs(vx), abs(vy))
            at = int(np.argmax(delta / limit))
            fields.append(dict(field=key, flat_index=at,
                original_value=float(vx.flat[at]), evaluated_value=float(vy.flat[at]),
                absolute_difference=float(delta.flat[at]), allowed_difference=float(limit.flat[at]),
                factor_above_limit=float((delta / limit).flat[at])))
        events.append(dict(index=i, event=x['event'], iteration=x['iteration'], fields=fields))
    first = events[0] if events else None
    details = {}
    if first:
        i = first['index']
        x, y = a[i], b[i]
        details['paired_event'] = dict(original=x, evaluated=y)
        iteration = x['iteration']
        details['retune_margins'] = [
            dict(index=j, original={k: a[j][k] for k in ['C', 'median', 'median_margin', 'lower_margin', 'upper_margin']},
                 evaluated={k: b[j][k] for k in ['C', 'median', 'median_margin', 'lower_margin', 'upper_margin']})
            for j in range(i, len(a)) if a[j]['iteration'] == iteration and a[j]['event'] == 'retune_eval']
        details['decision_margins'] = [
            dict(index=j, original_threshold=a[j]['threshold'], evaluated_threshold=b[j]['threshold'],
                 original_min_absolute_margin=float(np.min(abs(np.asarray(a[j]['threshold_margins'])))),
                 evaluated_min_absolute_margin=float(np.min(abs(np.asarray(b[j]['threshold_margins'])))),
                 candidates_equal=a[j]['candidates'] == b[j]['candidates'])
            for j in range(i, len(a)) if a[j]['iteration'] == iteration and a[j]['event'] == 'decision']
    attributable = bool(bad and discrete_equal and coefficients_equal and valid and
                         all(set(e['bad']) <= {'scales', 'ratios', 'stats', 'wstats', 'location',
                             'dispersion', 'threshold', 'raw_threshold', 'floored_threshold',
                             'median', 'median_residual', 'threshold_margins', 'median_margin',
                             'lower_margin', 'upper_margin', 'affinity'} for e in bad))
    result = dict(original_trace_sha256=sha(left / 'trace.jsonl'),
                  evaluated_trace_sha256=sha(right / 'trace.jsonl'),
                  comparison_passed=comp['passed'], events_outside_limits=events,
                  discrete_events_equal=discrete_equal, projected_LPs_identical=coefficients_equal,
                  all_raw_primal_dual_valid=valid,
                  final_affinity_exact=a[-1].get('affinity') == b[-1].get('affinity'),
                  representation_difference_with_unchanged_decisions=attributable,
                  explanation=('Controlled Python paths differ only in constraint representation. '
                    'Identical projected LPs receive numerically different solutions; the original '
                    'canonical conic problem can have an extra coordinate/cone. All raw checks pass '
                    'and all discrete decisions agree. The array comparison remains failed at the '
                    'original limits. Exact LP nonuniqueness is not established. '
                    'No native execution is needed to observe this representation effect.') if attributable else
                    'No automatic numerical representation classification; inspect retained evidence.',
                  first_difference_details=details, optimizations=0)
    assert not output.exists()
    write(output, result)
    return result


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    for name in ['left', 'right', 'comparison', 'output']:
        p.add_argument(name, type=Path)
    args = p.parse_args()
    revision()
    result = diagnose(args.left, args.right, args.comparison, args.output)
    print({k: result[k] for k in ['comparison_passed', 'discrete_events_equal',
           'projected_LPs_identical', 'representation_difference_with_unchanged_decisions']})
