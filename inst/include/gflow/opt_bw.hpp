#ifndef OPT_BW_H_
#define OPT_BW_H_

#include <vector>
#include "ulm.hpp"

struct opt_bw_t {
    std::vector<double> bws;       ///< candidate bandwidths
    std::vector<double> errors;    ///< prediction errors over candidate bandwidths
    double opt_bw;                 ///< optimal bandwidth
    std::vector<ext_ulm_t> models; ///< models corresponding to the optimal bw
};

#endif // OPT_BW_H_
