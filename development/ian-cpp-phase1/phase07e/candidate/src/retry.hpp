#pragma once
#include <cmath>
#include <utility>
namespace ian::detail {
template<class V> inline bool usable_return(const V &x,const V &z,const V &upper,
                                            double objective,size_t n,size_t m) {
    if(x.size()!=n || z.size()!=m || upper.size()!=n || !std::isfinite(objective)) return false;
    for(size_t i=0;i<n;++i) if(!std::isfinite(upper[i]) || !std::isfinite(x[i]) || (upper[i]>0 && x[i]<=0)) return false;
    for(double v:z) if(!std::isfinite(v)) return false;
    return true;
}
inline bool retry_eligible(bool usable, double objective_error, double primal,
                           double absolute, double stationarity, double negative, double gap,
                           bool almost=false) {
    return usable && std::isfinite(objective_error) && objective_error <= 1e-7 &&
        std::isfinite(primal) && std::isfinite(absolute) && std::isfinite(stationarity) &&
        std::isfinite(negative) && std::isfinite(gap) &&
        (almost || primal > 1e-7 || stationarity > 1e-7 || negative > 1e-7 || gap > 1e-7);
}
inline std::pair<bool,bool> classify_return(bool usable,bool solved,bool almost,
        double objective_error,double primal,double absolute,double stationarity,double negative,double gap) {
    bool finite=std::isfinite(objective_error)&&std::isfinite(primal)&&std::isfinite(absolute)&&
        std::isfinite(stationarity)&&std::isfinite(negative)&&std::isfinite(gap);
    bool accepted=usable&&solved&&finite&&objective_error<=1e-7&&primal<=1e-7&&
        stationarity<=1e-7&&negative<=1e-7&&gap<=1e-7;
    return {accepted,retry_eligible(usable&&(solved||almost),objective_error,primal,absolute,stationarity,negative,gap,almost)};
}
}
