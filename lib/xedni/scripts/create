-- Input:
--  ARGV[1] = record's ID string
--  ARGV[2] = collections
--  ARGV[3] = scores
local record_id = ARGV[1]
local collections = xedni_f.unpack(ARGV[2])
local scores      = xedni_f.unpack(ARGV[3])

-- Here we want to save all the data into the records table.

-- Here we add to the redis_map_key
xedni_f.add_record(record_id, collections, scores)
-- xedni_f.remove_record(record_id)
return
