elpi_toks = {
    new_bool = token.create('newboolean'),
    set_bool = token.create('setboolean'),
    list_conj = token.create('paramlistconjunction'),
    placeholder_format = token.create('paramplaceholder'),
    unknown_format = token.create('paramnotfound')
}

local base_param = {}
function base_param:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self
    return o
end

function base_param:is_set()
    return self and ((self.values or self.fields or self.value) ~= nil)
end

function base_param:val()
    return self.value or self.values or self.default
end

function base_param:print_val()
    local value = self:val()
    if value ~= nil then
        tex.write(value)
    else
        tex.sprint(elpi_toks.placeholder_format, '{', self.placeholder or self.key, '}')
    end
end

bool_param = base_param:new{
    type = 'bool'
}

function bool_param:new(key, _o)
    local o = {
        key = key,
        default = _o.default
    }
    setmetatable(o, self)
    self.__index = self
    tex.sprint(elpi_toks.new_bool, '{', o.key, '}')
    return o
end

function bool_param:val()
    local value
    if self.value ~= nil then
        value = tostring(self.value)
    elseif self.default ~= nil then
        value = tostring(self.default)
    else
        value = 'false'
    end
    return value
end

function bool_param:set_bool(key)
    tex.sprint(elpi_toks.set_bool, '{', key, '}{', self:val(), '}')
end

str_param = base_param:new{
    type = 'string'
}

function str_param:new(key, _o)
    local o = {
        key = key,
        placeholder = _o.placeholder
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

number_param = base_param:new{
    type = 'number'
}

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

function number_param:val()
    if self.value or self.default then
        return tex.number(self.value or self.default)
    end
end

list_param = base_param:new{
    type = 'list'
}

function list_param:new(key, _o)
    local o = {
        key = key,
        item_type = _o["item type"],
        default = _o.default
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function list_param:val()
    return self.values or self.default or {}
end

function list_param:print_val()
    local list = self:val()
    if #list > 0 then
        if not self.values then
            tex.sprint(elpi_toks.placeholder_format, '{')
        end
        tex.sprint(list[1])
        for i = 2, #list do
            tex.sprint(elpi_toks.list_conj, list[i])
        end
        if not self.values then
            tex.sprint('}')
        end
    end
end

object_param = base_param:new{
    type = 'object'
}

local function parse_field(key, o)
    if o.type then
        if key then
            if o.type == 'bool' then
                return bool_param:new(key, o)
            elseif o.type == 'string' then
                return str_param:new(key, o)
            elseif o.type == 'number' then
                return number_param:new(key, o)
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

function object_param:new(key, _o)
    local o = {
        key = key,
        fields = {},
        default = _o.default
    }
    for _key, field in pairs(_o.fields) do
        o.fields[_key] = parse_field(_key, field)
    end
    setmetatable(o, self)
    self.__index = self
    return o
end

table_param = base_param:new{
    type = 'table'
}

local function parse_column(key, o)
    if o.type then
        if key then
            if o.type == 'bool' then
                return bool_param:new(key, o)
            elseif o.type == 'string' then
                return str_param:new(key, o)
            elseif o.type == 'number' then
                return number_param:new(key, o)
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

function table_param:new(key, _o)
    local o = {
        key = key,
        columns = {}
    }
    for _, col in ipairs(_o.columns) do
        table.insert(o.columns, parse_column(col.key, col))
    end
    setmetatable(o, self)
    self.__index = self
    return o
end
