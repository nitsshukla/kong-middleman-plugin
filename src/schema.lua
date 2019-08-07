local colon_string_array = {
  type = "array",
  default = {},
  elements = { type = "string" },
}

local colon_string_record = {
  type = "record",
  fields = {
    { json = colon_string_array },
  },
}

return {
  no_consumer = true,
  fields = {
    urls = {required = true, type = "record"},
    response = { required = true, default = "table", type = "string", enum = {"table", "string"}},
    timeout = { default = 10000, type = "number" },
    keepalive = { default = 60000, type = "number" }
  }
}