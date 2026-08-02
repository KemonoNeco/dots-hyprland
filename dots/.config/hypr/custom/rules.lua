-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- ######## Terminal transparency ########
-- The terminals draw their own translucent background (kitty: background_opacity,
-- foot: colors.alpha), so glyphs stay fully opaque and the wallpaper shows through
-- sharp. Deliberately *not* blurred: hyprland/rules.lua disables blur for every
-- window (`class = ".*"` -> no_blur) and that is left alone here.
--
-- To blur behind terminals instead, drop `decoration.blur.enabled = false` from
-- custom/general.lua and add `no_blur = false` rules for their classes (kitty,
-- foot, footclient, Alacritty, org.kde.konsole, ...) — custom/ loads after
-- hyprland/, so the false wins.

-- ######## DeskSaw (desktop pet) ########
-- ~/Applications/DeskSaw, launched via the `desksaw` wrapper. It runs on
-- XWayland (class "desktop expie") because the app's own Wayland path is
-- broken. As a pet it must float, follow across workspaces, and carry no
-- decoration of its own so the transparent Godot window reads as a sprite
-- sitting on the desktop rather than a window.
hl.window_rule({match = {class = "^(desktop expie)$" }, float = true})
hl.window_rule({match = {class = "^(desktop expie)$" }, pin = true})
hl.window_rule({match = {class = "^(desktop expie)$" }, no_shadow = true})
hl.window_rule({match = {class = "^(desktop expie)$" }, border_size = 0})
hl.window_rule({match = {class = "^(desktop expie)$" }, rounding = 0})
hl.window_rule({match = {class = "^(desktop expie)$" }, no_anim = true})

-- The pet's own click-through does not survive this compositor: it asks Godot
-- for mouse passthrough outside the sprite, and neither the XWayland path
-- (X11 input shape) nor the native Wayland path honours it here — verified by
-- clicking through the overlay onto a window below in both. So the window is
-- all-or-nothing input, and `no_focus` picks which:
--   enabled  -> clicks fall through to the desktop, pet is decorative
--   disabled -> pet is interactive (pet/drag/console), overlay eats all input
-- Default is decorative so a running pet never locks the desktop out.
DESKSAW_DECORATIVE = hl.window_rule({
    name = "desksaw-decorative",
    match = {class = "^(desktop expie)$" },
    no_focus = true,
})

hl.bind("SUPER + ALT + P", function()
    local on = not DESKSAW_DECORATIVE:is_enabled()
    DESKSAW_DECORATIVE:set_enabled(on)
    hl.notification.create({
        text = on and "DeskSaw: decorative (clicks pass through)"
                   or "DeskSaw: interactive (overlay takes clicks)",
        timeout = 2000,
    })
end, {description = "DeskSaw: toggle pet interactivity"})
