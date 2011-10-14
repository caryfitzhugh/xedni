local args = xedni.unpack(ARGV[1]);
print('reading', table.show(args));
local record_data = xedni.records.read(args.record);
print('reading', table.show(record_data));
return xedni.pack(record_data);
