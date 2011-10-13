local args = xedni.unpack(ARGV[1]);
local results = xedni.search.query(args.query);
local scored_results = xedni.search.sort(results.records_key, args.weights);
return xedni.pack({records=scored_results});

--[[

local paginated_results = xedni.search.paginate(scored_results, args.options);
return xedni.pack(paginated_result);
--]]
