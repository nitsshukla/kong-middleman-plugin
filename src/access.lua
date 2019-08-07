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


local url1 = {url="http://localhost:8009/a.json", service="aPython"}
local url2 = {url="http://localhost:8009/b.json", service="bPython"}
local _M = {}

local function parse_url(host_url)
  local parsed_url = url.parse(host_url)
  if not parsed_url.port then
    if parsed_url.scheme == HTTP then
      parsed_url.port = 80
     elseif parsed_url.scheme == HTTPS then
      parsed_url.port = 443
     end
  end
  if not parsed_url.path then
    parsed_url.path = "/"
  end
  return parsed_url
end

function _M.execute(conf)
  if not conf.run_on_preflight and get_method() == "OPTIONS" then
    return
  end

  local name = "[middleman] "
  local aggregate_response = {}
  kong.log("urls printnig", conf.urls)
  local threadArray = {}
  local index = 1;
  for i,line in ipairs(conf.urls) do
      print(line)
      local thread = coroutine.create(request);
      threadArray[index] = thread
      index = index + 1
      coroutine.resume(thread, line, aggregate_response)
  end

--[[  coroutine.resume(co2, url1, aggregate_response)
  coroutine.resume(co3, url2, aggregate_response) ]]--
  while (checkAllThreadSuspended(threadArray))
  do  
    socketLib.sleep(0.001)
  end 

  return kong_response.exit(200, aggregate_response)
end

function checkAllThreadSuspended( threadArray )
  for i, thread in ipairs(threadArray) do
    if coroutine.status(thread) == "suspended" then
      return true
    end
  end
  return false
end

function request(url, response)
  local parsed_url = parse_url(url)
  kong.log("requesting url: ", url)
  b,r,h = httpLib.request(url)
  kong.log(b,r,h)
  response[conf.service] = {body=b, status=r}
end

return _M
