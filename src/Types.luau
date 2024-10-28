local Jabby = require(script.Parent.Parent.Jabby)
local Jecs = require(script.Parent.Parent.Jecs)

export type System = { system: () -> () } | () -> ()

export type Loop<T...> = {
	phases: {
		RenderStepped: Jecs.Entity<number>,
		Heartbeat: Jecs.Entity<number>,
		PreSimulation: Jecs.Entity<number>,
		PreAnimation: Jecs.Entity<number>,
	},
	phase: (after: Jecs.Entity<number>) -> Jecs.Entity<number>,
	schedule: (self: Loop<T...>, system: System, phase: number?) -> System,
	begin: (self: Loop<T...>) -> { [any]: any },

	_state: { [number]: any, n: number },
	_stateLength: number,
	_running: boolean,
	_name: string,
	_world: Jecs.World,
	_components: { [string]: Jecs.Entity<any> },
	_reporter: typeof(Jabby.scheduler.create("")),
	_collect: (self: Loop<T...>) -> { [any]: any },
}

return {}
