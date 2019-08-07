local JSON = require "kong.plugins.middleman.json"
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

local HTTP = "http"
local HTTPS = "https"

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
  local ok, err
  local parsed_url = parse_url(conf.url)
  kong.log("conf", conf.url, conf)
  b,r,h = httpLib.request(conf.url)
  kong.log(b,r,h)
  return kong_response.exit(status_code, body, headers)
end

function _M.compose_payload(parsed_url)
    local headers = get_headers()
    local uri_args = get_uri_args()
    local next = next
    
    read_body()
    local body_data = get_body()
    kong.log("body_data", body_data)

    headers["target_uri"] = ngx.var.request_uri
    headers["target_method"] = ngx.var.request_method

    --[[ Currently taking request method from ngx, this will be handled when full fledged reques is taken from client--]]
    

    local url
    if parsed_url.query then
      url = parsed_url.path .. "?" .. parsed_url.query
    else
      url = parsed_url.path
    end
    
    local raw_json_headers = JSON:encode(headers)
    local raw_json_body_data = JSON:encode(body_data)

    local raw_json_uri_args
    if next(uri_args) then 
      raw_json_uri_args = JSON:encode(uri_args) 
    else
      -- Empty Lua table gets encoded into an empty array whereas a non-empty one is encoded to JSON object.
      -- Set an empty object for the consistency.
      raw_json_uri_args = "{}"
    end

    local payload_body = [[{"headers":]] .. raw_json_headers .. [[,"uri_args":]] .. raw_json_uri_args.. [[,"body_data":]] .. raw_json_body_data .. [[}]]
    
    local payload_headers = string_format(
      "%s %s HTTP/1.1\r\nHost: %s\r\nConnection: Keep-Alive\r\nContent-Type: application/json\r\nContent-Length: %s\r\n",
      ngx.var.request_method, url, parsed_url.host, #payload_body)
    kong.log(payload_headers)  
    kong.log(payload_body)  
    return string_format("%s\r\n%s", payload_headers, payload_body)
end

return _M
