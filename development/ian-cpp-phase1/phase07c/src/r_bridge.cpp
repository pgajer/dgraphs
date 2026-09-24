// Local feasibility adapter; not an installed R package or a stable R API.
#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/Rdynload.h>
#include <ian/core.hpp>
#include <stdexcept>
#include <cstdio>

namespace {
struct Protect {
    int n=0;
    SEXP keep(SEXP value) { PROTECT(value); ++n; return value; }
    ~Protect() { UNPROTECT(n); }
};
ian::Matrix matrix(SEXP x) {
    if(TYPEOF(x)!=REALSXP || !Rf_isMatrix(x)) throw std::invalid_argument("expected_double_matrix");
    SEXP dim=Rf_getAttrib(x,R_DimSymbol);
    int n=INTEGER(dim)[0],p=INTEGER(dim)[1];
    ian::Matrix m(n,ian::Vector(p));
    for(int i=0;i<n;++i) for(int j=0;j<p;++j) m[i][j]=REAL(x)[i+n*j];
    return m;
}
std::vector<std::string> strings(SEXP x) {
    if(TYPEOF(x)!=STRSXP) throw std::invalid_argument("expected_character_vector");
    std::vector<std::string> out;
    for(R_xlen_t i=0;i<XLENGTH(x);++i) {
        if(STRING_ELT(x,i)==NA_STRING) throw std::invalid_argument("missing_identity");
        out.emplace_back(Rf_translateCharUTF8(STRING_ELT(x,i)));
    }
    return out;
}
SEXP vector(const ian::Vector& v,Protect& p) {
    SEXP x=p.keep(Rf_allocVector(REALSXP,v.size()));
    for(size_t i=0;i<v.size();++i) REAL(x)[i]=v[i]; return x;
}
SEXP indices(const ian::Indices& v,Protect& p,bool one_based=true) {
    SEXP x=p.keep(Rf_allocVector(INTSXP,v.size()));
    for(size_t i=0;i<v.size();++i) INTEGER(x)[i]=v[i]+(one_based?1:0); return x;
}
SEXP strings(const std::vector<std::string>& v,Protect& p) {
    SEXP x=p.keep(Rf_allocVector(STRSXP,v.size()));
    for(size_t i=0;i<v.size();++i) SET_STRING_ELT(x,i,Rf_mkCharCE(v[i].c_str(),CE_UTF8)); return x;
}
SEXP convert(const ian::Result& r) {
    Protect p;
    const std::vector<std::string> names={"schema_version","numerical_policy","complete","error_kind","error_code",
        "edges","edge_lengths","degrees","components","isolates","representatives","member_to_profile",
        "specimen_ids","profile_ids","participant_ids","scales","internal_scales","affinity","distance_multiplier",
        "multiplier","solves","graph_valid","scales_valid","affinity_valid"};
    SEXP out=p.keep(Rf_allocVector(VECSXP,names.size()));
    Rf_setAttrib(out,R_NamesSymbol,strings(names,p));
    int k=0;
    auto put=[&](SEXP x) { SET_VECTOR_ELT(out,k++,x); };
    put(p.keep(Rf_ScalarInteger(r.version))); put(p.keep(Rf_mkString(r.policy.c_str())));
    put(p.keep(Rf_ScalarLogical(r.complete))); put(p.keep(Rf_mkString(ian::error_kind_name(r.error.kind))));
    put(p.keep(Rf_mkString(r.error.code.c_str())));
    SEXP edges=p.keep(Rf_allocMatrix(INTSXP,r.graph.edges.size(),2));
    for(size_t i=0;i<r.graph.edges.size();++i) for(size_t j=0;j<2;++j)
        INTEGER(edges)[i+r.graph.edges.size()*j]=r.graph.edges[i][j]+1;
    put(edges); put(vector(r.graph.edge_lengths,p)); put(indices(r.graph.degrees,p,false));
    put(indices(r.graph.components,p)); put(indices(r.graph.isolates,p));
    put(indices(r.mapping.representatives,p)); put(indices(r.mapping.member_to_profile,p));
    put(strings(r.mapping.specimen_ids,p)); put(strings(r.mapping.profile_ids,p)); put(strings(r.mapping.participant_ids,p));
    put(vector(r.scales,p)); put(vector(r.internal_scales,p));
    SEXP affinity=p.keep(Rf_allocMatrix(REALSXP,r.affinity.size(),r.affinity.size()));
    for(size_t i=0;i<r.affinity.size();++i) for(size_t j=0;j<r.affinity.size();++j)
        REAL(affinity)[i+r.affinity.size()*j]=r.affinity[i][j];
    put(affinity); put(p.keep(Rf_ScalarReal(r.graph.distance_multiplier))); put(p.keep(Rf_ScalarReal(r.multiplier)));
    put(p.keep(Rf_ScalarInteger(r.solves))); put(p.keep(Rf_ScalarLogical(r.graph_valid)));
    put(p.keep(Rf_ScalarLogical(r.scales_valid))); put(p.keep(Rf_ScalarLogical(r.affinity_valid)));
    return out;
}
}
extern "C" SEXP ian_run(SEXP features,SEXP distances,SEXP ids,SEXP participants) {
    // C++ exceptions unwind before the R error longjmp. R allocation failure and
    // asynchronous interruption are not qualified in this feasibility adapter.
    char error[512] = {};
    SEXP value=R_NilValue;
    try {
        ian::Input input;
        input.features=matrix(features); input.distances=matrix(distances);
        input.specimen_ids=strings(ids); input.participant_ids=strings(participants);
        value=convert(ian::run(input));
    } catch(const std::exception& e) { std::snprintf(error,sizeof(error),"%s",e.what()); }
    if(error[0]) Rf_error("%s",error);
    return value;
}
extern "C" void R_init_ian_bridge(DllInfo* dll) {
    static const R_CallMethodDef methods[]={{"ian_run",reinterpret_cast<DL_FUNC>(&ian_run),4},{nullptr,nullptr,0}};
    R_registerRoutines(dll,nullptr,methods,nullptr,nullptr);
    R_useDynamicSymbols(dll,FALSE);
    R_forceSymbols(dll,TRUE);
}
