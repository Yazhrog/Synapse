require("core")
require("lazy_setup")

local term = vim.env.TERM or ""
if term:match("ghostty") then
    -- normal/visual/command: steady block
    -- insert/cmd‑line/visual‑select: 25%‑wide vertical bar
    -- replace/cmd‑line‑replace: 20%‑high horizontal bar
    -- all modes: no blinking
    vim.opt.guicursor = {
        "n-v-c:block-blinkon0",
        "i-ci-ve:ver50-blinkon0",
        "r-cr:hor20-blinkon0",
    }
end
