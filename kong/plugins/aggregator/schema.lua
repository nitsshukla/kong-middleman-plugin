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
    subrequests_conf = {required = true, type = "array"},
    method = { required = true, default = "GET", type = "string", enum = {"GET", "POST","PUT","DELETE"},},
    timeout = { default = 10000, type = "number" },
    keepalive = { default = 60000, type = "number" }
  }
}
