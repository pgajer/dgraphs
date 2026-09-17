"""Diagnostic fixed-state entry points into the unchanged executed Python reference."""
import argparse
import ast
import collections
import json
import sys
import textwrap
import traceback
from pathlib import Path

import cvxpy as cp
import numpy as np

OLD = Path(__file__).resolve().parents[1] / 'phase03'
sys.path.insert(0, str(OLD))
from reference import make_reference, sha, write, FROZEN, components


def routines(module):
    source = (FROZEN / 'build/source-evidence/ian/ian/ian.py').read_text()
    start = source.index('        to_be_pruned = np.flatnonzero( stats > thresh )')
    end = source.index('        if len(to_be_pruned) == 0:\n', start)
    block = textwrap.dedent(source[start:end])
    tree = ast.parse(source)
    ian = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'IAN')
    prune = next(n for n in ian.body if isinstance(n, ast.FunctionDef) and n.name == 'prune_edges')
    tuning = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'getSigmasTuneC')
    predicate = next(n for n in tuning.body if isinstance(n, ast.FunctionDef) and n.name == 'convergedC')

    def decision(stats, mu):
        stats = np.asarray(stats)
        loc, sd, threshold, _ = module.computeThreshold(stats[stats > 0], 4.5, 5 - (mu - 1),
                                                       plot=False, stdev_method='C3')
        scope = dict(np=np, stats=stats, thresh=threshold, extraVerbose=False,
                     diffmu=mu - 1, mu=mu, median_tol=.1, nonz_stats=stats[stats > 0])
        exec(block, scope)
        return dict(event='decision', location=loc, dispersion=sd, threshold=threshold,
                    raw_threshold=loc + 4.5 * sd, floored_threshold=max(2.75, loc + 4.5 * sd),
                    cap=5 - (mu - 1), stats=stats, candidates=np.asarray(scope['to_be_pruned'], dtype=int),
                    threshold_margins=stats - threshold, median_residual=mu - 1)

    def remove(D, edges, candidates):
        n = len(D)
        weighted = {tuple(e): D[tuple(e)] for e in edges}
        nbr = [[] for _ in range(n)]
        for i, j in edges:
            nbr[i].append(j)
            nbr[j].append(i)
        ordered = {i: collections.deque(sorted(nbr[i], key=lambda j: (D[i, j], j), reverse=True)) for i in range(n)}
        degree = np.array([len(x) for x in nbr])
        upper = np.array([max((D[i, j] for j in nbr[i]), default=0.) for i in range(n)])
        scope = dict(np=np, D1=D, extraVerbose=False, debugStatsPts=[], obj='l1')
        exec(compile(ast.Module(body=[prune], type_ignores=[]), 'pinned_prune', 'exec'), scope)
        result = scope['prune_edges'](candidates, weighted, ordered, degree, upper,
                                      None, None, [1] * len(candidates), None)
        return result[0], sorted(result[2]), degree, upper

    def converged(C, mu):
        scope = dict(np=np, curr_C=C, minC=min(C, .5), maxC=max(C, 1), diffmu=mu - 1, median_tol=.1)
        exec(compile(ast.Module(body=[predicate], type_ignores=[]), 'pinned_retune_predicate', 'exec'), scope)
        return bool(scope['convergedC']())
    return decision, remove, converged


def run(inp, output, condition, input_hash):
    output.mkdir(parents=True, exist_ok=False)
    module, audit, state = make_reference(output, condition, dict(input_sha256=input_hash,
        source_sha256=sha(__file__), configuration_sha256=sha(OLD / 'config.json')))
    decide, remove, converged = routines(module)
    try:
        if 'cases' in inp:
            results = []
            for case in inp['cases']:
                d = decide(case['stats'], case['median'])
                candidates = d['candidates']
                selected = candidates[:max(1, int(.1 * len(candidates)))]
                removed, edges, degree, upper = remove(np.asarray(case['D1'], dtype=float), case['edges'], selected)
                results.append(dict(name=case['name'], decision=d, selected=selected, removed=removed, edges=edges))
            write(output / 'stages.json', results)
            return dict(complete=True, solves=0)
        state.phase = 'fixed'
        state.scl = inp['scl']
        state.edges = [tuple(e) for e in inp['edges']]
        state.degrees = np.asarray(inp['degrees'])
        state.upper = np.asarray(inp['upper'])
        state.C = inp['C']
        state.emit(dict(event='mapping', **inp['mapping']))
        D, D2 = np.asarray(inp['D1']), np.asarray(inp['D2'])
        state.emit(dict(event='processed', D1=D, D2=D2, scl=state.scl, initial_edges=state.edges))
        state.emit(dict(event='iteration', scl=state.scl, **state.graph_data()))
        weighted = {e: D[e] for e in state.edges}
        if inp['action'] == 'tune':
            C, scales, stats, mu, _, _ = module.getSigmasTuneC(True, state.C, None,
                weighted, state.upper, 'l1', None,
                dict(degrees=state.degrees, D2=D2, sig2scl=1., disc_pts=np.flatnonzero(state.degrees == 0)),
                'median', use_wG=False, median_tol=.1, solver='CLARABEL', verbose=False, optverbose=False)
        else:
            x, objective, constraints, Cpar, Ct = module.buildOptimizationProblem(weighted, state.upper)
            Cpar.value = state.C
            Ct.value = 1 / Cpar.value
            audit.solve(cp.Problem(cp.Minimize(objective), constraints), x, 'parameterized')
            scales = x.value
            stats = module.getVolumeRatios(state.degrees, D2, scales, sig2scl=1.)
            mu = module.getMuStdev(stats[stats > 0], 'median')
            C = state.C
            state.emit(dict(event='predicate', C=C, median=mu,
                median_margin=abs(mu - 1) - .1, converged=converged(C, mu)))
        dec = decide(stats, mu)
        state.emit(dec)
        candidates = dec['candidates']
        selected = candidates[:max(1, int(.1 * len(candidates)))]
        removed, edges, degree, upper = remove(D, state.edges, selected)
        state.edges, state.degrees, state.upper = edges, degree, upper
        state.emit(dict(event='pruned', selected=selected, removed=removed, **state.graph_data()))
        result = dict(C=C, scales=scales, ratios=stats, median=mu, decision=dec,
                      selected=selected, removed=removed, **state.graph_data(), solves=state.solves)
        write(output / 'result.json', result)
        write(output / 'status.json', dict(complete=True, solves=state.solves, diagnostic_only=True))
        return result
    except Exception as exc:
        traceback.print_exc()
        write(output / 'status.json', dict(complete=False, solves=state.solves, error=repr(exc), diagnostic_only=True))
        raise
    finally:
        state.stream.close()


if __name__ == '__main__':
    p = argparse.ArgumentParser()
    p.add_argument('input', type=Path)
    p.add_argument('output', type=Path)
    p.add_argument('condition', choices=['original', 'evaluated'])
    a = p.parse_args()
    run(json.loads(a.input.read_text()), a.output, a.condition, sha(a.input))
