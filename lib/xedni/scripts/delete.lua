local args = xedni.unpack(ARGV[1]);
local record_data = xedni.records.delete(args.record);
return xedni.pack(record_data);
