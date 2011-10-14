-- These are constants and naming things...
xedni = {
  uid = function()
    return "x:tmp:" .. assert(redis.call("incr", "x:uid"));
  end,
  search = {
    -- Otherwise you can request a facet with an [...] - which looks for OR matches.
    -- :records is a special collection key - which when used, will match only those records.
    --
    --  :taste => true,
    --  :maker => ['apple','pear','grape']
    --
    --  Algorithm:
    --
    --  1st step:
    --    Find all the record key values in ONE shot - with UID keys that expire and such.
    --    A bunch of SUNION and SINTER commands -> into a single redis key
    --    if a value => true, ignore for now
    --    returns an array of redis record keys
    --
    --  2nd step:
    --    Now we have our records.
    --    Create the facets object, which is a hash
    --      c_name => { v => count }
    --    Go through each of the keys *again* - to get counts for all requested fields
    --
    --  3rd step - return all this goodness in a table.
    --
    query = function(query)
      collections = {};
      records_key = xedni.search.find_record_keys(query)
      facet_counts = xedni.search.facet_counts(query)
      local t_count = redis.call('scard', records_key);
      return {records_key = records_key, facets = facet_counts, total_count = t_count};
    end,

    -- This iterates over each of the keys in each query collection
    facet_counts = function(query)
      local results = {};

      local global_record_keys = xedni.search.find_record_keys(query);

      for index, collection in pairs(query) do
        local c_name     = collection[1]
        local values     = collection[2]
        local all_values = xedni.collections.valid_keys(c_name);
        results[c_name] = {}


        local these_record_keys = nil;

        if values == true then
          these_record_keys = global_record_keys;
        else
          local sub_query = deepcopy(query);

          -- If there is only 1 query, kindof search it against everything
          if (#sub_query == 1) then
            sub_query[2] = sub_query[1]
          end
          table.remove(sub_query, index);

          these_record_keys = xedni.search.find_record_keys(sub_query);
        end

        -- If none of our values are 'checked'

        for index, c_val in pairs(all_values) do
          -- We do an intersection and SCARD for each
          local tmp_uid = xedni.uid();
          local this_key = xedni.collections.key(c_name, c_val);

          -- Find the intersection of values
          results[c_name][c_val] = redis.call('sinterstore', tmp_uid, these_record_keys, this_key);
          redis.call('rem', tmp_uid);
        end
      end
      return results;
    end,
    -- This does the hugimongoso query across all the tables and SINTER and SUNIONS everything
    -- into a set of data which is stored in a redis key.
    --
    -- Returns *just* the redis key to pull this stuff out of later on.  So we're not pulling this stuff
    -- all over creation
    find_record_keys = function(query)
      local redis_uid = xedni.uid();
      local collection_result_uids = {}

      -- Load in *all* records now
      assert(redis.call('sunionstore', redis_uid, xedni.records.map_key()));

      for index, collection in pairs(query) do
        local key     = collection[1]
        local values  = collection[2]

        local result_uid = xedni.uid();
        if (values == true) then
          -- Nothing! Skip! This is only here for facet counting.
        else
          -- Store all results from this collection into this redis-store uid
          collection_result_uids[#collection_result_uids+1] = result_uid
          for i, value in pairs(values) do
            local collection_key = xedni.collections.key(key, value)
            redis.call('sunionstore', result_uid, result_uid, collection_key)
          end
        end
      end

      -- Now we have all the 'ORs'.  Let's AND them together
      if (#collection_result_uids > 0 ) then
        redis.call('sinterstore', redis_uid, unpack(collection_result_uids))
      end

      -- One minute from now, we'll expire this key
      redis.call('expire', redis_uid, 360)

      return redis_uid;
    end,

    -- You want to sort these puppies by their score values - given in the weights array.
    sort = function(results, weights)
      -- Explode the results now - into real values
      results.records = assert(redis.call('smembers', results.records_key))

      if (weights == 'default') then
        return results;
      end
      scores = {}
      for index, record_id in pairs(results.records) do
        local score = 0;
        local hash_key = xedni.records.weights_key(record_id);

        for field,weight in pairs(weights) do
          weight_val = redis.call('hget', hash_key, field);
          if (weight_val) then
            score = score + (weight * weight_val);
          end
        end
        scores[record_id] = score
      end

      function weighted_sort(x,y)
        if scores[x] > scores[y] then
          return true
        end
      end

      table.sort(results.records, weighted_sort)

      return results;
    end,
    paginate = function(results, options)
      -- TODO this should be pulled in and be a REDIS LIST
      -- and we do an LRANGE
      if (nil == options.per_page) then
        options.per_page = 1000
      end
      if (nil == options.page) then
        options.page = 1
      end
      local start = (options.page - 1) * options.per_page + 1;
      local count = options.per_page;

      -- TODO -- do this slice in REDIS (See above)
      local paginated_records = {};

      for i = start, start+count-1 do
        paginated_records[#paginated_records+1] = results.records[i];
      end

      results.records = paginated_records;
      return results;
    end
  },
  collections = {
    prefix         = "x:",
    map_key = function(name)
      return xedni.collections.key(name, "_keys");
    end,
    key = function(name, id)
      local key_prefix = xedni.collections.prefix .. name
      local col_prefix = key_prefix .. ":" .. id
      return col_prefix
    end,
    valid_keys = function(c_name)
      return assert(redis.call('smembers', xedni.collections.map_key(c_name)));
    end,
    valid_key = function(c_name, key)
      return assert(redis.call('ismember', xedni.collections.map_key(c_name), key));
    end,
    all_refs = function(c_name, key)
      return assert(redis.call('smembers', xedni.collections.key(c_name, key)));
    end,
    ref_count = function(c_name, key)
      return assert(redis.call('scard', xedni.collections.key(c_name, key)));
    end,
    -- Add a collection membership reference for a record
    add_ref = function(c_name, record_id, collection_ids)
      for index,col_id in pairs(collection_ids) do
        -- Add to list of collection's keys
        assert(redis.call('sadd', xedni.collections.map_key(c_name), col_id));
        -- Add ref
        local key = xedni.collections.key(c_name, col_id)
        assert(redis.call('sadd', key, record_id))
      end
    end,

    -- Remove a collection membership reference for a record
    delete_ref = function(c_name, record_id, collection_ids)
      for index,col_id in pairs(collection_ids) do
        -- remove to list of collection's keys
        assert(redis.call('srem', xedni.collections.map_key(c_name), col_id));
        -- remove ref
        local key = xedni.collections.key(c_name, col_id)
        assert(redis.call('srem', key, record_id))
      end
    end
  },
  records = {
    map_key = function()
      return xedni.collections.map_key('records');
    end,
    key = function(id)
      return xedni.collections.key('records', id);
    end,
    weights_key = function(id)
      return xedni.collections.key('record:weights', id);
    end,
    -- Add a record to xedni
    add = function (id, collections, weights)
      local item_key = xedni.records.key(id);
      local record = {record = id, collections = collections, weights = weights}

      -- Make the reverse index on this thing -- to all the collection keys
      for k,v in pairs(collections) do
        xedni.collections.add_ref(k, id, v)
      end

      -- Now add to the _key set, so we can know all the records in our system.
      assert(redis.call('sadd',xedni.records.map_key(), id));

      -- Now set the data on the record.
      assert(redis.call("set", item_key,                    xedni.pack(record)));

      -- and put the weights into a hash for sorting purposes
      -- When storing in the system for queries, we multiply by 100,
      -- so we can do some floating point
      local weights = {};
      for name, val in pairs(record.weights) do
        weights[name] = val * 100.0;
      end
      assert(redis.call("hmset", xedni.records.weights_key(id),unpack(xedni.records.hset_args(weights))));

      return {item_key, record};
    end,
    hset_args = function(t)
      local args = {}
      for key,val in pairs(t) do
        local len = #args
        args[len+1] = key
        args[len+2] = val
      end
      return args;
    end,
    hget_args = function(t)
        local data = {}
        local last_key = nil;

        for index, v in ipairs(t) do
          if (last_key) then
            data[last_key] = v
            last_key = nil;
          else
            last_key = v
          end
        end

        return data
    end,
    -- Read a record out of Xedni
    read = function(id)
      local item_key = xedni.records.key(id);
      local data = redis.call('get', item_key);
      if (data) then
        return xedni.unpack(data);
      else
        return false;
      end
    end,
    -- Remove a record from Xedni
    delete = function(id)
      local item_key = xedni.records.key(id);
      assert(redis.call('srem', xedni.records.map_key(), id))

      local record = xedni.records.read(id);
      local collections = record.collections

      -- Clean the reverse index on this thing -- from all the collection keys
      for k,v in pairs(collections) do
        xedni.collections.delete_ref(k, id, v)
      end

      -- delete the item key
      redis.call('del', item_key);

      -- delete the item's weights hash
      redis.call('del', xedni.records.weights_key(id));
      record.record = id;
      return record;
    end
  },
  -- This packs a table into a serialized string - we can save this in REDIS and pull it back out
  --
  --
  pack = function(t)
    return json.encode(t);
  end,

  -- This will execute the input and create the table
  --
  unpack = function (str)
    return json.decode(str);
  end
}

--[[
   Author: Julio Manuel Fernandez-Diaz
   Date:   January 12, 2007
   (For Lua 5.1)

   Modified slightly by RiciLake to avoid the unnecessary table traversal in tablecount()

   Formats tables with cycles recursively to any depth.
   The output is returned as a string.
   References to other tables are shown as values.
   Self references are indicated.

   The string returned is "Lua code", which can be procesed
   (in the case in which indent is composed by spaces or "--").
   Userdata and function keys and values are shown as strings,
   which logically are exactly not equivalent to the original code.

   This routine can serve for pretty formating tables with
   proper indentations, apart from printing them:

      print(table.show(t, "t"))   -- a typical use

   Heavily based on "Saving tables with cycles", PIL2, p. 113.

   Arguments:
      t is the table.
      name is the name of the table (optional)
      indent is a first indentation (optional).
--]]
function table.show(t, name, indent)
   local cart     -- a container
   local autoref  -- for self references

   --[[ counts the number of elements in a table
   local function tablecount(t)
      local n = 0
      for _, _ in pairs(t) do n = n+1 end
      return n
   end
   ]]
   -- (RiciLake) returns true if the table is empty
   local function isemptytable(t) return next(t) == nil end

   local function basicSerialize (o)
      local so = tostring(o)
      if type(o) == "function" then
         local info = debug.getinfo(o, "S")
         -- info.name is nil because o is not a calling level
         if info.what == "C" then
            return string.format("%q", so .. ", C function")
         else
            -- the information is defined through lines
            return string.format("%q", so .. ", defined in (" ..
                info.linedefined .. "-" .. info.lastlinedefined ..
                ")" .. info.source)
         end
      elseif type(o) == "number" or type(o) == "boolean" then
         return so
      else
         return string.format("%q", so)
      end
   end

   local function addtocart (value, name, indent, saved, field)
      indent = indent or ""
      saved = saved or {}
      field = field or name

      cart = cart .. indent .. field

      if type(value) ~= "table" then
         cart = cart .. " = " .. basicSerialize(value) .. ";\n"
      else
         if saved[value] then
            cart = cart .. " = {}; -- " .. saved[value]
                        .. " (self reference)\n"
            autoref = autoref ..  name .. " = " .. saved[value] .. ";\n"
         else
            saved[value] = name
            --if tablecount(value) == 0 then
            if isemptytable(value) then
               cart = cart .. " = {};\n"
            else
               cart = cart .. " = {\n"
               for k, v in pairs(value) do
                  k = basicSerialize(k)
                  local fname = string.format("%s[%s]", name, k)
                  field = string.format("[%s]", k)
                  -- three spaces between levels
                  addtocart(v, fname, indent .. "   ", saved, field)
               end
               cart = cart .. indent .. "};\n"
            end
         end
      end
   end

   name = name or "__unnamed__"
   if type(t) ~= "table" then
      return name .. " = " .. basicSerialize(t)
   end
   cart, autoref = "", ""
   addtocart(t, name, indent)
   return cart .. autoref
end

--#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
---#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
---#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
---#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-

-----------------------------------------------------------------------------
-- JSON4Lua: JSON encoding / decoding support for the Lua language.
-- json Module.
-- Author: Craig Mason-Jones
-- Homepage: http://json.luaforge.net/
-- Version: 0.9.40
-- This module is released under the MIT License (MIT).
-- Please see LICENCE.txt for details.
--
-- USAGE:
-- This module exposes two functions:
--   encode(o)
--     Returns the table / string / boolean / number / nil / json.null value as a JSON-encoded string.
--   decode(json_string)
--     Returns a Lua object populated with the data encoded in the JSON string json_string.
--
-- REQUIREMENTS:
--   compat-5.1 if using Lua 5.0
--
-- CHANGELOG
--   0.9.20 Introduction of local Lua functions for private functions (deleted _ function prefix).
--          Fixed Lua 5.1 compatibility issues.
--   		Introduced json.null to have null values in associative arrays.
--          encode() performance improvement (more than 50%) through table.concat rather than ..
--          Introduced decode ability to ignore /**/ comments in the JSON string.
--   0.9.10 Fix to array encoding / decoding to correctly manage nil/null values in arrays.
-----------------------------------------------------------------------------

json = {
  -----------------------------------------------------------------------------
  -- PUBLIC FUNCTIONS
  -----------------------------------------------------------------------------
  --- Encodes an arbitrary Lua object / variable.
  -- @param v The Lua object / variable to be JSON encoded.
  -- @return String containing the JSON encoding in internal Lua string format (i.e. not unicode)
  encode = function(v)
    -- Handle nil values
    if v==nil then
      return "null"
    end

    local vtype = type(v)

    -- Handle strings
    if vtype=='string' then
      return '"' .. json.encodeString(v) .. '"'	    -- Need to handle encoding in string
    end

    -- Handle booleans
    if vtype=='number' or vtype=='boolean' then
      return tostring(v)
    end

    -- Handle tables
    if vtype=='table' then
      local rval = {}
      -- Consider arrays separately
      local bArray, maxCount = json.isArray(v)
      if bArray then
        for i = 1,maxCount do
          table.insert(rval, json.encode(v[i]))
        end
      else	-- An object, not an array
        for i,j in pairs(v) do
          if json.isEncodable(i) and json.isEncodable(j) then
            table.insert(rval, '"' .. json.encodeString(i) .. '":' .. json.encode(j))
          end
        end
      end
      if bArray then
        return '[' .. table.concat(rval,',') ..']'
      else
        return '{' .. table.concat(rval,',') .. '}'
      end
    end

    -- Handle null values
    if vtype=='function' and v==null then
      return 'null'
    end

    assert(false,'encode attempt to encode unsupported type ' .. vtype .. ':' .. tostring(v))
  end,

  --- Decodes a JSON string and returns the decoded value as a Lua data structure / value.
  -- @param s The string to scan.
  -- @param [startPos] Optional starting position where the JSON string is located. Defaults to 1.
  -- @param Lua object, number The object that was scanned, as a Lua table / string / number / boolean or nil,
  -- and the position of the first character after
  -- the scanned JSON object.
  decode = function(s, startPos)
    startPos = startPos and startPos or 1
    startPos = json.decode_scanWhitespace(s,startPos)
    assert(startPos<=string.len(s), 'Unterminated JSON encoded object found at position in [' .. s .. ']')
    local curChar = string.sub(s,startPos,startPos)
    -- Object
    if curChar=='{' then
      return json.decode_scanObject(s,startPos)
    end
    -- Array
    if curChar=='[' then
      return json.decode_scanArray(s,startPos)
    end
    -- Number
    if string.find("+-0123456789.e", curChar, 1, true) then
      return json.decode_scanNumber(s,startPos)
    end
    -- String
    if curChar==[["]] or curChar==[[']] then
      return json.decode_scanString(s,startPos)
    end
    if string.sub(s,startPos,startPos+1)=='/*' then
      return json.decode(s, json.decode_scanComment(s,startPos))
    end
    -- Otherwise, it must be a constant
    return json.decode_scanConstant(s,startPos)
  end,

  --- The null function allows one to specify a null value in an associative array (which is otherwise
  -- discarded if you set the value with 'nil' in Lua. Simply set t = { first=json.null }
  null = function()
    return null -- so json.null() will also return null ;-)
  end,
  -----------------------------------------------------------------------------
  -- Internal, PRIVATE functions.
  -- Following a Python-like convention, I have prefixed all these 'PRIVATE'
  -- functions with an underscore.
  -----------------------------------------------------------------------------

  --- Scans an array from JSON into a Lua object
  -- startPos begins at the start of the array.
  -- Returns the array and the next starting position
  -- @param s The string being scanned.
  -- @param startPos The starting position for the scan.
  -- @return table, int The scanned array as a table, and the position of the next character to scan.
  decode_scanArray = function(s,startPos)
    local array = {}	-- The return value
    local stringLen = string.len(s)
    assert(string.sub(s,startPos,startPos)=='[','decode_scanArray called but array does not start at position ' .. startPos .. ' in string:\n'..s )
    startPos = startPos + 1
    -- Infinite loop for array elements
    repeat
      startPos = json.decode_scanWhitespace(s,startPos)
      assert(startPos<=stringLen,'JSON String ended unexpectedly scanning array.')
      local curChar = string.sub(s,startPos,startPos)
      if (curChar==']') then
        return array, startPos+1
      end
      if (curChar==',') then
        startPos = json.decode_scanWhitespace(s,startPos+1)
      end
      assert(startPos<=stringLen, 'JSON String ended unexpectedly scanning array.')
      object, startPos = json.decode(s,startPos)
      table.insert(array,object)
    until false
  end,

  --- Scans a comment and discards the comment.
  -- Returns the position of the next character following the comment.
  -- @param string s The JSON string to scan.
  -- @param int startPos The starting position of the comment
  decode_scanComment = function(s, startPos)
    assert( string.sub(s,startPos,startPos+1)=='/*', "decode_scanComment called but comment does not start at position " .. startPos)
    local endPos = string.find(s,'*/',startPos+2)
    assert(endPos~=nil, "Unterminated comment in string at " .. startPos)
    return endPos+2
  end,

  --- Scans for given constants: true, false or null
  -- Returns the appropriate Lua type, and the position of the next character to read.
  -- @param s The string being scanned.
  -- @param startPos The position in the string at which to start scanning.
  -- @return object, int The object (true, false or nil) and the position at which the next character should be
  -- scanned.
  decode_scanConstant = function(s, startPos)
    local consts = { ["true"] = true, ["false"] = false, ["null"] = nil }
    local constNames = {"true","false","null"}

    for i,k in pairs(constNames) do
      --print ("[" .. string.sub(s,startPos, startPos + string.len(k) -1) .."]", k)
      if string.sub(s,startPos, startPos + string.len(k) -1 )==k then
        return consts[k], startPos + string.len(k)
      end
    end
    assert(nil, 'Failed to scan constant from string ' .. s .. ' at starting position ' .. startPos)
  end,

  --- Scans a number from the JSON encoded string.
  -- (in fact, also is able to scan numeric +- eqns, which is not
  -- in the JSON spec.)
  -- Returns the number, and the position of the next character
  -- after the number.
  -- @param s The string being scanned.
  -- @param startPos The position at which to start scanning.
  -- @return number, int The extracted number and the position of the next character to scan.
  decode_scanNumber = function(s,startPos)
    local endPos = startPos+1
    local stringLen = string.len(s)
    local acceptableChars = "+-0123456789.e"
    while (string.find(acceptableChars, string.sub(s,endPos,endPos), 1, true)
    and endPos<=stringLen
    ) do
      endPos = endPos + 1
    end
    local stringValue = 'return ' .. string.sub(s,startPos, endPos-1)
    local stringEval = loadstring(stringValue)
    assert(stringEval, 'Failed to scan number [ ' .. stringValue .. '] in JSON string at position ' .. startPos .. ' : ' .. endPos)
    return stringEval(), endPos
  end,

  --- Scans a JSON object into a Lua object.
  -- startPos begins at the start of the object.
  -- Returns the object and the next starting position.
  -- @param s The string being scanned.
  -- @param startPos The starting position of the scan.
  -- @return table, int The scanned object as a table and the position of the next character to scan.
  decode_scanObject = function(s,startPos)
    local object = {}
    local stringLen = string.len(s)
    local key, value
    assert(string.sub(s,startPos,startPos)=='{','decode_scanObject called but object does not start at position ' .. startPos .. ' in string:\n' .. s)
    startPos = startPos + 1
    repeat
      startPos = json.decode_scanWhitespace(s,startPos)
      assert(startPos<=stringLen, 'JSON string ended unexpectedly while scanning object.')
      local curChar = string.sub(s,startPos,startPos)
      if (curChar=='}') then
        return object,startPos+1
      end
      if (curChar==',') then
        startPos = json.decode_scanWhitespace(s,startPos+1)
      end
      assert(startPos<=stringLen, 'JSON string ended unexpectedly scanning object.')
      -- Scan the key
      key, startPos = json.decode(s,startPos)
      assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
      startPos = json.decode_scanWhitespace(s,startPos)
      assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
      assert(string.sub(s,startPos,startPos)==':','JSON object key-value assignment mal-formed at ' .. startPos)
      startPos = json.decode_scanWhitespace(s,startPos+1)
      assert(startPos<=stringLen, 'JSON string ended unexpectedly searching for value of key ' .. key)
      value, startPos = json.decode(s,startPos)
      object[key]=value
    until false	-- infinite loop while key-value pairs are found
  end,

  --- Scans a JSON string from the opening inverted comma or single quote to the
  -- end of the string.
  -- Returns the string extracted as a Lua string,
  -- and the position of the next non-string character
  -- (after the closing inverted comma or single quote).
  -- @param s The string being scanned.
  -- @param startPos The starting position of the scan.
  -- @return string, int The extracted string as a Lua string, and the next character to parse.
  decode_scanString = function(s,startPos)
    assert(startPos, 'decode_scanString(..) called without start position')
    local startChar = string.sub(s,startPos,startPos)
    assert(startChar==[[']] or startChar==[["]],'decode_scanString called for a non-string')
    local escaped = false
    local endPos = startPos + 1
    local bEnded = false
    local stringLen = string.len(s)
    repeat
      local curChar = string.sub(s,endPos,endPos)
      -- Character escaping is only used to escape the string delimiters
      if not escaped then
        if curChar==[[\]] then
          escaped = true
        else
          bEnded = curChar==startChar
        end
      else
        -- If we're escaped, we accept the current character come what may
        escaped = false
      end
      endPos = endPos + 1
      assert(endPos <= stringLen+1, "String decoding failed: unterminated string at position " .. endPos)
    until bEnded
    local stringValue = 'return ' .. string.sub(s, startPos, endPos-1)
    local stringEval = loadstring(stringValue)
    assert(stringEval, 'Failed to load string [ ' .. stringValue .. '] in JSON4Lua.decode_scanString at position ' .. startPos .. ' : ' .. endPos)
    return stringEval(), endPos
  end,

  --- Scans a JSON string skipping all whitespace from the current start position.
  -- Returns the position of the first non-whitespace character, or nil if the whole end of string is reached.
  -- @param s The string being scanned
  -- @param startPos The starting position where we should begin removing whitespace.
  -- @return int The first position where non-whitespace was encountered, or string.len(s)+1 if the end of string
  -- was reached.
  decode_scanWhitespace = function(s,startPos)
    local whitespace=" \n\r\t"
    local stringLen = string.len(s)
    while ( string.find(whitespace, string.sub(s,startPos,startPos), 1, true)  and startPos <= stringLen) do
      startPos = startPos + 1
    end
    return startPos
  end,

  --- Encodes a string to be JSON-compatible.
  -- This just involves back-quoting inverted commas, back-quotes and newlines, I think ;-)
  -- @param s The string to return as a JSON encoded (i.e. backquoted string)
  -- @return The string appropriately escaped.
  encodeString = function(s)
    s = string.gsub(s,'\\','\\\\')
    s = string.gsub(s,'"','\\"')
    s = string.gsub(s,"'","\\'")
    s = string.gsub(s,'\n','\\n')
    s = string.gsub(s,'\t','\\t')
    return s
  end,

  -- Determines whether the given Lua type is an array or a table / dictionary.
  -- We consider any table an array if it has indexes 1..n for its n items, and no
  -- other data in the table.
  -- I think this method is currently a little 'flaky', but can't think of a good way around it yet...
  -- @param t The table to evaluate as an array
  -- @return boolean, number True if the table can be represented as an array, false otherwise. If true,
  -- the second returned value is the maximum
  -- number of indexed elements in the array.
  isArray = function(t)
    -- Next we count all the elements, ensuring that any non-indexed elements are not-encodable
    -- (with the possible exception of 'n')
    local maxIndex = 0
    for k,v in pairs(t) do
      if (type(k)=='number' and math.floor(k)==k and 1<=k) then	-- k,v is an indexed pair
        if (not json.isEncodable(v)) then return false end	-- All array elements must be encodable
        maxIndex = math.max(maxIndex,k)
      else
        if (k=='n') then
          if v ~= getn(t) then return false end  -- False if n does not hold the number of elements
        else -- Else of (k=='n')
          if json.isEncodable(v) then return false end
        end  -- End of (k~='n')
      end -- End of k,v not an indexed pair
    end  -- End of loop across all pairs
    return true, maxIndex
  end,

  --- Determines whether the given Lua object / table / variable can be JSON encoded. The only
  -- types that are JSON encodable are: string, boolean, number, nil, table and json.null.
  -- In this implementation, all other types are ignored.
  -- @param o The object to examine.
  -- @return boolean True if the object should be JSON encoded, false if it should be ignored.
  isEncodable = function(o)
    local t = type(o)
    return (t=='string' or t=='boolean' or t=='number' or t=='nil' or t=='table') or (t=='function' and o==null)
  end
};
Set = {}

function Set.new (t)
  local set = {}
  for _, l in ipairs(t) do set[l] = true end
  return set
end

function Set.union (a,b)
  local res = Set.new{}
  for k in pairs(a) do res[k] = true end
  for k in pairs(b) do res[k] = true end
  return res
end

function Set.intersection (a,b)
  local res = Set.new{}
  for k in pairs(a) do
    res[k] = b[k]
  end
  return res
end

function deepcopy(object)
    local lookup_table = {}
    local function _copy(object)
        if type(object) ~= "table" then
            return object
        elseif lookup_table[object] then
            return lookup_table[object]
        end
        local new_table = {}
        lookup_table[object] = new_table
        for index, value in pairs(object) do
            new_table[_copy(index)] = _copy(value)
        end
        return setmetatable(new_table, getmetatable(object))
    end
    return _copy(object)
end


--#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-#-
