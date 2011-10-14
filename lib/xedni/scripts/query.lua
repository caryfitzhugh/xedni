local args = xedni.unpack(ARGV[1]);
print('query input', table.show(args));
local results = xedni.search.query(args.query);
print('query results', table.show(results));
results = xedni.search.sort(results, args.weights);
print('sorted results', table.show(results));
results = xedni.search.paginate(results, args.options);
print('paginated results', table.show(results));
return xedni.pack(results);
