#ifndef DGRAPHS_ANN_RAII_HPP
#define DGRAPHS_ANN_RAII_HPP

#include <ANN/ANN.h>

// Own the point storage and its tree together so exceptional exits release both.
// ANN searches and annClose() must run serially because ANN has global state.
struct ann_dataset_t {
    ANNpointArray points;
    ANNkd_tree* tree = nullptr;

    ann_dataset_t(int n, int dim) : points(annAllocPts(n, dim)) {}
    ann_dataset_t(const ann_dataset_t&) = delete;
    ann_dataset_t& operator=(const ann_dataset_t&) = delete;
    ~ann_dataset_t() {
        delete tree;
        if (points) annDeallocPts(points);
        annClose();
    }
};

#endif
