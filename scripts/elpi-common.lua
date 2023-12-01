
function table.copy(t)
    local u = { }
    for k, v in pairs(t) do
        u[k] = v
    end
    return setmetatable(u, getmetatable(t))
end

elpi_toks = {
    new_bool = token.create('newboolean'),
    set_bool = token.create('setboolean'),
    list_conj = token.create('paramlistconjunction'),
    placeholder_format = token.create('paramplaceholder'),
    unknown_format = token.create('paramnotfound')
}
