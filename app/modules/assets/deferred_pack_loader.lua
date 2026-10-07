-- Downloads the shared Live Update ZIP and loads the requested collection proxies.
---@class starbreaker.deferred_pack_loader
---@field specs table
---@field options table
---@field entries table
---@field archive table
---@field is_alive boolean
local M = {}

local Loader = {}
Loader.__index = Loader

local function exists(path)
	local file = io.open(path, "rb")
	if not file then return false end
	file:close()
	return true
end

---Configure the shared archive and its collection proxies.
---@param config table
---@param options table
---@return starbreaker.deferred_pack_loader
function M.new(config, options)
	return setmetatable({
		specs = config.packs,
		options = options,
		entries = {},
		archive = {
			spec = config.archive,
			state = "WAITING",
			attempts = 0,
			path = sys.get_save_file(options.cache_namespace, config.archive.cache_filename),
		},
		is_alive = true,
	}, Loader)
end

---Check whether a pack's proxy has finished loading.
---@param self starbreaker.deferred_pack_loader
---@param id string
---@return boolean
function Loader:is_ready(id)
	return self.entries[id] and self.entries[id].state == "READY" or false
end

local function current_archive(self, state)
	return self.is_alive and self.archive.state == state
end

local function mounted(spec)
	for _, mount in pairs(liveupdate.get_mounts() or {}) do
		if mount.name == hash(spec.mount_name) then return true end
	end
	return false
end

local function load_pack(self, id, entry)
	if not self.is_alive or self.entries[id] ~= entry or entry.state ~= "WAITING" then return end
	entry.state = "LOADING"
	msg.post(self.options.proxy_owner, "load_pack", { proxy = self.specs[id].proxy })
end

local function archive_ready(self)
	self.archive.state = "READY"
	for id, entry in pairs(self.entries) do
		load_pack(self, id, entry)
	end
end

local function archive_failed(self, reason)
	self.archive.state = "FAILED"
	for id, entry in pairs(self.entries) do
		if self.entries[id] == entry and entry.state == "WAITING" then
			entry.state = "FAILED"
			if self.options.on_failed then self.options.on_failed(id, reason) end
		end
	end
end

local function retry(self, reason)
	local archive = self.archive
	archive.attempts = archive.attempts + 1
	if archive.attempts >= 3 then
		archive_failed(self, reason)
		return
	end
	archive.state = "RETRY"
	timer.delay(archive.attempts, false, function()
		if current_archive(self, "RETRY") then self:attempt_archive() end
	end)
end

local function mount(self)
	local archive = self.archive
	local spec = archive.spec
	archive.state = "MOUNTING"
	local token = {}
	archive.mount = token
	local is_accepted = liveupdate.add_mount(spec.mount_name, "zip:" .. archive.path, spec.priority or 10,
		function(_, _, _, result)
			if not current_archive(self, "MOUNTING") or archive.mount ~= token then return end
			if result == liveupdate.LIVEUPDATE_OK then
				archive_ready(self)
			else
				os.remove(archive.path)
				liveupdate.remove_mount(spec.mount_name)
				retry(self, "mount_failed_" .. tostring(result))
			end
		end)
	if is_accepted == false and current_archive(self, "MOUNTING") then
		os.remove(archive.path)
		retry(self, "mount_rejected")
	end
end

---Use an existing mount/cache or download the archive with retries.
---@param self starbreaker.deferred_pack_loader
function Loader:attempt_archive()
	local archive = self.archive
	local spec = archive.spec
	if not liveupdate or not liveupdate.is_built_with_excluded_files() or mounted(spec) then
		archive_ready(self)
	elseif exists(archive.path) then
		mount(self)
	else
		archive.state = "DOWNLOADING"
		local token = {}
		archive.download = token
		http.request(spec.remote_url, "GET", function(_, _, response)
			if not current_archive(self, "DOWNLOADING") or archive.download ~= token then return end
			response = response or {}
			if response.bytes_total and not response.status then return end
			if not response.error and (response.status == 200 or response.status == 304) and exists(archive.path) then
				mount(self)
			else
				os.remove(archive.path)
				retry(self, "http_" .. tostring(response.error or response.status))
			end
		end, nil, nil, { path = archive.path, timeout = 60 })
	end
end

---Queue a pack once and begin loading its shared archive.
---@param self starbreaker.deferred_pack_loader
---@param id string
---@return boolean
function Loader:request(id)
	local spec = self.specs[id]
	if not spec or not self.is_alive then return false end
	local entry = self.entries[id]
	if entry and entry.state ~= "FAILED" then return true end

	entry = { state = "WAITING" }
	self.entries[id] = entry
	local archive = self.archive
	if archive.state == "READY" then
		load_pack(self, id, entry)
	elseif archive.state == "FAILED" then
		archive.state = "WAITING"
		archive.attempts = 0
		self:attempt_archive()
	elseif archive.state == "WAITING" then
		self:attempt_archive()
	end
	return true
end

---Queue several packs and report whether every ID was accepted.
---@param self starbreaker.deferred_pack_loader
---@param ids string[]
---@return boolean
function Loader:request_many(ids)
	local is_accepted = true
	for _, id in ipairs(ids) do
		is_accepted = self:request(id) and is_accepted
	end
	return is_accepted
end

---Mark the matching collection proxy ready after a pack_loaded message.
---@param self starbreaker.deferred_pack_loader
---@param message_id hash
---@param message table
function Loader:on_message(message_id, message)
	if not self.is_alive or message_id ~= hash("pack_loaded") then return end
	for id, spec in pairs(self.specs) do
		local entry = self.entries[id]
		if entry and entry.state == "LOADING" and msg.url(spec.proxy) == message.proxy then
			entry.state = "READY"
			if self.options.on_ready then self.options.on_ready(id, spec) end
			return
		end
	end
end

---Ignore later async archive callbacks after shutdown.
---@param self starbreaker.deferred_pack_loader
function Loader:final()
	self.is_alive = false
end

return M
