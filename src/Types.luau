local Jecs = require(script.Parent.Parent.Jecs)

export type World = typeof(Jecs.World.new())
export type Entity<T> = number & {
	__T: T,
}

export type System = { system: () -> (), name: string } | () -> ()

export type Loop<T...> = {
	phases: {
		RenderStepped: Entity<number>,
		Heartbeat: Entity<number>,
		PreSimulation: Entity<number>,
		PreAnimation: Entity<number>,
	},
	phase: (after: Entity<number>) -> Entity<number>,
	schedule: (self: Loop<T...>, system: System, phase: number?) -> System,
	begin: (self: Loop<T...>) -> { [any]: any },
}

return {}
