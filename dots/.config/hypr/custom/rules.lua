-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- ######## Terminal transparency ########
-- The terminals draw their own translucent background (kitty: background_opacity,
-- foot: colors.alpha), so glyphs stay fully opaque. Hyprland's only job is to blur
-- what shows through: hyprland/rules.lua turns blur off for *every* window
-- (`class = ".*"` -> no_blur), so re-enable it for terminals here.
local terminalClasses = {
    "^(kitty)$",
    "^(foot)$",
    "^(footclient)$",
    "^(Alacritty)$",
    "^(org\\.wezfurlong\\.wezterm)$",
    "^(org\\.kde\\.konsole)$",
}
for _, class in ipairs(terminalClasses) do
    hl.window_rule({ match = { class = class }, no_blur = false })
end
