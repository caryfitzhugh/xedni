local args = xedni.unpack(ARGV[1]);
local record_data = xedni.records.read(args.record);
print('reading', table.show(record_data));
return xedni.pack(record_data);
