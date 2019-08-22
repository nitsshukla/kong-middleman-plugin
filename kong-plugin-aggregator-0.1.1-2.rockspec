package = "kong-plugin-aggregator"

version = "0.1.1-2"

-- The version '0.1.1' is the source code version, the trailing '1' is the version of this rockspec.
-- whenever the source version changes, the rockspec should be reset to 1. The rockspec version is only
-- updated (incremented) when this file changes, but the source remains the same.

local pluginName = package:match("^kong%-plugin%-(.+)$")  
supported_platforms = {"linux", "macosx"}

source = {
  url = "http://localhost:8009",
  tag = "0.1.1"
}

description = {
  summary = "A Kong plugin that allows for an extra HTTP requests to be aggregated and returned as response.", 
  license = "AJIO"
}

dependencies = {
}

build = {
  type = "builtin",
  modules = {
    ["kong.plugins."..pluginName..".handler"] = "kong/plugins/"..pluginName.."/handler.lua",
    ["kong.plugins."..pluginName..".schema"] = "kong/plugins/"..pluginName.."/schema.lua",
    ["kong.plugins."..pluginName..".access"] = "kong/plugins/"..pluginName.."/access.lua",
    ["kong.plugins."..pluginName..".json"] = "kong/plugins/"..pluginName.."/json.lua",
  }
}
