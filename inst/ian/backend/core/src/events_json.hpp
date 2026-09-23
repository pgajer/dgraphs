#pragma once
#include "event_fields.hpp"
#include <json.hpp>
#include <type_traits>
namespace ian::io {
using Json = nlohmann::json;
template<class T> Json object_json(const T& value);
template<class T> Json object_json(const std::vector<T>& value);
template<class T,std::size_t N> Json object_json(const std::array<T,N>& value);
struct JsonFields {
    Json value = Json::object();
    template<class T> void field(const char* name,const T& x) {
        if constexpr(std::is_arithmetic_v<T> || std::is_same_v<T,std::string>) value[name]=x;
        else value[name]=object_json(x);
    }
};
template<class T> Json object_json(const T& value) { JsonFields out; serialization::fields(out,value); return out.value; }
template<class T> Json object_json(const std::vector<T>& value) { if constexpr(std::is_same_v<T,ProtectedBridge> || std::is_same_v<T,PruningStep>) {
 Json out=Json::array();for(const auto& x:value)out.push_back(object_json(x));return out;
 } else return Json(value); }
template<class T,std::size_t N> Json object_json(const std::array<T,N>& value) { return Json(value); }
template<class T> Json payload_json(const T& value) { auto out=object_json(value); out["event"]=event_name(value); return out; }
inline Json event_json(const Event& event) { return object_json(event); }
}
