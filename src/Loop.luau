local RunService = game:GetService("RunService")

local IS_CLIENT = RunService:IsClient()

local jecs = require(script.Parent.Parent.jecs)
local jabby = require(script.Parent.Parent.jabby)

local pair = jecs.pair
local topoRuntime = require(script.Parent.topoRuntime)

local Loop = {}
Loop.__index = Loop

local recentErrors = {}
local recentErrorLastTime = 0

local function systemFn(system)
	if type(system) == "table" then
		return system.system
	end

	return system
end

local function systemName(system)
	local fn = systemFn(system)
	return debug.info(fn, "s") .. "->" .. debug.info(fn, "n")
end

function Loop.new(name, ...)
	local self = setmetatable({}, Loop)

	self._name = name
	self._running = false

	self._state = { ... }
	self._stateLength = select("#", ...)

	self._world = jecs.World.new()
	self._reporter = jabby.scheduler.create(name)

	table.insert(jabby.public, {
		class_name = "World",
		world = self._world,
		name = name .. "-world",
		debug = jecs.Name,
	})

	table.insert(jabby.public, self._reporter)

	self._components = {
		Event = self._world:component(),
		Phase = self._world:component(),
		System = self._world:component(),
		Disabled = self._world:component(),
		DependsOn = self._world:component(),
	}

	self._world:set(self._components.Event, jecs.Name, "Event")
	self._world:set(self._components.Phase, jecs.Name, "Phase")
	self._world:set(self._components.System, jecs.Name, "System")
	self._world:set(self._components.Disabled, jecs.Name, "Disabled")
	self._world:set(self._components.DependsOn, jecs.Name, "DependsOn")

	self.phases = {
		RenderStepped = self._world:component(),
		Heartbeat = self._world:component(),
		PreSimulation = self._world:component(),
		PreAnimation = self._world:component(),
	}

	if IS_CLIENT then
		self._world:add(self.phases.RenderStepped, self._components.Phase)
		self._world:set(self.phases.RenderStepped, self._components.Event, RunService.RenderStepped)
		self._world:set(self.phases.RenderStepped, jecs.Name, "RenderStepped")
	end

	self._world:add(self.phases.Heartbeat, self._components.Phase)
	self._world:set(self.phases.Heartbeat, self._components.Event, RunService.Heartbeat)
	self._world:set(self.phases.Heartbeat, jecs.Name, "Heartbeat")

	self._world:add(self.phases.PreSimulation, self._components.Phase)
	self._world:set(self.phases.PreSimulation, self._components.Event, RunService.PreSimulation)
	self._world:set(self.phases.PreSimulation, jecs.Name, "PreSimulation")

	self._world:add(self.phases.PreAnimation, self._components.Phase)
	self._world:set(self.phases.PreAnimation, self._components.Event, RunService.PreAnimation)
	self._world:set(self.phases.PreAnimation, jecs.Name, "PreAnimation")

	return self
end

function Loop:_collectSystemsUnderPhaseRecursive(systems, phase)
	for _, system in self._world:query(self._components.System):with(pair(self._components.DependsOn, phase)) do
		table.insert(systems, system)
	end
	for after in self._world:query(self._components.Phase):with(pair(self._components.DependsOn, phase)) do
		self:collectSystemsUnderPhaseRecursive(systems, after)
	end
end

function Loop:_collectSystemsUnderEvent(event)
	local systems = {}
	self:_collectSystemsUnderPhaseRecursive(systems, event)

	return systems
end

function Loop:_collect()
	local systems = {}
	for phase, event in self._world:query(self._components.Event):with(self._components.Phase) do
		systems[event] = self:_collectSystemsUnderEvent(phase)
	end
	return systems
end

function Loop:phase(after)
	local phase = self.world:entity()
	self._world:add(phase, self._components.Phase)
	self._world:add(phase, pair(self._components.DependsOn, after))
	return phase
end

function Loop:schedule(system)
	local id = self._world:entity()
	local name = systemName(system)
	local phase = typeof(system) == "table" and system.phase or self.phases.Heartbeat
	local callback = systemFn(system)

	self._world:set(id, self._components.System, {
		name = name,
		callback = callback,
		state = {},
		jabbyId = self._reporter:register_system({ name = name }),
	})

	self._world:add(id, pair(self._components.DependsOn, phase))

	return system
end

function Loop:begin()
	assert(not self._running, string.format("Loop (%s) is already running!", self._name))

	self._running = true

	local connections = {}

	for event, systems in self:_collect() do
		local lastTime = os.clock()

		local function stepSystems()
			local currentTime = os.clock()
			local deltaTime = currentTime - lastTime
			lastTime = currentTime

			for _, system in systems do
				topoRuntime.start({
					system = system.state,
					frame = {
						deltaTime = deltaTime,
					},
					currentSystem = system,
				}, function()
					debug.profilebegin("system: " .. system.name)

					local thread = coroutine.create(function(...)
						self._reporter:run(system.jabbyId, system.callback)
					end)

					local success, errorValue = coroutine.resume(thread, unpack(self._state, 1, self._stateLength))

					if coroutine.status(thread) ~= "dead" then
						coroutine.close(thread)

						task.spawn(
							error,
							(
								"jam: System %s yielded! Its thread has been closed. "
								.. "Yielding in systems is not allowed."
							):format(systemName(system))
						)
					end

					if not success then
						if os.clock() - recentErrorLastTime > 10 then
							recentErrorLastTime = os.clock()
							recentErrors = {}
						end

						local errorString = system.name .. ": " .. "\n" .. debug.traceback(thread)

						if not recentErrors[errorString] then
							task.spawn(error, errorString)
							warn("jam: The above error will be suppressed for the next 10 seconds")
							recentErrors[errorString] = true
						end
					end

					debug.profileend()
				end)
			end
		end

		connections[event] = event:Connect(stepSystems)
	end

	return connections
end

return Loop
