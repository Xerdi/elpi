-- Application variables
local APPLICATION_NAME = 'Extended LaTeX Parameter Interface'

if not modules then
    modules = {}
end

modules.elpi = {
    version = 0.001,
    comment = 'Extended LaTeX Parameter Interface — for specifying and inserting document parameters',
    author = 'Erik Nijenhuis',
    license = 'Copyright 2023 Xerdi'
}

local api = {
    namespaces = {},
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
texio.write_nl(modules.elpi.comment)
texio.write_nl('Version:\t' .. modules.elpi.version)
texio.write_nl('Author:\t\t' .. modules.elpi.author)
texio.write_nl('Copyright:\t' .. modules.elpi.license)
texio.write_nl('\n')

-- Parsing commandline arguments
local recipe_files = {}
local payload_files = {}
for _, a in ipairs(arg) do
    if string.find(a, '-+recipe=.*') then
        local recipe_file = string.gsub(a, '-+recipe=(.*)', '%1')
        table.insert(recipe_files, recipe_file)
        texio.write_nl("Info: using recipe file '" .. recipe_file .. "'.\n")
    end
    if string.find(a, '-+payload=.*') then
        local payload_file = string.gsub(a, '-+payload=(.*)', '%1')
        table.insert(payload_files, payload_file)
        texio.write_nl("Info: using payload file '" .. payload_file .. "'.\n")
    end
    if string.find(a, '-+final') then
        api.strict = true
    end
end
texio.write_nl('\n')

local elpi_namespace = require('elpi-namespace')
local load_resource = require('elpi-parser')

local function get_param(key, namespace)
    namespace = namespace or tex.jobname
    local _namespace = api.namespaces[namespace]
    return _namespace and _namespace:param(key)
end

function api.set_strict()
    api.strict = true
end

function api.recipe(path, namespace_name)
    if namespace_name == '' then
        namespace_name = nil
    end
    local filename, abs_path = elpi_namespace.parse_filename(path)
    local raw_recipe = load_resource(abs_path)
    local name = namespace_name or raw_recipe.namespace or filename
    local namespace = api.namespaces[name] or elpi_namespace:new { recipe_file = abs_path, strict = api.strict }
    if not api.namespaces[name] then
        api.namespaces[name] = namespace
    end
    if raw_recipe.namespace then
        namespace:load_recipe(raw_recipe.parameters)
    else
        namespace:load_recipe(raw_recipe)
    end
    if namespace.payload_file and not namespace.payload_loaded then
        local raw_payload = load_resource(namespace.payload_file)
        if raw_payload.namespace then
            namespace:load_payload(raw_payload.parameters)
        else
            namespace:load_payload(raw_payload)
        end
    end
end

function api.payload(path, namespace_name)
    if namespace_name == '' then
        namespace_name = nil
    end
    local filename, abs_path = elpi_namespace.parse_filename(path)
    local raw_payload = load_resource(abs_path)
    local name = namespace_name or raw_payload.namespace or filename
    local namespace = api.namespaces[name] or elpi_namespace:new { payload_file = abs_path, strict = api.strict }
    if not api.namespaces[name] then
        api.namespaces[name] = namespace
    end
    if namespace.recipe_loaded then
        if raw_payload.namespace then
            namespace:load_payload(raw_payload.parameters)
        else
            namespace:load_payload(raw_payload)
        end
    end
end

function api.param_object(key, namespace)
    return get_param(key, namespace)
end

function api.param(key, namespace)
    local param = get_param(key, namespace)
    if param then
        param:print_val()
    else
        tex.sprint(elpi_toks.unknown_format, '{', key, '}')
    end
end

function api.handle_param_is_set(key, namespace)
    local param = get_param(key, namespace)
    if param and param.is_set() then
        tex.sprint(token.create('has@param@true'))
    else
        tex.sprint(token.create('has@param@false'))
    end
end

function api.field(object_key, field, namespace)
    local param = get_param(object_key, namespace)
    if param then
        local object = param.fields or param.default or {}
        local f = object[field]
        if f then
            f:print_val()
        else
            tex.sprint(elpi_toks.unknown_format, '{', field, '}')
        end
    else
        tex.error('No such object', object_key)
    end
end

function api.with_object(object_key, namespace)
    local object = get_param(object_key, namespace)
    for key, param in pairs(object.fields) do
        local val = param:val()
        if val then
            token.set_macro(key, param:val() .. '\\xspace')
        else
            token.set_macro(key, '\\paramplaceholder{' .. (param.placeholder or key) .. '}\\xspace')
        end
    end
end

function api.for_item(list_key, namespace, csname)
    local param = get_param(list_key, namespace)
    local list = param:val()
    if #list > 0 then
        if token.is_defined(csname) then
            local tok = token.create(csname)
            for _, item in ipairs(list) do
                if param.values then
                    tex.sprint(tok, '{', item:val(), '}')
                else
                    tex.sprint(tok, '{', elpi_toks.placeholder_format, '{', item:val(), '}}')
                end
            end
        else
            tex.error('No such command ', csname or 'nil')
        end
    end
end

function api.with_rows(key, namespace, csname)
    local param = get_param(key, namespace)
    if token.is_defined(csname) then
        local row_content = token.get_macro(csname)
        if param then
            if param.values or api.strict then
                if #param.values > 0 then
                    for _, row in ipairs(param.values) do
                        local format = row_content
                        for col_key, cell in pairs(row) do
                            format = format:gsub('\\' .. col_key, cell:val())
                        end
                        tex.print(format)
                    end
                end
            elseif param.columns then
                texio.write_nl("Warning: no values set for " .. param.key)
                local format = row_content
                for col_key, col in pairs(param.columns) do
                    format = format:gsub('\\' .. col_key, '{\\paramplaceholder{' .. (col.placeholder or col_key) .. '}}')
                end
                tex.print(format)
            else
                tex.error('No values either columns available')
            end
        else
            tex.error('Error: no such parameter')
        end
    else
        tex.error('Error: no such command: ', csname or 'nil')
    end
end

for _, path in ipairs(recipe_files) do
    api.recipe(path)
end

for _, path in ipairs(payload_files) do
    api.payload(path)
end

return elpi
