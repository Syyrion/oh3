--[[
milua: Lua micro framework for web development

This is a heavily modified version of the server example in https://github.com/duarnimator/lua-http

]]

local os = require("os")
local url = require("net.url")
local http_server = require("http.server")
local http_headers = require("http.headers")
local logger = require("milua.log")

local openssl_ctx = require("openssl.ssl.context")
local pkey = require("openssl.pkey")
local x509 = require("openssl.x509")

local app = {}

local path_handlers = {
    GET = {},
    HEAD = {},
    POST = {},
    PUT = {},
    DELETE = {},
    CONNECT = {},
    OPTIONS = {},
    TRACE = {},
    PATCH = {},
}

-- A handler is a function(captures, query, headers, body) -> res_body, res_headers
function app.add_handler(method, url_pattern, handler)
    local processed_pattern = "^" .. url_pattern:gsub("[.][.][.]", "([^/?]+)") .. "$"
    local exists = path_handlers[method]
    if not exists then
        logger.ERROR("CANNOT ADD HANDLER TO THE METHOD " .. method)
        os.exit()
    end
    path_handlers[method][processed_pattern] = handler
    logger.INFO("Handler added for: " .. method .. " " .. url_pattern)
end

local g_config

local function reply(_, stream) -- luacheck: ignore 212
    -- Read in headers
    local req_headers = assert(stream:get_headers())
    local req_method = req_headers:get(":method")

    -- Get path
    local path = req_headers:get(":path") or ""

    logger.INFO(
        string.format(
            '"%s %s HTTP/%g"  "%s" "%s"\n',
            req_method or "",
            path,
            stream.connection.version,
            req_headers:get("referer") or "-",
            req_headers:get("user-agent") or "-"
        )
    )

    if not path_handlers[req_method] then
        logger.ERROR(string.format("MISSNG %s METHOD", req_method))
        os.exit(1)
    end
    -- Default headers
    local res_headers = http_headers.new()
    res_headers:append(":status", "200")
    res_headers:append("content-type", "text/plain")
    if g_config.cors_url then
        res_headers:append("Access-Control-Allow-Origin", g_config.cors_url)
    end

    -- Look for a pattern that matches the path
    local path_wo_query = path:gsub("?.*", "")
    for pattern, handler in pairs(path_handlers[req_method]) do
        local captures = { path_wo_query:match(pattern) }

        -- The pattern matches
        if #captures > 0 then
            -- Build headers table
            local req_headers_table = {}
            for key, value in req_headers:each() do
                req_headers_table[key] = value
            end

            -- Call handler
            local res_body, ret_res_headers =
                handler(captures, url.parse(path).query, req_headers_table, stream:get_body_as_string())

            -- Merge headers with defaults
            for key, value in pairs(ret_res_headers or {}) do
                if res_headers:has(key) then
                    res_headers:delete(key)
                end
                res_headers:append(key, value)
            end

            -- Send answer
            local result = stream:write_headers(res_headers, false)
            if not result then
                logger.ERROR(string.format("ERROR WRITING THE RESPONSE HEADERS %s", res_headers))
            end
            result = stream:write_body_from_string(res_body, false)
            if not result then
                logger.ERROR(string.format("ERROR WRITING THE RESPONSE BODY %s", res_headers))
            end
            -- RETURN
            return
        end
    end
    -- If the loop ends it means that no pattern matched
    -- RETURN 404
    res_headers:append(":status", 400)
    local response = stream:write_headers(res_headers, false)
    if not response then
        logger.ERROR(string.format("ERROR WRITING THE RESPONSE HEADERS %s", res_headers))
    end
    response = stream:write_body_from_string("Not found")
    if not response then
        logger.ERROR(string.format("ERROR WRITING THE RESPONSE BODY %s", res_headers))
    end
end
-- Reply function for the requests receievd by the server

local function onerror(myserver, context, op, err, errno) -- luacheck: ignore 212
    local msg = op .. " on " .. tostring(context) .. " failed"
    if err then
        msg = msg .. ": " .. tostring(err)
    end
    logger.ERROR(msg)
end

local function read_file(path)
    local file, err, errno = io.open(path, "rb")
    if not file then
        return nil, err, errno
    end
    local contents
    contents, err, errno = file:read("*a")
    file:close()
    return contents, err, errno
end

function app.start(config)
    config = config or {}
    g_config = config
    local ssl_ctx = openssl_ctx.new("TLS", true)
    ssl_ctx:setPrivateKey(pkey.new(assert(read_file(config.key))))
    ssl_ctx:setCertificate(x509.new(assert(read_file(config.cert))))
    local myserver = assert(http_server.listen({
        host = config.HOST,
        port = config.PORT,
        tls = true,
        ctx = ssl_ctx,
        onstream = reply,
        onerror = onerror,
    }))

    -- Manually call :listen() so that we are bound before calling :localname()
    local err, error_msj = pcall(myserver:listen())
    if err then
        logger.ERROR(error_msj)
        os.exit()
    end

    do
        local bound_port = select(3, myserver:localname())
        logger.INFO(string.format("Now listening on port %d\n", bound_port))
    end

    -- Start the main server loop
    assert(myserver:loop())
end

return app
