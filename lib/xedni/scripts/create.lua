local args = xedni.unpack(ARGV[1]);
local record_id   = args.record
local collections = args.collections
local weights      = args.weights

xedni.records.add(record_id, collections, weights)

return xedni.pack(record_id);
