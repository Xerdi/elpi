-- lua-placeholders-parser.lua
-- Copyright 2024 E. Nijenhuis
--
-- This work may be distributed and/or modified under the
-- conditions of the LaTeX Project Public License, either version 1.3c
-- of this license or (at your option) any later version.
-- The latest version of this license is in
-- http://www.latex-project.org/lppl.txt
-- and version 1.3c or later is part of all distributions of LaTeX
-- version 2005/12/01 or later.
--
-- This work has the LPPL maintenance status ‘maintained’.
--
-- The Current Maintainer of this work is E. Nijenhuis.
--
-- This work consists of the files lua-placeholders.sty
-- lua-placeholders-manual.pdf lua-placeholders.lua
-- lua-placeholders-common.lua lua-placeholders-namespace.lua
-- lua-placeholders-parser.lua and lua-placeholders-types.lua

local LUA_VERSION = string.sub(_VERSION, 5, -1)

yaml_supported = false

-- Check if LUA_PATH is set
local current_path = os.getenv('LUA_PATH')
if current_path then
    texio.write_nl('Info: LUA path setup up correctly. Great job!')
else
    -- Set the LUA_PATH and LUA_CPATH using 'luarocks -lua-version <LuaLaTeX version> path'
    texio.write_nl('Warning: No LUA_PATH set. Looking for LuaRocks installation...')
    local handle = io.popen('luarocks --lua-version ' .. LUA_VERSION .. ' path')
    if handle then
        local buffer = handle:read('*a')
        if handle:close() then
            texio.write_nl('Info: luarocks command executed successfully')
            local lua_path, lua_search_count = string.gsub(buffer, ".*LUA_PATH='([^']*)'.*", "%1")
            local lua_cpath, clua_search_count = string.gsub(buffer, ".*LUA_CPATH='([^']*)'.*", "%1")
            if lua_search_count > 0 then
                texio.write_nl('Info: Setting LUA_PATH from LuaRocks', lua_path)
                package.path = lua_path
            end
            if clua_search_count > 0 then
                texio.write_nl('Info: Setting LUA_CPATH from LuaRocks', lua_cpath)
                package.cpath = lua_cpath
            end
        else
            texio.write_nl('Error: couldn\'t find LuaRocks installation')
            texio.write_nl("Info: LUA PATH:\n\t" .. string.gsub(package.path, ';', '\n\t') .. '\n\n')
        end
    else
        tex.error('Error: could not open a shell. Is shell-escape turned on?')
    end
end
texio.write_nl('\n')

-- For falling back to JSON
require('lualibs')

-- Require YAML configuration files
-- Make sure to have the apt package lua-yaml installed
local status, yaml = pcall(require, 'lyaml')
if status then
    yaml_supported = true
else
    texio.write_nl('Warning: No YAML support.')
    texio.write_nl(yaml)
    texio.write_nl('Info: Falling back to JSON.')
end

return function(filename)
    local _, _, ext = string.match(filename, "(.-)([^\\]-([^\\%.]+))$")
    local file = io.open(filename, "rb")
    if not file then
        error('File ' .. filename .. ' doesn\'t exist...')
    end
    local raw = file:read "*a"
    file:close()
    if ext == 'json' then
        return utilities.json.tolua(raw)
    else
        if yaml_supported then
            return yaml.load(raw)
        else
            tex.error('Error: no YAML support!')
        end
    end
end
