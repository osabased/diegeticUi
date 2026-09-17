--!strict

-- This file is analyzed directly by scripts/verify.luau. It proves that the
-- standalone luau-lsp invocation loaded Roblox globals and API types.
local players: Players = game:GetService("Players")
local localPlayer: Player? = players.LocalPlayer

return localPlayer
