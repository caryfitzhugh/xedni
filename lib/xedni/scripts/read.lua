local args = xedni.unpack(ARGV[1]);
local record_data = xedni.records.read(args.record);
return xedni.pack(record_data);
