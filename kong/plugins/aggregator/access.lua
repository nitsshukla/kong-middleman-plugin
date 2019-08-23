local JSON = require "kong.plugins.aggregator.json"
local cjson = require "cjson"
local url = require "socket.url"
local kong = kong

local string_format = string.format

local kong_response = kong.response

local get_method = ngx.req.get_method
local httpLib = require("socket.http")
local socketLib = require("socket")

local _M = {}
local THREAD_STATUS_SUSPENDED = "suspended"
local STATUS_OK = 200
local METHOD_OPTIONS = "OPTIONS"
local SLEEP_TIME_IN_S = 0.001
local ARGUMENT_PREFIX = '$'

local aggregator_args_tree = {}

function update_arguments(urls)
  local path = kong.request.get_path();
  local index = 1;
  for path_split in string.gmatch(path, "[^/]+") do
    kong.log(index,path_split)
    aggregator_args_tree[ARGUMENT_PREFIX..index]=path_split
    for i=1,#urls do
      urls[i]=string.gsub(urls[i],ARGUMENT_PREFIX..index,path_split)
      kong.log("sub url ", urls[i])
    end
    index=index+1
  end
  return urls
end

function _M.execute(conf)
  if not conf.run_on_preflight and get_method() == METHOD_OPTIONS then
    return
  end
  kong.log(kong.request)
  local aggregate_response = {}
  local threadArray = {}
  local index = 1;
  kong.log(JSON::encode(conf.urls))
  local urls = update_arguments(conf.urls)
  for i,url in ipairs(urls) do
      local thread = coroutine.create(request);
      threadArray[index] = thread
      index = index + 1
      coroutine.resume(thread, url, aggregate_response)
  end

  while (checkAllThreadSuspended(threadArray))
  do  
    socketLib.sleep(SLEEP_TIME_IN_S)
  end 

  return kong_response.exit(STATUS_OK, aggregate_response)
end

function checkAllThreadSuspended( threadArray )
  for i, thread in ipairs(threadArray) do
    if coroutine.status(thread) == THREAD_STATUS_SUSPENDED then
      return true
    end
  end
  return false
end

function request(url, response)
  kong.log("requesting url: ", url)
  local b,r,h = httpLib.request(url)
  kong.log(b,r,h)
  response[url] = {body=b, status=r}
end

return _M
