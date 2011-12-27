local redis_call = redis.call;
local args = xedni.unpack(ARGV[1]);
redis_call("sunionstore", "union_records", "collections:attr_a:" .. args.a,
            "collections:attr_b:" .. args.b,
            "collections:attr_c:" .. args.c,
            "collections:attr_d:" .. args.d,
            "collections:attr_e:" .. args.e,
            "collections:attr_f:" .. args.f);

local record_ids = redis_call('smembers',"union_records");
redis_call('del','results_key');

local scores = {};
local random = math.random;
for index, rid in ipairs(record_ids) do
  --  1/2 of the time
  local record_id = "record:" .. rid;
  local values = redis_call('hmget', record_id, 'a','b','c','d','e','f');
  local score = random() * 100;
  -- 1/4 of the time
  redis_call('zadd', 'results_key', score, rid);
end
-- Alternative, is to push all of them onto the scores table,
-- Then split that into blocks of N records, and unpack -> zadd those.
-- unpack has an upper limit, (something < 50k) for unpacking things into a function call.
-- SO we'd have to split it into blocks of 10,000 or so.
-- Would splitting it into blocks, then adding, be faster than just adding with ZADD each time?
-- We have the table insertion, then splitting into blocks, then unpacking.
--
-- Alternative, just do a straight zadd.

local record_ids = redis_call("zcard", 'results_key');
return xedni.pack(record_ids);
