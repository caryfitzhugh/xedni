local args = xedni.unpack(ARGV[1]);
local results = xedni.search.query(args.query);
local scored_results = xedni.search.sort(results, args.weights);

-- Explode the results now - into real values
scored_results.records = assert(redis.call('smembers', scored_results.records_key))
return xedni.pack(results);

--[[

local paginated_results = xedni.search.paginate(scored_results, args.options);
return xedni.pack(paginated_result);
--]]
