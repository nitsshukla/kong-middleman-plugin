local JSON = require "kong.plugins.aggregator.json"
local cjson = require "cjson"
local url = require "socket.url"
local kong = kong

local string_format = string.format

local kong_response = kong.response

local get_headers = ngx.req.get_headers
local get_uri_args = ngx.req.get_uri_args
local read_body = ngx.req.read_body
local get_body = ngx.req.get_body_data
local get_method = ngx.req.get_method
local ngx_re_match = ngx.re.match
local ngx_re_find = ngx.re.find
local httpLib = require("socket.http")
local socketLib = require("socket")
local HTTP = "http"
local HTTPS = "https"

local _M = {}
local THREAD_STATUS_SUSPENDED = "suspended"
local STATUS_OK = 200
local METHOD_OPTIONS = "OPTIONS"

function getSuffix() 
  local uri_args = get_uri_args()
  kong.log("uri_args", uri_args)
  kong.log("uri_args_type", type(uri_args))

  print_table(uri_args)
  uri_args = uri_args["request"]
  kong.log("uri_args", uri_args)
  local split = string.gmatch(uri_args, "%S+")
  split()
  local path = split()
  return string.gsub(path, "^/[a-z]+", "")
end

function _M.execute(conf)
  if not conf.run_on_preflight and get_method() == METHOD_OPTIONS then
    return
  end
  kong.log(kong.request)
  local aggregate_response = {}
  kong.log("urls printnig", conf.urls)
  --local suffix = getSuffix()
  kong.log("uris: ", uri_args);
  local threadArray = {}
  local index = 1;
  for i,url in ipairs(conf.urls) do
      local thread = coroutine.create(request);
      threadArray[index] = thread
      index = index + 1
      --local modified_url = url + "/" + suffix
      --kong.log("modified_url",modified_url)
      coroutine.resume(thread, url, aggregate_response)
  end

  while (checkAllThreadSuspended(threadArray))
  do  
    socketLib.sleep(0.001)
  end 

  return kong_response.exit(STATUS_OK, aggregate_response)
end

function print_table(table)
  for i,obj in ipairs(table) do
    kong.log("pring table", i, obj)
  end
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
