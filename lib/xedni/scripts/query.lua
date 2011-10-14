local args = xedni.unpack(ARGV[1]);
local results = xedni.search.query(args.query);
results = xedni.search.sort(results, args.weights);
results = xedni.search.paginate(results, args.options);
return xedni.pack(results);
