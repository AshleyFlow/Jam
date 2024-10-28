local Jecs = require(script.Parent.Parent.Jecs)

export type System = { system: () -> () } | () -> ()

export type Loop = {
	phases: {
		RenderStepped: Jecs.Entity<number>,
		Heartbeat: Jecs.Entity<number>,
		PreSimulation: Jecs.Entity<number>,
		PreAnimation: Jecs.Entity<number>,
	},
	phase: (after: Jecs.Entity<number>) -> Jecs.Entity<number>,
	schedule: (self: Loop, system: System, phase: number?) -> System,
	begin: (self: Loop) -> { [any]: any },
}

return {}
