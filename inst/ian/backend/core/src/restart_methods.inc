    void restore(const ian::RestartState& s) {
        require(s.version == 1 && s.policy == result.policy && s.preserve_connectivity == result.preserve_connectivity &&
            s.source == ian::source_identity() && s.configuration == ian::configuration_identity() &&
            s.input_hash == input_hash, "incompatible_restart");
        const auto& m = result.mapping;
        require(s.mapping.representatives == m.representatives &&
            s.mapping.member_to_profile == m.member_to_profile &&
            s.mapping.specimen_ids == m.specimen_ids && s.mapping.profile_ids == m.profile_ids &&
            s.mapping.participant_ids == m.participant_ids, "invalid_restart");
        require((s.boundary == "pruning" || s.boundary == "graph") && s.cache &&
            s.iteration >= 0 && s.iteration < 2000 && s.solves >= s.iteration + 1 &&
            s.solves <= (s.iteration + 1) * (result.policy == ian::retry_power_policy ? 42 : 21) && s.distance_multiplier == scl &&
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
        bool stopped = decision(s.last_stats, median(positive)).candidates.empty();
        if(result.preserve_connectivity) {
            auto labels=components(D.size(),s.edges);require(*std::max_element(labels.begin(),labels.end())==0,"invalid_restart");
            std::set<std::array<int,2>> seen;
            int total_encounters=0,total_skips=0;
            for(const auto& b:s.pruning.protected_bridges) {
                require(std::binary_search(s.edges.begin(),s.edges.end(),b.edge) && seen.insert(b.edge).second &&
                    (b.trigger==b.edge[0] || b.trigger==b.edge[1]) && b.first_iteration>=0 &&
                    b.first_iteration<=b.last_iteration && b.last_iteration<=s.iteration && b.encounters>0 &&
                    std::isfinite(b.statistic) && std::isfinite(b.threshold) && std::isfinite(b.margin) &&
                    b.margin==b.statistic-b.threshold && bridge(D.size(),s.edges,b.edge),"invalid_restart");
                total_encounters+=b.encounters;
            }
            require(s.pruning.history.size()==size_t(s.iteration+1),"invalid_restart");
            for(size_t k=0;k<s.pruning.history.size();++k) {
                const auto& h=s.pruning.history[k];
                require(h.iteration==int(k) && h.statistical_candidates>=0 && h.statistical_candidates<=int(D.size()) &&
                    h.allowance==std::max(1,int(.1*h.statistical_candidates)) && h.removed>=0 && h.removed<=h.allowance &&
                    h.examined>=0 && h.examined<=int(D.size()) && h.bridge_skips>=0 && h.bridge_checks>=0 && h.cached_skips>=0 &&
                    h.condition_rejections>=0 && h.endpoint_conflicts>=0 && h.bridge_skips>=h.cached_skips &&
                    h.examined==h.bridge_checks+h.cached_skips &&
                    h.examined==h.bridge_skips+h.condition_rejections+h.endpoint_conflicts+h.removed &&
                    (k+1==s.pruning.history.size() || h.removed>0),"invalid_restart");
                total_skips+=h.bridge_skips;
            }
            require(total_skips==total_encounters,"invalid_restart");
            if(s.boundary=="graph") {
                require(s.pruning.history.back().removed==0 && s.pruning.stop_reason==(stopped ? "no_pruning_candidates" : "no_connectivity_preserving_removal"),"invalid_restart");
                Edges trial=s.edges;auto diagnostic=s.pruning;Ids selected;
                require(prune_connected(trial,D,decision(s.last_stats,median(positive),false),s.iteration,diagnostic,selected).empty(),"invalid_restart");
            } else require(s.pruning.history.back().removed>0 && s.pruning.stop_reason.empty(),"invalid_restart");
            result.pruning=s.pruning;
        } else require(stopped == (s.boundary == "graph") && s.pruning.protected_bridges.empty() && s.pruning.history.empty() && s.pruning.stop_reason.empty(), "invalid_restart");
        edges = s.edges; deg = s.degrees; upper = s.upper; C = s.multiplier;
        cache = s.cache; solves = s.solves; iteration = s.iteration; last_stats = s.last_stats;
    }
    void boundary(const std::string& kind) {
        if (!observer) return;
        ian::RestartState s;
        s.policy = result.policy;
        s.preserve_connectivity=result.preserve_connectivity;s.pruning=result.pruning;
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
