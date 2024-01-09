-- elpi-common.lua
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
-- This work consists of the files elpi.sty elpi-manual.pdf
-- elpi.lua elpi-common.lua elpi-namespace.lua elpi-parser.lua
-- and elpi-types.lua

function table.copy(t)
    local u = { }
    for k, v in pairs(t) do
        u[k] = v
    end
    return setmetatable(u, getmetatable(t))
end

elpi_toks = {
    new_bool = token.create('provideboolean'),
    set_bool = token.create('setboolean'),
    list_conj = token.create('paramlistconjunction'),
    placeholder_format = token.create('paramplaceholder'),
    unknown_format = token.create('paramnotfound')
}
