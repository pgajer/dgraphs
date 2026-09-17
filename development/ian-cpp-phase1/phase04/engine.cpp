// Standalone exact-path IAN prototype; phase03 baseline retained unchanged.
// See IAN-LICENSE.txt and NUMPY-LICENSE.txt.
#include "engine.hpp"
#include "stages.hpp"
#include <iostream>
int main(int argc, char **argv) {
    if (argc < 3 || argc > 4) {
        std::cerr << "ian_engine input.json new-output "
                     "[invalid_solver|after_graph|after_scales|after_affinity|pruning_cap]\n";
        return 2;
    }
    fs::path out = argv[2];
    if (!fs::create_directories(out)) {
        std::cerr << "output_exists\n";
        return 2;
    }
    std::unique_ptr<Engine> engine;
    try {
        std::ifstream file(argv[1]);
        Json in;
        file >> in;
        if (in.value("kind", "") == "stages") {
            atomic_json(out / "stages.json", stages(in));
            return 0;
        }
        engine = std::make_unique<Engine>(out, argc == 4 ? argv[3] : "none");
        engine->run(in, argv[1]);
        return 0;
    } catch (const std::exception &exc) {
        Json status = engine ? engine->status
                             : Json{{"graph", false},
                                    {"scales", false},
                                    {"affinity", false},
                                    {"complete", false}};
        status["error"] = exc.what();
        try {
            atomic_json(out / "status.json", status);
        } catch (...) {
            std::cerr << "status_write_failed\n";
        }
        std::cerr << exc.what() << '\n';
        return 1;
    }
}
