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

function update_tree()
  local path = kong.request.get_path();
  local index = 1;
  for path_split in string.gmatch(path, "[^/]+") do
    kong.log(index,path_split)
    aggregator_args_tree[ARGUMENT_PREFIX..index]=path_split
    index=index+1
  end
end

function get_filled_url(url)
  local path = kong.request.get_path();
  local index = 1;
  for key, value in aggregator_args_tree do
    url=string.gsub(url,ARGUMENT_PREFIX..key,value)
  end
  return url;
end

function _M.execute(conf)
  if not conf.run_on_preflight and get_method() == METHOD_OPTIONS then
    return
  end
  kong.log(kong.request)
  local aggregate_response = {}
  local threadArray = {}
  local index = 1;
  subrequests = JSON:decode(conf.subrequests_conf)
  update_tree()
  --local urls = update_arguments(conf.urls)
  for i,subrequest in ipairs(subrequests) do
      local thread = coroutine.create(request);
      threadArray[index] = thread
      index = index + 1
      local url = get_filled_url(subrequest.url)
      coroutine.resume(thread, url, aggregate_response, subrequest.method)
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

function request(url, response, method)
  kong.log("requesting url: ", url, " method: ", method)
  local b,r,h = httpLib.request(url)
  kong.log(b,r,h)
  response[url] = {body=b, status=r}
end

return _M
