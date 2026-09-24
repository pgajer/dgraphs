"""Preserve Phase06A arithmetic; explicit substitutions add accepted-boundary state."""
import argparse
from pathlib import Path
here = Path(__file__).resolve().parent
old = here.parent / 'phase06a'
p = argparse.ArgumentParser(); p.add_argument('--check', action='store_true'); a = p.parse_args()
def save(name, text):
    path = here / name
    if a.check: assert path.read_text() == text, name
    else: path.write_text(text)
for name in ['numeric.hpp', 'solver.hpp', 'input.hpp', 'stages.hpp', 'checkpoint.hpp']:
    save('src/' + name, (old / 'src' / name).read_text())
for name in ['config.json', 'IAN-LICENSE.txt', 'NUMPY-LICENSE.txt']:
    save(name, (old / name).read_text())
s = (old / 'src/engine.hpp').read_text()
def replace(left, right):
    global s
    assert s.count(left) == 1, left
    s = s.replace(left, right)
replace('#include "solver.hpp"', '#include "solver.hpp"\n#include "digest.hpp"')
replace('struct Engine {', 'struct Cancelled : std::runtime_error { using std::runtime_error::runtime_error; };\nstruct Engine {')
replace('    Mat input_distances;', '    Mat input_distances;\n    const ian::RestartState* restart;\n    Vec last_stats;\n    std::string input_hash;')
replace('std::string injection)\n        : result(value), observer(sink), inject(std::move(injection)) {}',
        'std::string injection, const ian::RestartState* saved = nullptr)\n        : result(value), observer(sink), restart(saved), inject(std::move(injection)) {}')
replace('    Json graph_data()', '    #include "restart_methods.inc"\n    Json graph_data()')
replace('        emit(map);', '        if (!restart) emit(map);')
replace('        emit(Json{\n            {"event", "processed"}', '        if (!restart) emit(Json{\n            {"event", "processed"}')
replace('        bool converged = false;\n        Vec last_stats;',
        '        if (restart) restore(*restart);\n        bool graph_restored = restart && restart->boundary == "graph";\n        bool converged = graph_restored;')
replace('for (iteration = 0; iteration < (inject == "pruning_cap" ? 1 : 2000); iteration++)',
        'for (iteration = restart ? restart->iteration + (graph_restored ? 0 : 1) : 0;\n             !graph_restored && iteration < (inject == "pruning_cap" ? 1 : 2000); iteration++)')
replace('            emit(event);\n        }', '            emit(event);\n            boundary("pruning");\n        }')
replace('        emit(stop);\n        require(converged', '        if (!graph_restored) emit(stop);\n        require(converged')
replace('        checkpoint("graph", graph);', '        checkpoint("graph", graph);\n        if (!graph_restored) boundary("graph");')
save('src/engine.hpp', s)
print('Phase06A numerical bodies preserved; declared restart substitutions match.')

cli = (old / "src/cli.cpp").read_text().split("int main(")[0]
save("src/files.hpp", "#pragma once\n" + cli.replace("struct Files final", "struct Files"))
