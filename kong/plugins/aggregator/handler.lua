local BasePlugin = require "kong.plugins.base_plugin"
local access = require "kong.plugins.aggregator.access"

local MiddlemanHandler = BasePlugin:extend()

MiddlemanHandler.PRIORITY = 700
--This is made lower than request-transformer's prioirity i.e. 800

function MiddlemanHandler:new()
  MiddlemanHandler.super.new(self, "aggregator")
end

function MiddlemanHandler:access(conf)
  MiddlemanHandler.super.access(self)
  access.execute(conf)
end

return MiddlemanHandler
