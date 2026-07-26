-- This file will not be overwritten across dots-hyprland updates.
-- The file name is for the sake of organization and does not matter
-- See the corresponding files in ~/.config/hypr/hyprland for examples

-- Start the Hermes Agent proxy so the LLM widget can route through it.
-- The proxy exposes an OpenAI-compatible streaming endpoint at
-- http://127.0.0.1:8645/v1/chat/completions using your Hermes OAuth credentials.
-- Only start if not already running.
hl.exec_cmd("pgrep -f 'hermes proxy start' || hermes proxy start --provider nous --port 8645 &")
