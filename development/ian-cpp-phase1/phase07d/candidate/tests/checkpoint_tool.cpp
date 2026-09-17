// Private corruption-test helper: recompute a payload hash after a declared mutation.
#include "state_json.hpp"
#include <fstream>
int main(int argc,char** argv) {
    if(argc!=3) return 2;
    std::ifstream f(argv[1]); ian::io::Json j; f>>j;
    j["payload_sha256"]=ian::digest(j.at("payload").dump());
    std::ofstream out(argv[2]); out<<j.dump()<<'\n'; return out?0:1;
}
