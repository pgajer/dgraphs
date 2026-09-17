"""Focused F1 CLI tests; preserve the original Phase06A evidence unchanged."""
import argparse
import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent / 'phase04'))
from support import revision, load, write, sha, supervise, one_thread_environment, traces, check_lp

p = argparse.ArgumentParser()
p.add_argument('worker', type=Path)
p.add_argument('output', type=Path)
p.add_argument('--engine', type=Path, required=True)
a = p.parse_args()
rev = revision()
a.output.mkdir(parents=True, exist_ok=False)
fixture = a.worker / 'phase03/fixtures-v1/nonuniform_curve.json'
reference = a.worker / 'phase06a/regressions-v1/full/nonuniform_curve/child'
original = load(fixture)
original.pop('schema_version', None)
record = dict(revision=rev, engine=str(a.engine), engine_sha256=sha(a.engine),
              fixture=str(fixture), fixture_sha256=sha(fixture), reference=str(reference),
              complete=False, total_solver_calls=0, cases=[])

def save():
    write(a.output / 'checks.json', record)

def without_timing(events):
    return [{k: v for k, v in event.items() if k != 'seconds'} for event in events]

# Literals preserve the exact JSON type and exercise signed/unsigned parser ranges.
cases = [('omitted', None, True), ('integer_one', '1', True),
         ('fraction', '1.5', False), ('narrowing_integer', '4294967297', False),
         ('unsupported_two', '2', False), ('integral_float', '1.0', False),
         ('integral_exponent', '1e0', False), ('negative', '-1', False),
         ('zero', '0', False), ('signed_max', '9223372036854775807', False),
         ('unsigned_max', '18446744073709551615', False),
         ('beyond_unsigned', '18446744073709551616', False),
         ('string', '"1"', False), ('true', 'true', False), ('false', 'false', False),
         ('null', 'null', False), ('array', '[1]', False), ('object', '{"version":1}', False)]

for name, literal, accepted in cases:
    folder = a.output / name
    folder.mkdir()
    path = folder / 'input.json'
    text = json.dumps(original, allow_nan=False)
    if literal is not None:
        text = text[:-1] + ', "schema_version": ' + literal + '}'
    path.write_text(text + '\n')
    supplied = load(path)
    supplied.pop('schema_version', None)
    assert supplied == original
    proc = supervise([str(a.engine), str(path), str(folder / 'child')],
                     folder / 'process', one_thread_environment())
    child = folder / 'child'
    status = load(child / 'status.json')
    events = traces(child) if (child / 'trace.jsonl').exists() else []
    raw = [check_lp(e) for e in events if e['event'] == 'solve']
    item = dict(name=name, literal=literal, expected_accepted=accepted,
                input_sha256=sha(path), process=proc, status=status, solves=len(raw))
    record['cases'].append(item)
    record['total_solver_calls'] += len(raw)
    save()
    if accepted:
        assert proc['exit_code'] == 0 and status['complete'] and status['solves'] == 2
        assert len(raw) == 2 and all(c['accepted'] and c['dual_valid'] for c in raw)
        item['raw_checks'] = raw
        item['exact_trace_except_seconds'] = without_timing(events) == without_timing(traces(reference))
        item['exact_result'] = load(child / 'result.json') == load(reference / 'result.json')
        assert item['exact_trace_except_seconds'] and item['exact_result']
        item['stages_equal_except_provenance'] = {}
        for stage in ['graph', 'scales', 'affinity']:
            current, old = load(child / (stage + '.json')), load(reference / (stage + '.json'))
            for payload in [current, old]:
                payload.pop('input_sha256')
                payload.pop('source_sha256')
            item['stages_equal_except_provenance'][stage] = current == old
            assert current == old
            assert status[stage + '_sha256'] == sha(child / (stage + '.json'))
    else:
        assert proc['exit_code'] == 1 and status['error'] == 'unsupported_schema'
        assert status['error_kind'] == 'adapter'
        assert not any(status[k] for k in ['complete', 'graph', 'scales', 'affinity'])
        assert not events and not raw
        # The parser returns before the Files observer or core exists.
        assert sorted(f.name for f in child.iterdir()) == ['status.json']
        item['rejected_before_core'] = True
    item['passed'] = True
    save()
    print(name, 'passed', flush=True)

assert record['total_solver_calls'] == 4
record['complete'] = True
save()
print('18 CLI schema cases passed; four valid solves, zero solves for refusals.', flush=True)
