-- These
xedni_values = {
  records = {
    prefix  = "x:r:",
    map_key = "x:r:_ky"
  },
  collections = {
    prefix         = "x:c:",
    key = function(name, id)
      local key_prefix = xedni_values.collections.prefix .. name
      local col_prefix = key_prefix .. ":" .. id
      return col_prefix
    end
  }
}

xedni_f = {
  -- Add a record to xedni
  add_record = function (id, collections, scores)
    local item_key = xedni_values.records.prefix .. id
    local record = {collections = collections, scores = scores}

    -- Make the reverse index on this thing -- to all the collection keys
    for k,v in pairs(collections) do
      xedni_f.add_collection_ref(k, item_key, v)
    end

    -- Now add to the _key set, so we can know all the records in our system.
    assert(redis.call('sadd',xedni_values.records.map_key, item_key))

    -- Now set the data on the record.
    local data = xedni_f.pack(record)
    assert(redis.call('set', item_key, data))

    return {item_key, record}
  end,

  -- Remove a record from Xedni
  remove_record = function(id)
    local item_key = xedni_values.records.prefix .. id
    assert(redis.call('srem', xedni_values.records.map_key, item_key))

    local record = assert(xedni_f.unpack(redis.call('get', item_key)))
    local collections = record.collections

    -- Clean the reverse index on this thing -- from all the collection keys
    for k,v in pairs(collections) do
      xedni_f.remove_collection_ref(k, item_key, v)
    end

    return {item_key, record}
  end,

  -- Add a collection membership reference for a record
  add_collection_ref = function(collection_name, record_id, collection_ids)
    for index,col_id in pairs(collection_ids) do
      local key = xedni_values.collections.key(collection_name, col_id)
      assert(redis.call('sadd', key, record_id))
    end
  end,

  -- Remove a collection membership reference for a record
  remove_collection_ref = function(collection_name, record_id, collection_ids)
    for index,col_id in pairs(collection_ids) do
      local key = xedni_values.collections.key(collection_name, col_id)
      assert(redis.call('srem', key, record_id))
    end
  end,

  -- This packs a table into an executable string - we can save this in REDIS and pull it back out
  --
  --
  pack = function(Table)
     local savedTables = {} -- used to record tables that have been saved, so that we do not go into an infinite recursion
     local outFuncs = {
        ['string']  = function(value) return string.format("%q",value) end;
        ['boolean'] = function(value) if (value) then return 'true' else return 'false' end end;
        ['number']  = function(value) return string.format('%f',value) end;
     }
     local outFuncsMeta = {
        __index = function(t,k) error('Invalid Type For SaveTable: '..k) end
     }
     setmetatable(outFuncs,outFuncsMeta)
     local tableOut = function(value)
        if (savedTables[value]) then
           error('There is a cyclical reference (table value referencing another table value) in this set.');
        end
        local outValue = function(value) return outFuncs[type(value)](value) end
        local out = '{'
        for i,v in pairs(value) do out = out..'['..outValue(i)..']='..outValue(v)..';' end
        savedTables[value] = true; --record that it has already been saved
        return out..'}'
     end
     outFuncs['table'] = tableOut;
     return tableOut(Table);
  end,

  -- This will execute the input and create the table
  --
  unpack = function (Input)
     -- note that this does not enforce anything, for simplicity
     return assert(loadstring('return '..Input))()
  end
}
