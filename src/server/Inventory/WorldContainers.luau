--!strict

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Janitor = require(ReplicatedStorage.Packages.Janitor)
local Grid = require(ReplicatedStorage.Shared.Inventory.Grid)
local Containers = require(script.Parent.Containers)
local Mutation = require(script.Parent.Mutation)
local TransferCommit = require(script.Parent.TransferCommit)

export type FailureReason = Containers.FailureReason | "NotEligible"
export type TransferResult = TransferCommit.Result
export type SnapshotResult =
	{ Ok: true, Id: string, Snapshot: Grid.InventorySnapshot }
	| { Ok: false, Reason: FailureReason }

type Entry = {
	Id: string,
	Part: BasePart,
	Closing: boolean,
	Claims: number,
	CleanupResources: () -> (),
}

local ACCESS_DISTANCE = 12
local WorldContainers = {}

local function nearby(player: Player, part: BasePart): boolean
	if player.Parent ~= Players or not part:IsDescendantOf(Workspace) then
		return false
	end
	local character = player.Character
	if character == nil then
		return false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root == nil or not root:IsA("BasePart") or humanoid == nil or humanoid.Health <= 0 then
		return false
	end
	return (root.Position - part.Position).Magnitude <= ACCESS_DISTANCE
end

function WorldContainers.new()
	local store = Containers.new()
	local entries: { [string]: Entry } = {}
	local byPart: { [BasePart]: Entry } = {}
	local world = {}

	local function finish(entry: Entry)
		if entry.Closing and entry.Claims == 0 then
			local discarded = store.discard(entry.Id)
			assert(discarded.Ok, "world container still reserved after its final claim")
			entries[entry.Id] = nil
		end
	end

	local function retire(entry: Entry, destroyPart: boolean)
		if entry.Closing then
			return
		end
		entry.Closing = true
		byPart[entry.Part] = nil
		entry.CleanupResources()
		if not destroyPart and entry.Part.Parent ~= nil then
			entry.Part:SetAttribute("ContainerId", nil)
		end
		if destroyPart then
			entry.Part:Destroy()
		end
		finish(entry)
	end

	local function current(id: unknown): Entry?
		if type(id) ~= "string" then
			return nil
		end
		local entry = entries[id]
		if entry == nil or entry.Closing then
			return nil
		end
		if not entry.Part:IsDescendantOf(Workspace) then
			retire(entry, false)
			return nil
		end
		return entry
	end

	function world.bind(part: BasePart, seeds: { Containers.Seed }): SnapshotResult
		if not part:IsA("BasePart") or not part:IsDescendantOf(Workspace) then
			return { Ok = false, Reason = "InvalidRequest" }
		end
		if byPart[part] ~= nil then
			return { Ok = false, Reason = "ContainerExists" }
		end
		local id = HttpService:GenerateGUID(false)
		local created = store.create(id, seeds)
		if not created.Ok then
			return created
		end
		local owner = Janitor.new()
		local entry: Entry = {
			Id = id,
			Part = part,
			Closing = false,
			Claims = 0,
			CleanupResources = function()
				owner:Destroy()
			end,
		}
		entries[id] = entry
		byPart[part] = entry
		part:SetAttribute("ContainerId", id)
		owner:Add(
			part.AncestryChanged:Connect(function()
				if not part:IsDescendantOf(Workspace) then
					retire(entry, false)
				end
			end),
			"Disconnect"
		)
		owner:Add(
			part.Destroying:Connect(function()
				retire(entry, false)
			end),
			"Disconnect"
		)
		return { Ok = true, Id = id, Snapshot = created.Snapshot }
	end

	function world.inspect(player: Player, id: unknown): SnapshotResult
		local entry = current(id)
		if entry == nil then
			return { Ok = false, Reason = "ContainerMissing" }
		end
		if not nearby(player, entry.Part) then
			return { Ok = false, Reason = "NotEligible" }
		end
		local read = store.read(entry.Id)
		if not read.Ok then
			return read
		end
		return { Ok = true, Id = entry.Id, Snapshot = read.Snapshot }
	end

	function world.claim(
		serverData: Mutation.ServerData,
		player: Player,
		id: unknown,
		itemId: unknown,
		expectedPlayerRevision: unknown,
		expectedContainerRevision: unknown,
		timeout: number?
	): TransferCommit.Result
		local entry = current(id)
		if entry == nil then
			return { Ok = false, Reason = "ContainerMissing" }
		end
		if not nearby(player, entry.Part) then
			return { Ok = false, Reason = "NotEligible" }
		end
		entry.Claims += 1
		local ok, result = pcall(function(): TransferCommit.Result
			return TransferCommit.take(
				serverData,
				store,
				player,
				id,
				itemId,
				expectedPlayerRevision,
				expectedContainerRevision,
				timeout,
				function(): boolean
					return not entry.Closing and nearby(player, entry.Part)
				end
			)
		end)
		entry.Claims -= 1
		finish(entry)
		if not ok then
			error(result, 0)
		end
		return result
	end

	function world.expire(id: unknown): { Ok: boolean, Reason: FailureReason? }
		local entry = current(id)
		if entry == nil then
			return { Ok = false, Reason = "ContainerMissing" }
		end
		retire(entry, true)
		return { Ok = true, Reason = nil }
	end

	function world.destroy()
		for _, entry in entries do
			retire(entry, true)
		end
	end

	return world
end

return table.freeze(WorldContainers)
