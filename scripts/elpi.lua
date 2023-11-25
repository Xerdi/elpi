-- Application variables
local APPLICATION_NAME = 'Extended LaTeX Parameter Interface'
local LUA_VERSION = string.sub(_VERSION, 5, -1)

if not modules then
    modules = {}
end

modules['doc-payload-spec'] = {
    version = 0.001,
    comment = 'Extended LaTeX Parameter Interface — for specifying and inserting document parameters',
    author = 'Erik Nijenhuis',
    license = 'Copyright 2023 Xerdi'
}

local api = {
    parameters = {},
    strict = false
}
local elpi = {}
local elpi_mt = {
    __index = api,
    __newindex = function()
        error('Cannot override or set actions for this module...')
    end
}

setmetatable(elpi, elpi_mt)

-- Writing the banner
local term_column_size = 78
local padding = (term_column_size - #APPLICATION_NAME) / 2
texio.write_nl(string.rep('=', term_column_size))
texio.write_nl(string.rep(' ', padding) .. APPLICATION_NAME .. string.rep(' ', padding))
texio.write_nl(string.rep('=', term_column_size))
texio.write_nl('')
texio.write_nl(modules['doc-payload-spec'].comment)
texio.write_nl('Version:\t' .. modules['doc-payload-spec'].version)
texio.write_nl('Author:\t\t' .. modules['doc-payload-spec'].author)
texio.write_nl('Copyright:\t' .. modules['doc-payload-spec'].license)
texio.write_nl('\n')

-- Parsing commandline arguments
local recipe_file
local params_file
for _, a in ipairs(arg) do
    if string.find(a, '-recipe=.*') then
        recipe_file = string.gsub(a, '-recipe=(.*)', '%1')
        texio.write_nl("Info: using recipe file '" .. recipe_file .. "'.\n")
    end
    if string.find(a, '-params=.*') then
        params_file = string.gsub(a, '-params=(.*)', '%1')
        texio.write_nl("Info: using params file '" .. params_file .. "'.\n")
    end
end
texio.write_nl('\n')

-- Check if LUA_PATH is set
local current_path = os.getenv('LUA_PATH')
if current_path then
    texio.write_nl('Info: LUA path setup up correctly. Great job!')
else
    -- Set the LUA_PATH and LUA_CPATH using 'luarocks -lua-version <LuaLaTeX version> path'
    texio.write_nl('Warning: No LUA_PATH set. Looking for LuaRocks installation...')
    local handle = io.popen('luarocks --lua-version ' .. LUA_VERSION .. ' path')
    local buffer = handle:read('*a')
    if handle:close() then
        texio.write_nl('Info: luarocks command executed successfully')
        local lua_path, lua_search_count = string.gsub(buffer, ".*LUA_PATH='([^']*)'.*", "%1")
        local lua_cpath, clua_search_count = string.gsub(buffer, ".*LUA_CPATH='([^']*)'.*", "%1")
        if lua_search_count > 0 then
            texio.write_nl('Info: Setting LUA_PATH from LuaRocks')
            package.path = lua_path
        end
        if clua_search_count > 0 then
            texio.write_nl('Info: Setting LUA_CPATH from LuaRocks')
            package.cpath = lua_cpath
        end
    else
        texio.write_nl('Error: couldn\'t find LuaRocks installation')
        texio.write_nl("Info: LUA PATH:\n\t" .. string.gsub(package.path, ';', '\n\t') .. '\n\n')
    end
end
texio.write_nl('\n')


-- Require YAML configuration files
-- Make sure to have the apt package lua-yaml installed
local status, yaml = pcall(require, 'lyaml')
if not status then
    tex.error('Error: no YAML support!')
end
local recipe_loaded = false
local params_loaded = false

local function load_resource(filename)
    if yaml then
        texio.write_nl('Info: Loading resouce: ' .. filename)
        local file = io.open(filename, "rb")
        if not file then
            error('File ' .. filename .. ' doesn\'t exist...')
        end
        local raw = file:read "*a"
        file:close()
        return yaml.load(raw)
    else
        return {}
    end
end

local placeholder_open = '{[}'
local placeholder_close = '{]}'
local function format_placeholder(s)
    return placeholder_open .. s .. placeholder_close
end

-- Prototype Classes
bool_param = {
    type = 'bool'
}
str_param = {
    type = 'string'
}
number_param = {
    type = 'number'
}
currency_param = {
    type = 'currency'
}
select_param = {
    type = 'select'
}
table_param = {
    type = 'table'
}

local function parse_parameter(key, o)
    if o.type then
        if o.type == 'bool' then
            return bool_param:new(key, o)
        elseif o.type == 'string' then
            return str_param:new(key, o)
        elseif o.type == 'number' then
            return number_param:new(key, o)
        elseif o.type == 'currency' then
            return currency_param:new(key, o)
        elseif o.type == 'select' then
            return select_param:new(key, o)
        elseif o.type == 'table' then
            return table_param:new(key, o)
        else
            texio.write_nl('Warning: no such parameter type ' .. o.type)
        end
    else
        error('ERROR: parameter must have a "type" field')
    end
end

local function parse_column(key, o)
    if o.type then
        if key then
            if o.type == 'string' then
                return str_param:new(key, o)
            elseif o.type == 'number' then
                return number_param:new(key, o)
            elseif o.type == 'currency' then
                return currency_param:new(key, o)
            elseif o.type == 'select' then
                return select_param:new(key, o)
            else
                texio.write_nl('Warning: no such column type ' .. o.type)
            end
        else
            error('ERROR: column must have a "key" field')
        end
    else
        error('ERROR: column must have a "type" field')
    end
end

local function parse_recipe_parameters(params, namespace)
    if not api.parameters[namespace] then
        api.parameters[namespace] = {}
    end
    for key, opts in pairs(params) do
        local param = parse_parameter(key, opts)
        if param then
            api.parameters[namespace][key] = param
        end
    end
end

local function parse_recipe(raw_recipe, namespace)
    namespace = namespace or raw_recipe.namespace or 'elpi'
    if raw_recipe.parameters then
        parse_recipe_parameters(raw_recipe.parameters, namespace)
    else
        parse_recipe_parameters(raw_recipe, namespace)
    end
end

function api.set_strict()
    api.strict = true
end

function api.recipe(name)
    if recipe_loaded then
        texio.write_nl('Warning: recipe already loaded. Skipping ' .. name)
        return nil
    end
    local the_file = recipe_file or name
    if recipe_file and name then
        texio.write_nl("Warning: ignoring recipe file '" .. name .. "', and loading '" .. recipe_file .. "' instead...")
    end
    parse_recipe(load_resource(the_file))
    recipe_loaded = true
    if not params_loaded and params_file then
        api.params()
    end
end

function api.params(name, namespace)
    namespace = namespace or 'elpi'
    if not recipe_loaded then
        tex.error('Error: tried to load params before recipe. Make sure to first load the recipe.')
        return nil
    end
    if params_loaded then
        texio.write_nl('Warning: params already loaded. Skipping ' .. name)
        return nil
    end
    local the_file = params_file or name
    if params_file and name then
        texio.write_nl("Warning: ignoring params file '" .. name .. "', and loading '" .. params_file .. "' instead...")
    end

    local values = load_resource(the_file)
    for key, value in pairs(values) do
        if api.parameters[namespace][key] then
            local param = api.parameters[namespace][key]
            if param.type == 'table' then
                param.values = value
            else
                param.value = value
            end
            if param.type == 'bool' then
                param:print_val()
            end
        else
            texio.write_nl('Warning: passed an unknown key ' .. key)
        end
        texio.write_nl('Key ' .. key)
    end

    texio.write_nl('Info: Enabled strict mode!')
    api.strict = true
end

function api.param(key, namespace)
    namespace = namespace or 'elpi'
    local param = api.parameters[namespace] and api.parameters[namespace][key]
    local output
    if param then
        param:print_val()
    else
        output = '\\textbf{' .. placeholder_open .. '{\\normalfont <unknown>} ' .. key .. placeholder_close .. '}'
        texio.write_nl('Warning: no parameter found by key "' .. key .. '"')
    end
    if output then
        texio.write_nl('Writing to tex: \'' .. output .. '\'')
        tex.print(output)
    end
end

function api.format_rows(csname, key, namespace)
    namespace = namespace or 'elpi'
    local param = api.parameters[namespace][key]
    if param then
        if param.values or api.strict then
            if #param.values > 0 then
                texio.write_nl('Writing table ' .. key)
                for _, row in ipairs(param.values) do
                    tex.sprint('\\' .. csname)
                    for __, column in pairs(param.columns) do
                        tex.sprint('{' .. row[column.key] .. '}')
                    end
                end
            end
        elseif param.columns then
            texio.write_nl("Warning: no values set for " .. param.key)
            if #param.columns > 0 then
                tex.sprint('\\' .. csname)
                for _, col in ipairs(param.columns) do
                    tex.sprint('{' .. (col.value or col.default or col.placeholder or '') .. '}')
                end
            end
        else
            error('No values either columns available')
        end
    else
        error('ERROR: no such parameter')
    end
end

-- Boolean Parameter definitions
local newbooltok = token.create('newboolean')
local setbooltok = token.create('setboolean')
function bool_param:new(key, _o)
    local o = {
        key = key,
        default = _o.default
    }
    setmetatable(o, self)
    self.__index = self
    tex.sprint(newbooltok, '{', o.key, '}')
    return o
end

function bool_param:print_val()
    local value
    if self.value ~= nil then
        value = tostring(self.value)
    elseif self.default ~= nil then
        value = tostring(self.default)
    else
        value = 'false'
    end
    tex.sprint(setbooltok, '{', self.key, '}{', value, '}')
end

-- String Parameter definitions

function str_param:new(key, _o)
    local o = {
        key = key,
        placeholder = _o.placeholder
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function str_param:print_val()
    tex.write(self.value or self.placeholder or '')
end

-- Integer Parameter definitions

function number_param:new(key, _o)
    local o = {
        key = key,
        placeholder = _o.placeholder,
        default = _o.default
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function number_param:print_val()
    if self.value or self.default then
        tex.write(tex.number(self.value or self.default))
    else
        tex.write(self.placeholder or 0)
    end
end

-- Currency Parameter definitions

function currency_param:new(key, _o)
    local o = {
        key = key,
        default = _o.default,
        placeholder = _o.placeholder
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function currency_param:print_val()
    if self.value or self.default then
        tex.write(tex.sp(self.value or self.default))
    else
        tex.write(0.00)
    end
end

-- Select Parameter definitions

function select_param:new(key, _o)
    local o = {
        key = key,
        options = _o.options,
        default = _o.default
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function select_param:print_val()
    if self.value or self.default then
        tex.write(self.value or self.default)
    else
        tex.write(format_placeholder(self.key))
    end
end


-- Table Parameter definitions

function table_param:new(key, _o)
    local o = {
        key = key,
        columns = {}
    }
    for _key, col in pairs(_o.columns) do
        table.insert(o.columns, parse_column(_key, col))
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

function table_param:print_val()
    tex.write(format_placeholder(self.key))
end

-- Load recipe and params from commandline
if recipe_file then
    api.recipe()
end

if params_file and recipe_loaded then
    api.params()
end

return elpi
