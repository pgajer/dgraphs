#include "r_dimensions.hpp"
#include <iostream>
#include <stdexcept>
using namespace ian_r;
int main() {
 int checks=0;auto pass=[&](bool x){if(!x)throw std::runtime_error("control_failed");++checks;};
 auto refusal=[&](auto f){bool rejected=false;try{f();}catch(const std::runtime_error&){rejected=true;}pass(rejected);};
 constexpr std::size_t rmax=std::size_t(1)<<52;constexpr auto imax=std::numeric_limits<int>::max();
 for(std::size_t n:{500,501,1000,5000,10000}){input_dimensions(n,5,rmax);++checks;}
 input_dimensions(std::size_t(1)<<26,1,rmax);++checks;
 refusal([&]{input_dimensions((std::size_t(1)<<26)+1,1,rmax);});
 refusal([&]{input_dimensions(std::size_t(imax)/2+1,1,rmax);});
 refusal([&]{input_dimensions(2,std::size_t(imax)+1,rmax);});
 refusal([&]{matrix_dimensions(std::numeric_limits<std::size_t>::max(),2,rmax);});
 refusal([&]{matrix_dimensions(2,std::numeric_limits<std::size_t>::max(),rmax);});
 matrix_dimensions(0,0,rmax);++checks;
 pass(!integer_as_double(imax));pass(integer_as_double(std::numeric_limits<int>::min()));pass(!integer_as_double(std::numeric_limits<int>::min()+1));
 pass(integer_as_double(std::uint64_t(imax)+1));pass(integer_as_double(std::int64_t(std::numeric_limits<int>::min())-1));
 pass(integer_as_double(std::uint64_t(1)<<53));pass(integer_as_double(-(std::int64_t(1)<<53)));
 refusal([&]{integer_as_double((std::uint64_t(1)<<53)+1);});
 refusal([&]{integer_as_double(-(std::int64_t(1)<<53)-1);});
 refusal([&]{integer_as_double(std::numeric_limits<std::uint64_t>::max());});
 refusal([&]{integer_as_double(std::numeric_limits<std::int64_t>::min());});
 std::cout<<"{\"passed\":true,\"dimension_and_narrowing_checks\":"<<checks<<",\"engine_calls\":0}\n";
}
