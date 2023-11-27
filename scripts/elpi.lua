-- Application variables
local APPLICATION_NAME = 'Extended LaTeX Parameter Interface'

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
    strict = false,
    toks = {
        is_set_true = token.create('has@param@true'),
        is_set_false = token.create('has@param@false'),
    }
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
local payload_file
for _, a in ipairs(arg) do
    if string.find(a, '-recipe=.*') then
        recipe_file = string.gsub(a, '-recipe=(.*)', '%1')
        texio.write_nl("Info: using recipe file '" .. recipe_file .. "'.\n")
    end
    if string.find(a, '-params=.*') then
        payload_file = string.gsub(a, '-params=(.*)', '%1')
        texio.write_nl("Info: using params file '" .. payload_file .. "'.\n")
    end
end
texio.write_nl('\n')

require('elpi-types')
local load_resource = require('elpi-parser')

local recipe_loaded = false
local payload_loaded = false

local function get_param(key, namespace)
    namespace = namespace or 'elpi'
    local tbl = api.parameters[namespace]
    return tbl and tbl[key]
end

local function parse_parameter(key, o)
    if o.type then
        if o.type == 'bool' then
            return bool_param:new(key, o)
        elseif o.type == 'string' then
            return str_param:new(key, o)
        elseif o.type == 'number' then
            return number_param:new(key, o)
        elseif o.type == 'list' then
            return list_param:new(key, o)
        elseif o.type == 'object' then
            return object_param:new(key, o)
        elseif o.type == 'table' then
            return table_param:new(key, o)
        else
            texio.write_nl('Warning: no such parameter type ' .. o.type)
        end
    else
        error('ERROR: parameter must have a "type" field')
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
    if not payload_loaded and payload_file then
        api.params()
    end
end

function api.payload(name, namespace)
    namespace = namespace or 'elpi'
    if not recipe_loaded then
        tex.error('Error: tried to load params before recipe. Make sure to first load the recipe.')
        return nil
    end
    if payload_loaded then
        texio.write_nl('Warning: params already loaded. Skipping ' .. name)
        return nil
    end
    local the_file = name or payload_file
    if payload_file and name then
        texio.write_nl("Warning: ignoring params file '" .. name .. "', and loading '" .. payload_file .. "' instead...")
    end

    local values = load_resource(the_file)
    for key, value in pairs(values) do
        if api.parameters[namespace][key] then
            local param = api.parameters[namespace][key]
            if param.type == 'table' or param.type == 'list' or param.type == 'object' then
                param.values = value
            else
                param.value = value
            end
            if param.type == 'bool' then
                param:set_bool(key)
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
    local param = get_param(key, namespace)
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

function api.handle_param_is_set(key, namespace)
    local param = get_param(key, namespace)
    if param.is_set() then
        tex.sprint(token.create('has@param@true'))
    else
        tex.sprint(token.create('has@param@false'))
    end
end

function api.field(object_key, field, namespace)
    local param = get_param(object_key, namespace)
    local object = param.values or param.default or {}
    -- todo: parse field
    --if object and object.print_val then
    --    object.
    --end
end

function api.for_item(list_key, namespace, csname)
    local param = get_param(list_key, namespace)
    local list = param:val()
    if #list > 0 then
        if token.is_defined(csname) then
            local tok = token.create(csname)
            for _, item in ipairs(list) do
                if param.values then
                    tex.sprint(tok, '{', item, '}')
                else
                    tex.sprint(tok, '{', elpi_toks.placeholder_format, '{', item, '}}')
                end
            end
        else
            tex.error('No such command ', csname or 'nil')
        end
    end
end

function api.for_row(csname, key, namespace)

end

function api.for_column(csname, key, namespace)

end

function api.format_rows(csname, key, namespace)
    local param = get_param(key, namespace)
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

-- Load recipe and params from commandline
if recipe_file then
    api.recipe()
end

if payload_file and recipe_loaded then
    api.payload()
end

return elpi
