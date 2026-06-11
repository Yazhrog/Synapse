-- Clases que flotan por window_rule y tienen tamaño propio
local _skip_classes = {
    "pavucontrol",
    "nm-connection-editor",
    "blueman-manager",
    "flameshot",
    "vsfetch",
}

local function _is_auto_float(window)
    local cls = (window and window.class) or ""
    for _, c in ipairs(_skip_classes) do
        if cls:find(c, 1, true) then return true end
    end
    if cls:find("webapp%-", 1, true) then return true end
    return false
end

-- Rastrea estado anterior de float por ventana
local _prev_float = {}

-- window.update_rules se dispara cuando cambian las propiedades de una ventana
hl.on("window.update_rules", function(window)
    if not window then return end
    local addr = window.address
    local floating = window.floating
    local prev = _prev_float[addr]
    _prev_float[addr] = floating
    -- Solo actuar cuando transiciona de tiled → floating
    if floating and not prev and not _is_auto_float(window) then
        hl.dispatch(hl.dsp.window.resize({exact=true, x=900, y=600}))
        hl.dispatch(hl.dsp.window.center())
    end
end)
