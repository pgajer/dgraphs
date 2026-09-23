#pragma once
#include <json.hpp>
#include <stdexcept>
#include <CommonCrypto/CommonDigest.h>
#include <filesystem>
#include <fstream>
#include <iomanip>
#include <sstream>
#include <fcntl.h>
#include <unistd.h>
namespace fs = std::filesystem;
namespace ian::io {
using Json = nlohmann::json;
inline void require(bool condition, const std::string &message) {
    if (!condition) throw std::runtime_error(message);
}
// File hashes and durable same-directory JSON commits.
std::string file_hash(const fs::path &p) {
    std::ifstream f(p, std::ios::binary);
    require(bool(f), "hash_read");
    CC_SHA256_CTX ctx;
    CC_SHA256_Init(&ctx);
    char buf[65536];
    while (f) {
        f.read(buf, sizeof(buf));
        if (f.gcount())
            CC_SHA256_Update(&ctx, buf, CC_LONG(f.gcount()));
    }
    unsigned char result[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(result, &ctx);
    std::ostringstream s;
    for (auto c : result)
        s << std::hex << std::setw(2) << std::setfill('0') << int(c);
    return s.str();
}
void atomic_json(const fs::path &p, const Json &value) {
    std::string text = value.dump() + "\n";
    fs::path tmp = p;
    tmp += ".tmp";
    int fd = ::open(tmp.c_str(), O_WRONLY | O_CREAT | O_EXCL, 0600);
    require(fd >= 0, "checkpoint_open");
    size_t at = 0;
    while (at < text.size()) {
        ssize_t n = ::write(fd, text.data() + at, text.size() - at);
        if (n <= 0) {
            ::close(fd);
            throw std::runtime_error("checkpoint_write");
        }
        at += n;
    }
    int flushed = ::fsync(fd);
    int closed = ::close(fd);
    require(flushed == 0 && closed == 0, "checkpoint_flush");
    fs::rename(tmp, p);
    int dir = ::open(p.parent_path().c_str(), O_RDONLY);
    require(dir >= 0, "checkpoint_directory");
    int sync = ::fsync(dir);
    ::close(dir);
    require(sync == 0, "checkpoint_directory_flush");
}

} // namespace ian::io
