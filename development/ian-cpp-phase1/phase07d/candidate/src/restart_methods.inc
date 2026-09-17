    void restore(const ian::RestartState& s) {
        require(s.version == 1 && s.policy == ian::numerical_policy &&
            s.source == ian::source_identity() && s.configuration == ian::configuration_identity() &&
            s.input_hash == input_hash, "incompatible_restart");
        const auto& m = result.mapping;
        require(s.mapping.representatives == m.representatives &&
            s.mapping.member_to_profile == m.member_to_profile &&
            s.mapping.specimen_ids == m.specimen_ids && s.mapping.profile_ids == m.profile_ids &&
            s.mapping.participant_ids == m.participant_ids, "invalid_restart");
        require((s.boundary == "pruning" || s.boundary == "graph") && s.cache &&
            s.iteration >= 0 && s.iteration < 2000 && s.solves >= s.iteration + 1 &&
            s.solves <= (s.iteration + 1) * 42 && s.distance_multiplier == scl &&
            std::isfinite(s.multiplier) && s.multiplier > 0 && s.multiplier <= 1 &&
            s.last_stats.size() == D.size(), "invalid_restart");
        for (double v : s.last_stats) require(std::isfinite(v) && v >= 0, "invalid_restart");
        require(std::is_sorted(s.edges.begin(), s.edges.end()) &&
            std::adjacent_find(s.edges.begin(), s.edges.end()) == s.edges.end(), "invalid_restart");
        for (auto e : s.edges) require(e[0] >= 0 && e[0] < e[1] && size_t(e[1]) < D.size() &&
            std::binary_search(edges.begin(), edges.end(), e), "invalid_restart");
        require(s.degrees == degrees(D.size(), s.edges) &&
            s.upper == upper_bounds(D, s.edges), "invalid_restart");
        Vec positive;
        for (double v : s.last_stats) if (v > 0) positive.push_back(v);
        require(!positive.empty(), "invalid_restart");
        bool stopped = decision(s.last_stats, median(positive))["candidates"].empty();
        require(stopped == (s.boundary == "graph"), "invalid_restart");
        edges = s.edges; deg = s.degrees; upper = s.upper; C = s.multiplier;
        cache = s.cache; solves = s.solves; iteration = s.iteration; last_stats = s.last_stats;
    }
    void boundary(const std::string& kind) {
        if (!observer) return;
        ian::RestartState s;
        s.source = ian::source_identity(); s.configuration = ian::configuration_identity();
        s.input_hash = input_hash; s.boundary = kind; s.mapping = result.mapping;
        s.edges = edges; s.degrees = deg; s.upper = upper; s.last_stats = last_stats;
        s.multiplier = C; s.distance_multiplier = scl; s.iteration = iteration;
        s.solves = solves; s.cache = cache;
        bool proceed;
        try { proceed = observer->on_checkpoint(s); }
        catch (const std::exception& e) { throw ObserverFailure(e.what()); }
        catch (...) { throw ObserverFailure("nonstandard_callback_exception"); }
        if (!proceed) throw Cancelled("cancelled_at_accepted_boundary");
    }
