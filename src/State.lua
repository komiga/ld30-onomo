
State = State or {}
local M = State

State.gen_debug = true
State.gfx_debug = false
State.gfx_debug_cross = false
State.sfx_debug = false

State.edit_mode = false

State.paused = false
State.pause_lock = false

State.auto_reload = true
State.enable_lovebird = true

return M
