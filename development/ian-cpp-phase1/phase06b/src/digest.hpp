#pragma once
#include <algorithm>
#include <CommonCrypto/CommonDigest.h>
#include <iomanip>
#include <sstream>
#include <string>
namespace ian {
inline std::string finish_digest(CC_SHA256_CTX context) {
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(bytes, &context);
    std::ostringstream out;
    for (auto c : bytes) out << std::hex << std::setw(2) << std::setfill('0') << int(c);
    return out.str();
}
inline std::string digest(const std::string& text) {
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    size_t at = 0;
    while (at < text.size()) {
        size_t count = std::min(size_t(65536), text.size() - at);
        CC_SHA256_Update(&context, text.data() + at, CC_LONG(count));
        at += count;
    }
    return finish_digest(context);
}
}
