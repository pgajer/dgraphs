"""Check that formatting/extraction preserves tokens except the declared metadata."""
import argparse
import re
from pathlib import Path
from support import HERE, OLD, sha, write, revision


def tokens(text):
    # Match quoted literals before comments; preserve all non-whitespace tokens.
    parts = re.findall(r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|//[^\n]*|/\*.*?\*/|\S',
                       text, re.DOTALL)
    return [p for p in parts if not p.startswith(('//', '/*'))]


parser = argparse.ArgumentParser()
parser.add_argument('output', type=Path)
args = parser.parse_args()
rev = revision()
assert not args.output.exists()
baseline = (OLD / 'engine.cpp').read_text()
checks = []
for file, start, end in [
        ('checkpoint.hpp', 'std::string file_hash', 'struct Input'),
        ('input.hpp', 'struct Input', 'struct Engine'),
        ('engine.hpp', 'struct Engine', 'Json stages'),
        ('stages.hpp', 'Json stages', 'int main'),
        ('engine.cpp', 'int main', None)]:
    old = baseline[baseline.index(start):baseline.index(end) if end else None]
    new = (HERE / file).read_text()
    new = new[new.index(start):]
    if file == 'engine.hpp':
        old = old.replace('checkpoint("graph",graph_data());',
              'Json graph = graph_data(); graph["scl"] = scl; '
              'graph["upper_units"] = "internal_distance = input_distance * scl"; '
              'graph["upper_to_input_distance"] = 1 / scl; checkpoint("graph", graph);')
    assert tokens(old) == tokens(new), file
    checks.append(dict(file=file, tokens_unchanged_except_declared_metadata=True))
for file in ['numeric.hpp', 'solver.hpp']:
    assert tokens((OLD / file).read_text()) == tokens((HERE / file).read_text()), file
    checks.append(dict(file=file, tokens_identical=True))
assert sha(OLD / 'config.json') == sha(HERE / 'config.json')
write(args.output, dict(revision=rev, checks=checks,
                       configuration_unchanged=True, optimizations=0))
print('All algorithm tokens preserved; only graph checkpoint metadata added.')
