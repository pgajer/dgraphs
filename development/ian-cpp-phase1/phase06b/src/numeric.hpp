// IAN arithmetic/order port. IAN-LICENSE.txt and NUMPY-LICENSE.txt apply.
#pragma once
#include <json.hpp>
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <limits>
#include <numeric>
#include <stdexcept>
#include <vector>
namespace ian::detail {
using Json = nlohmann::json;
using Vec = std::vector<double>;
using Mat = std::vector<Vec>;
using Ids = std::vector<int>;
using Edges = std::vector<std::array<int, 2>>;
inline void require(bool b, const std::string &s) {
    if (!b)
        throw std::runtime_error(s);
}
inline double percentile(Vec v, double p) {
    require(!v.empty(), "empty_statistics");
    std::sort(v.begin(), v.end());
    double f = (v.size() - 1) * p;
    size_t i = std::floor(f);
    double g = f - i;
    if (i + 1 == v.size())
        return v[i];
    double d = v[i + 1] - v[i];
    return g >= .5 ? v[i + 1] - d * (1 - g) : v[i] + d * g;
}
inline double median(Vec v) {
    require(!v.empty(), "empty_statistics");
    std::sort(v.begin(), v.end());
    return v.size() % 2 ? v[v.size() / 2] : (v[v.size() / 2 - 1] + v[v.size() / 2]) / 2;
}
inline double norm_quantile(double p) {
    double lo = -10, hi = 10;
    for (int i = 0; i < 80; i++) {
        double x = (lo + hi) * .5;
        if (.5 * std::erfc(-x / std::sqrt(2.)) < p)
            lo = x;
        else
            hi = x;
    }
    return (lo + hi) * .5;
}
inline bool close(double x, double y) {
    return std::abs(x - y) <= 1e-8 + 1e-5 * std::abs(y);
}
// NumPy's float64 sum uses eight accumulators / recursive 128-element blocks.
inline double pair_sum(const double *a, size_t n) {
    if (n < 8) {
        double s = -0.;
        for (size_t i = 0; i < n; i++)
            s += a[i];
        return s;
    }
    if (n <= 128) {
        double r[8];
        for (int i = 0; i < 8; i++)
            r[i] = a[i];
        size_t i = 8;
        for (; i + 7 < n; i += 8)
            for (int j = 0; j < 8; j++)
                r[j] += a[i + j];
        double s = ((r[0] + r[1]) + (r[2] + r[3])) + ((r[4] + r[5]) + (r[6] + r[7]));
        for (; i < n; i++)
            s += a[i];
        return s;
    }
    size_t mid = (n / 2) - (n / 2) % 8;
    return pair_sum(a, mid) + pair_sum(a + mid, n - mid);
}
// Scalar indexed introsort order from NumPy 2.2.6 aquicksort_, Charles R. Harris.
// Same <=15 insertion partitions, median pivot and partition processing order.
inline Ids numpy_argsort(const Vec &v) {
    Ids a(v.size());
    std::iota(a.begin(), a.end(), 0);
    if (a.empty())
        return a;
    struct Part {
        int l, r, depth;
    };
    int depth = 2 * int(std::floor(std::log2(a.size())));
    std::vector<Part> stack;
    int l = 0, r = int(a.size()) - 1;
    for (;;) {
        if (depth < 0) { // indexed heapsort, one-based heap relative to l
            int n = r - l + 1;
            auto sift = [&](int start, int end) {
                int root = start;
                int value = a[l + root - 1];
                while (2 * root <= end) {
                    int child = 2 * root;
                    if (child < end && v[a[l + child - 1]] < v[a[l + child]])
                        child++;
                    if (v[value] < v[a[l + child - 1]]) {
                        a[l + root - 1] = a[l + child - 1];
                        root = child;
                    } else
                        break;
                }
                a[l + root - 1] = value;
            };
            for (int i = n / 2; i > 0; i--)
                sift(i, n);
            for (int i = n; i > 1; i--) {
                std::swap(a[l], a[l + i - 1]);
                sift(1, i - 1);
            }
        } else {
            while (r - l > 15) {
                int m = l + ((r - l) >> 1);
                if (v[a[m]] < v[a[l]])
                    std::swap(a[m], a[l]);
                if (v[a[r]] < v[a[m]])
                    std::swap(a[r], a[m]);
                if (v[a[m]] < v[a[l]])
                    std::swap(a[m], a[l]);
                double pivot = v[a[m]];
                int i = l, j = r - 1;
                std::swap(a[m], a[j]);
                for (;;) {
                    do {
                        i++;
                    } while (v[a[i]] < pivot);
                    do {
                        j--;
                    } while (pivot < v[a[j]]);
                    if (i >= j)
                        break;
                    std::swap(a[i], a[j]);
                }
                std::swap(a[i], a[r - 1]);
                --depth;
                if (i - l < r - i) {
                    stack.push_back({i + 1, r, depth});
                    r = i - 1;
                } else {
                    stack.push_back({l, i - 1, depth});
                    l = i + 1;
                }
            }
            for (int i = l + 1; i <= r; i++) {
                int value = a[i], j = i;
                while (j > l && v[value] < v[a[j - 1]]) {
                    a[j] = a[j - 1];
                    --j;
                }
                a[j] = value;
            }
        }
        if (stack.empty())
            break;
        auto p = stack.back();
        stack.pop_back();
        l = p.l;
        r = p.r;
        depth = p.depth;
    }
    return a;
}
inline Edges gabriel(const Mat &D2) {
    int n = D2.size();
    std::vector<std::vector<float>> d(n, std::vector<float>(n));
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++)
            d[i][j] = float(D2[i][j]);
    Edges e;
    double eps = 10 * double(std::numeric_limits<float>::epsilon());
    for (int i = 0; i < n; i++)
        for (int j = i + 1; j < n; j++) {
            bool keep = true;
            double bound = double(d[i][j]) + eps;
            for (int k = 0; k < n; k++)
                if (k != i && k != j) {
                    float sum = d[i][k] + d[j][k];
                    if (double(sum) <= bound) {
                        keep = false;
                        break;
                    }
                }
            if (keep)
                e.push_back({i, j});
        }
    return e;
}
inline Ids degrees(int n, const Edges &e) {
    Ids d(n, 0);
    for (auto a : e) {
        d[a[0]]++;
        d[a[1]]++;
    }
    return d;
}
inline Vec upper_bounds(const Mat &D, const Edges &e) {
    Vec u(D.size(), 0);
    for (auto a : e) {
        u[a[0]] = std::max(u[a[0]], D[a[0]][a[1]]);
        u[a[1]] = std::max(u[a[1]], D[a[0]][a[1]]);
    }
    return u;
}
inline std::vector<Ids> neighbors(const Mat &D, const Edges &e) {
    std::vector<Ids> a(D.size());
    for (auto p : e) {
        a[p[0]].push_back(p[1]);
        a[p[1]].push_back(p[0]);
    }
    for (size_t i = 0; i < a.size(); i++)
        std::sort(a[i].begin(), a[i].end(),
                  [&](int j, int k) { return D[i][j] != D[i][k] ? D[i][j] > D[i][k] : j > k; });
    return a;
}
inline Ids components(int n, const Edges &e) {
    std::vector<Ids> a(n);
    for (auto p : e) {
        a[p[0]].push_back(p[1]);
        a[p[1]].push_back(p[0]);
    }
    Ids labels(n, -1);
    int count = 0;
    for (int i = 0; i < n; i++)
        if (labels[i] < 0) {
            Ids q{i};
            labels[i] = count;
            for (size_t k = 0; k < q.size(); k++)
                for (int j : a[q[k]])
                    if (labels[j] < 0) {
                        labels[j] = count;
                        q.push_back(j);
                    }
            count++;
        }
    return labels;
}
inline Ids isolates(const Ids &d) {
    Ids x;
    for (size_t i = 0; i < d.size(); i++)
        if (!d[i])
            x.push_back(i);
    return x;
}
inline Mat affinity(const Mat &D2, const Vec &scales, const Ids &deg) {
    int n = D2.size();
    Vec inv(n);
    for (int i = 0; i < n; i++)
        inv[i] = deg[i] ? 1 / scales[i] : 1.;
    Mat K(n, Vec(n));
    double cutoff = -std::log(2 * std::numeric_limits<double>::epsilon());
    for (int i = 0; i < n; i++)
        for (int j = 0; j < n; j++) {
            double power = (inv[j] * D2[i][j]) * inv[i];
            double v = power < cutoff ? std::exp(-power) : 0.;
            K[i][j] = (deg[i] && deg[j] && v >= 1e-8) ? v : 0.;
        }
    for (int i = 0; i < n; i++)
        for (int j = i + 1; j < n; j++)
            K[i][j] = K[j][i] = std::max(K[i][j], K[j][i]);
    return K;
}
inline Vec volumes(const Mat &D2, const Vec &s, const Ids &d, const Mat *K = nullptr) {
    int n = s.size();
    Vec v(n, 0);
    double cutoff = -std::log(2 * std::numeric_limits<double>::epsilon());
    double factor = std::sqrt(std::acos(-1.)) / 2;
    for (int i = 0; i < n; i++)
        if (d[i]) {
            Vec values(n);
            if (K)
                values = (*K)[i];
            else
                for (int j = 0; j < n; j++) {
                    double power = D2[i][j] / (s[i] * s[i]);
                    values[j] = power <= cutoff ? std::exp(-power) : 0.;
                }
            double sum = pair_sum(values.data(), n);
            double degree = std::max(2, d[i]);
            double ratio = sum / degree;
            v[i] = ratio / std::pow(factor, std::log2(degree));
        }
    return v;
}
inline Json decision(const Vec &stats, double mu) {
    Vec positive;
    for (double s : stats)
        if (s > 0)
            positive.push_back(s);
    double q1 = percentile(positive, .25), m = percentile(positive, .5),
           q3 = percentile(positive, .75);
    double location = .333 * ((q1 + m) + q3);
    double n = positive.size();
    double sd = (q3 - q1) / (2 * norm_quantile((.75 * n - .125) / (n + .25)));
    double raw = location + 4.5 * sd;
    double floor = std::max(2.75, raw), threshold = floor, cap = 5 - (mu - 1);
    bool below =
        std::all_of(positive.begin(), positive.end(), [&](double x) { return x <= threshold; });
    if (below && cap < threshold)
        threshold = cap;
    Ids candidates;
    for (size_t i = 0; i < stats.size(); i++)
        if (stats[i] > threshold)
            candidates.push_back(i);
    std::stable_sort(candidates.begin(), candidates.end(),
                     [&](int i, int j) { return stats[i] > stats[j]; });
    if (mu - 1 > .1) {
        int nbelow =
            std::count_if(positive.begin(), positive.end(), [](double x) { return x < 1.1; });
        int needed = int(positive.size()) - 2 * nbelow;
        if (needed > int(candidates.size())) {
            auto order = numpy_argsort(stats);
            candidates.assign(order.rbegin(), order.rbegin() + needed);
        }
    }
    Vec margins = stats;
    for (double &v : margins)
        v -= threshold;
    return Json{{"event", "decision"},
                {"location", location},
                {"dispersion", sd},
                {"threshold", threshold},
                {"raw_threshold", raw},
                {"floored_threshold", floor},
                {"cap", cap},
                {"stats", stats},
                {"candidates", candidates},
                {"threshold_margins", margins},
                {"median_residual", mu - 1}};
}
inline Edges prune(Edges &edges, const Mat &D, const Ids &candidates) {
    auto nbrs = neighbors(D, edges);
    Ids seen(D.size());
    Edges removed;
    for (int i : candidates) {
        if (seen[i])
            continue;
        require(!nbrs[i].empty(), "candidate_isolate");
        int j = nbrs[i][0];
        if (seen[j])
            continue;
        std::array<int, 2> e = {std::min(i, j), std::max(i, j)};
        auto it = std::find(edges.begin(), edges.end(), e);
        require(it != edges.end(), "missing_edge");
        edges.erase(it);
        removed.push_back(e);
        seen[i] = seen[j] = 1;
    }
    return removed;
}

} // namespace ian::detail
