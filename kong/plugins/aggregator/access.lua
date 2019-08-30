local JSON = require "kong.plugins.aggregator.json"
local url = require "socket.url"

local kong = kong

local kong_response = kong.response

local get_method = ngx.req.get_method
local get_headers = ngx.req.get_headers

local httpLib = require("socket.http")
local httpsLib = require("ssl.https")
local socketLib = require("socket")
local cacheMgr;

local _M = {}
local THREAD_STATUS_SUSPENDED = "suspended"
local STATUS_OK = 200
local METHOD_OPTIONS = "OPTIONS"
local SLEEP_TIME_IN_S = 0.001
local ARGUMENT_PREFIX = '$'
local QUERY_PARAM_PREFIX = '#'

local aggregator_args_tree = {}

function update_tree()
  local path = kong.request.get_path();
  kong.log("paht: ", path)
  for key, value in pairs(kong.request.get_query()) do
    kong.log.inspect(key, value)
    aggregator_args_tree[QUERY_PARAM_PREFIX..key]=value
  end

  local index = 1;
  for path_split in string.gmatch(path, "[^/]+") do
    kong.log(index,path_split)
    aggregator_args_tree[ARGUMENT_PREFIX..index]=path_split
    index=index+1
  end
end

function get_filled_request(subrequest)
  kong.log("Got url", subrequest.url)
  for key, value in pairs(aggregator_args_tree) do
    kong.log(key,value)
    subrequest.url=string.gsub(subrequest.url,key,value)
    if subrequest.data ~= nil then
      subrequest.data=string.gsub(subrequest.data,key,value)
    end
  end
  return subrequest;
end

function _M.execute(conf)
  if not conf.run_on_preflight and get_method() == METHOD_OPTIONS then
    return
  end

  local aggregate_response = {}
  local threadArray = {}
  local index = 1;
  kong.log(conf.subrequests_conf[1])
  local subrequests = conf.subrequests_conf
  update_tree()
  --local urls = update_arguments(conf.urls)
  for i,subrequest_json in pairs(subrequests) do
      local thread = coroutine.create(request);
      threadArray[index] = thread
      index = index + 1
      local subrequest = JSON:decode(subrequest_json)
      subrequest = get_filled_request(subrequest)
      coroutine.resume(thread, url, aggregate_response, subrequest)
      --take care of defaults?
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

function get_refresh_token(key)
    local auth_token = JSON:decode(key)
    for k,v in pairs(auth_token.headers) do
      kong.log("sub auth header",k,": ",v)
    end
    for k,v in pairs(auth_token.data) do
      kong.log("sub auth data",k,": ",v)
    end
    kong.log("auth_token.method ", auth_token.method)
    local auth_response_json,status,header = http_request(auth_token.url,auth_token.method,auth_token.headers,JSON:encode(auth_token.data))
    --need to validate 200 status and cache using 'refreshExpireIn'
    if status ~= 200 then
      kong.log("Auth service failed to return"); --should retry
      return nil;
    end
    kong.log(auth_response_json)
    local auth_response = JSON:decode(auth_response_json)
    return auth_response.tokenType..' '..auth_response.accessToken, auth_response.expiresIn
end

function request(url, response, subrequest)
  kong.log("requesting url: ", url, " method: ", subrequest.method)
  local headers=get_headers() --any other header?

  kong.log("Getting for ", subrequest.name)
  if subrequest["auth_token"]~=nil then
    if cacheMgr == nil then
      cacheMgr = kong.cache
      kong.log("created cache")
    end
    local auth_token_info = subrequest["auth_token"];
    auth_token_info["name"]=subrequest.name;
    local  auth_token_info_json = JSON:encode(auth_token_info);
    headers["authorization"] = cacheMgr:get(auth_token_info_json, nil, get_refresh_token, auth_token_info_json);
    local ttl = cacheMgr:probe(auth_token_info_json)
    kong.log("TTL", ttl);
  end
  
  for k,v in pairs(headers) do
    kong.log("header",k,": ",v)
  end
 kong.log("original subrequest: ", subrequest);
 local body, status, header = http_request(subrequest.url,subrequest.method,headers,subrequest.data)
 response[subrequest.name] = {body=body,status=status,header=header}
end
--- HTTP request for given inputs
-- @param url the cache key to lookup first
-- @param method the location of the key file
-- @return the response, status, header
function http_request(url, method, headers, source)
  local chunks={}
  local body_response,immediate_body_response,status,header_response;
 
  if string.lower(method)=="post" then
    headers["Content-Length"]=#source
    kong.log("post doing ")
  end

  local request_info = {
    url=url,
    method=method,
    headers=headers,
    sink = ltn12.sink.table(chunks)
  }
  if string.lower(method)=="post" then
    request_info["source"]=ltn12.source.string(source)
  end
  if string.match(url,"^https.*") then
    immediate_body_response,status,header_response = httpsLib.request(request_info)
  else
    immediate_body_response,status,header_response = httpLib.request(request_info)
  end
  body_response = table.concat(chunks)
  kong.log(body_response,"status",status)
  for k,v in pairs(header_response) do
      kong.log("response header",k,": ",v)
  end
  return body_response,status,header_response; 
end

return _M
