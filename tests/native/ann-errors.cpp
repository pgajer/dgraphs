// Standalone regression test: compile with src/ANN/*.cpp and -Iinst/include.
#include <ANN/ANNx.h>
#include <ANN/pr_queue.h>
#include <dgraphs/ann_raii.hpp>
#include <cassert>
#include <stdexcept>
#include <string>

template <typename F> void expect_error(F f, const char* text) {
    bool caught = false;
    try { f(); }
    catch (const std::runtime_error& e) {
        caught = std::string(e.what()).find(text) != std::string::npos;
    }
    assert(caught);
}

int main() {
    expect_error([] { annError("fatal-test", ANNabort); }, "fatal-test");
    expect_error([] { annError("warning-test", ANNwarn); }, "warning-test");
    expect_error([] { annAllocPts(0, 2); }, "positive");
    expect_error([] {
        ANNpr_queue queue(1);
        queue.insert(1.0, nullptr);
        queue.insert(2.0, nullptr);
    }, "overflow");
    for (int iteration = 0; iteration < 50; ++iteration) {
        ann_dataset_t dataset(2, 1);
        dataset.points[0][0] = 0;
        dataset.points[1][0] = 1;
        dataset.tree = new ANNkd_tree(dataset.points, 2, 1);
        ANNidx indices[3];
        ANNdist distances[3];
        expect_error([&] {
            dataset.tree->annkSearch(dataset.points[0], 3, indices, distances);
        }, "more near neighbors");
        dataset.tree->annkSearch(dataset.points[0], 1, indices, distances);
        assert(indices[0] == 0 && distances[0] == 0);
    }
}
