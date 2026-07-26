-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- ######## No blur ########
-- Everything that is already translucent — the quickshell panels, the terminals —
-- shows the wallpaper through sharp instead of smeared. hyprland/rules.lua only
-- turns blur off per *window*; the shell's layer surfaces opt back in with
-- `blur = true` layer rules, so kill it at the source here.
-- This changes nothing about how translucent anything is, only how the pixels
-- behind it are sampled.
hl.config({
    decoration = {
        blur = {
            enabled = false
        }
    }
})
