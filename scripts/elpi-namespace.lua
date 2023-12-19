require('elpi-types')

local namespace = {
    strict = false,
    recipe_file = nil,
    recipe_loaded = false,
    payload_file = nil,
    payload_loaded = false
}

function namespace.parse_filename(path)
    local abs_path = kpse.find_file(path)
    local _, _, name = abs_path:find('/?%w*/*(%w+)%.%w+')
    return name, abs_path
end

function namespace:new(_o)
    local o = {
        recipe_file = _o.recipe_file,
        payload_file = _o.payload_file,
        strict = _o.strict,
        values = {}
    }
    setmetatable(o, self)
    self.__index = self
    return o
end

function namespace:load_recipe(params)
    for key, opts in pairs(params) do
        local param = base_param.define(key, opts)
        if param then
            self.values[key] = param
        end
    end
    self.recipe_loaded = true
end

function namespace:load_payload(values)
    if self.recipe_loaded then
        if values then
            for key, value in pairs(values) do
                if self.values[key] then
                    local param = self.values[key]
                    param:load(key, value)
                else
                    texio.write_nl('Warning: passed an unknown key ' .. key)
                end
                texio.write_nl('Key' .. key)
            end
        else
            texio.write_nl('Warning: Payload file was empty')
        end
        self.payload_loaded = true
    end
end

function namespace:param(key)
    if not self.recipe_loaded then
        tex.error('Error: Recipe was not loaded yet...')
        return nil
    end
    if not self.payload_loaded then
        if self.strict then
            tex.error('Error: Payload was not loaded yet...')
            return nil
        else
            texio.write_nl('Warning: Payload was not loaded yet...')
        end
    end
    return self.values[key]
end

return namespace
