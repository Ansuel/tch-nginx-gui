-- Based on agentzh's lua-resty-upload (see https://github.com/agentzh/lua-resty-upload),
-- but more generic: it not only supports streamed processing of the request
-- body but also body data that nginx stored in memory or a temporary file.
--
-- How to use: the module exports two functions:
-- - fromstream([chunk_size]): this is the original lua-resty-upload; it reads
--   the request data directly from the socket. Note that this means you cannot
--   have lua_need_request_body on in nginx.conf and that ngx.req.read_body()
--   must not have been called.
-- - frombody([chunk_size]): this accesses the request data after nginx has
--   stored it either in memory or in a temporary file. You must have
--   lua_need_request_body on in nginx.conf or you must have called
--   ngx.req.read_body() prior to calling frombody().
-- Both functions return either nil + error message or a upload context that
-- has one method read(); see the original lua-resty-upload documentation.
--
-- IMPORTANT NOTE: the CSRFtoken *must* be the first piece of data; if not the
-- request is aborted!
--
-- Implementation details: the core of the module uses a state machine to parse
-- the data. Where the data comes from is abstracted away behind a data source
-- object. Such a source exposes two methods: receiveuntil(pattern) and
-- receive(size). For more info on those methods see the ngx_lua documentation
-- about methods on cosockets. Note that the buffer source and file source
-- only implement what is needed for this fileupload module to work.

local ngx = ngx
local get_headers = ngx.req.get_headers
local req_socket = ngx.req.socket
local log, ERR = ngx.log, ngx.ERR
local type = type
local match, find, lower = string.match, string.find, string.lower


--[[ processing of uploaded data ]]--

local MAX_LINE_SIZE = 512

local STATE_BEGIN = 1
local STATE_READING_HEADER = 2
local STATE_READING_BODY = 3
local STATE_EOF = 4


local function discard_line(self)
  local read_line = self.read_line

  local line, err = read_line(MAX_LINE_SIZE)
  if not line then
    return nil, err
  end

  local dummy, err = read_line(1)
  if dummy then
    return nil, "line too long: " .. line .. dummy .. "..."
  end

  if err then
    return nil, err
  end

  return true
end

local function discard_rest(self)
  local src = self.src
  local size = self.size

  while true do
    local dummy, err = src:receive(size)
    if err and err ~= 'closed' then
      return nil, err
    end

    if not dummy then
      return true
    end
  end
end

local function read_body_part(self)
  local read2boundary = self.read2boundary

  local chunk, err = read2boundary(self.size)
  if err then
      return nil, nil, err
  end

  if not chunk then
    local src = self.src

    local data = src:receive(2)
    if data == "--" then
      local ok, err = discard_rest(self)
      if not ok then
        return nil, nil, err
      end

      self.state = STATE_EOF
      return "part_end"
    end

    if data ~= "\r\n" then
      local ok, err = discard_line(self)
      if not ok then
        return nil, nil, err
      end
    end

    self.state = STATE_READING_HEADER
    return "part_end"
  end

  return "body", chunk
end

-- TODO: we should parse headers lines and make them
--       available in a nice structure
local function read_header(self)
  local read_line = self.read_line

  local line, err = read_line(MAX_LINE_SIZE)
  if err then
    return nil, nil, err
  end

  local dummy, err = read_line(1)
  if dummy then
    return nil, nil, "line too long: " .. line .. dummy .. "..."
  end

  if err then
    return nil, nil, err
  end

  if line == "" then
    -- after the last header
    self.state = STATE_READING_BODY
    return read_body_part(self)
  end

  local key, value = match(line, "([^: \t]+)%s*:%s*(.+)")
  if not key then
    return 'header', line
  end

  return 'header', {key, value, line}
end

-- forward declaration
local read

local function check_CSRFtoken(self)
  local token, data = read(self)
  if token ~= "header" or
     lower(data[1]) ~= "content-disposition" or
     find(data[2], 'name="CSRFtoken"', 1, true) == nil then
    log(ERR, "no CSRFtoken as first data")
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end
  token, data = read(self)
  if token ~= "body" or
     not ngx.ctx.session:checkCSRFtoken(data) or
     read(self) ~= "part_end" then
    log(ERR, "invalid CSRFtoken")
    ngx.exit(ngx.HTTP_FORBIDDEN)
  end
  return read(self)
end

local function read_preamble(self)
  local src = self.src
  local size = self.size
  local read2boundary = self.read2boundary

  while true do
    local preamble, err = read2boundary(size)
    if not preamble then
      break
    end
    -- discard the preamble data chunk
  end

  local ok, err = discard_line(self)
  if not ok then
    log(ERR, "no CSRFtoken as first data")
    ngx.exit(ngx.HTTP_FORBIDDEN)
    --return nil, nil, err
  end

  local read2boundary, err = src:receiveuntil("\r\n--" .. self.boundary)
  if not read2boundary then
    log(ERR, "no CSRFtoken as first data")
    ngx.exit(ngx.HTTP_FORBIDDEN)
    --return nil, nil, err
  end

  self.read2boundary = read2boundary
  self.state = STATE_READING_HEADER
  return check_CSRFtoken(self)
end

local function eof()
  return "eof"
end

local state_handlers = {
  read_preamble,
  read_header,
  read_body_part,
  eof
}

read = function(self)
  local handler = state_handlers[self.state]
  if handler then
    return handler(self)
  end

  return nil, nil, "bad state: " .. self.state
end


--[[ reading from upstream socket ]]--

local function create_sk_src()
  local sk, err = req_socket()
  if not sk then
    return nil, err
  end
  -- socket already has an appropriate
  -- implementation of the common methods 
  return sk
end


--[[ upload ctx creation ]]--

local function get_boundary()
  local header = get_headers()["content-type"]
  if not header then
    return nil
  end

  if type(header) == "table" then
    header = header[1]
  end

  local m = match(header, ";%s*boundary=\"([^\"]+)\"")
  if m then
    return m
  end

  return match(header, ";%s*boundary=([^\",;]+)")
end

local function create_ctx(src, boundary, chunk_size)
  local read2boundary, err = src:receiveuntil("--" .. boundary)
  if not read2boundary then
    return nil, err
  end

  local read_line, err = src:receiveuntil("\r\n")
  if not read_line then
    return nil, err
  end

  return {
    read = read,  -- the public method that users call to get the next token + data
    src = src,  -- the data source
    size = chunk_size or 4096,
    read2boundary = read2boundary,
    read_line = read_line,
    boundary = boundary,  -- the boundary string as provided in the content-type header
    state = STATE_BEGIN
  }
end


--[[ module API ]]--

return {
  fromstream = function(chunk_size)
    local boundary = get_boundary()
    if not boundary then
        return nil, "no boundary defined in Content-Type"
    end
    local src, err = create_sk_src()
    if not src then
      return nil, err
    end
    return create_ctx(src, boundary, chunk_size)
  end
}
