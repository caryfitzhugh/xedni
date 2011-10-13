local args = xedni.unpack(ARGV[1]);
local record_id   = args.record
local collections = args.collections
local scores      = args.scores

xedni.records.add(record_id, collections, scores)

return xedni.pack(record_id);
