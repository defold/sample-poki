-- Defines shared interface colors used by UI components.
local M = {}

M.primary = vmath.vector4(0.18, 0.86, 0.34, 1)
M.primary_focus = vmath.vector4(0.55, 1.0, 0.68, 1)
M.shop = vmath.vector4(0.15, 0.85, 0.96, 1)
M.shop_equipped = vmath.vector4(0.70, 0.95, 1.0, 1)
M.rewarded = vmath.vector4(0.64, 0.32, 0.92, 1)
M.disabled = vmath.vector4(0.24, 0.32, 0.42, 1)
M.gold = vmath.vector4(1.0, 0.78, 0.20, 1)
M.error = vmath.vector4(1.0, 0.24, 0.10, 1)
M.success = vmath.vector4(0.25, 1.0, 0.68, 1)
M.success_transparent = vmath.vector4(0.25, 1.0, 0.68, 0)
M.fail = vmath.vector4(1.0, 0.40, 0.22, 1)
M.bonus = vmath.vector4(1.0, 0.78, 0.12, 1)
M.bonus_fade = vmath.vector4(1.0, 0.78, 0.12, 0)
M.purchase_flash = vmath.vector4(0.22, 0.62, 0.44, 1)
M.bar_flash = vmath.vector4(1, 0.52, 0.44, 1)

return M
