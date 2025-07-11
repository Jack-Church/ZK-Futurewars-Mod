local aimTime = 8*30 -- in frames
local aimTimeMin = 2*30
return { 
	cloaksnipe = {
		name                   = "Phantom",
		description            = "Cloaked Skirmish/Anti-Heavy Artillery Bot",
		acceleration           = 0.9,
		brakeRate              = 1.2,
		buildPic               = "cloaksnipe.png",
		canGuard               = true,
		canMove                = true,
		canPatrol              = true,
		category               = "LAND",
		cloakCost              = 5,
		cloakCostMoving        = 20,
		collisionVolumeOffsets = "0 0 0",
		collisionVolumeScales  = "30 60 30",
		collisionVolumeType    = "cylY",
		selectionVolumeOffsets = "0 0 0",
		selectionVolumeScales  = "68 68 68",
		selectionVolumeType    = "ellipsoid",
		corpse                 = "DEAD",
		customParams           = {
			bait_level_default = 1,
			modelradius    = "15",
			dontfireatradarcommand = '1',
			no_decloak_on_weapon_fire = 1,
			outline_x = 120,
			outline_y = 120,
			outline_yoff = 32.5,
			aimdelay = tostring(aimTime),
		},
		decloakOnFire          = false,
		explodeAs              = "BIG_UNITEX",
		footprintX             = 3,
		footprintZ             = 3,
		health                 = 1200,
		iconType               = "sniper",
		leaveTracks            = true,
		initCloaked            = true,
		maxSlope               = 36,
		maxWaterDepth          = 22,
		metalCost              = 1700,
		minCloakDistance       = 155,
		movementClass          = "KBOT3",
		noChaseCategory        = "TERRAFORM FIXEDWING GUNSHIP SUB",
		objectName             = "sharpshooter.s3o",
		script                 = "cloaksnipe.lua",
		selfDestructAs         = "BIG_UNITEX",
		sfxtypes               = {
			explosiongenerators = {
				"custom:WEAPEXP_PUFF",
				"custom:MISSILE_EXPLOSION",
			},
		},
		sightEmitHeight        = 40,
		sightDistance          = 400,
		speed                  = 42,
		trackOffset            = 0,
		trackStrength          = 8,
		trackStretch           = 1,
		trackType              = "ComTrack",
		trackWidth             = 22,
		turnRate               = 2500,
		upright                = true,
		weapons                = {
			{
				def                = "SHOCKRIFLE",
				badTargetCategory  = "FIXEDWING",
				onlyTargetCategory = "FIXEDWING LAND SINK TURRET SHIP SWIM FLOAT GUNSHIP HOVER",
			},
		},
		weaponDefs             = {
			SHOCKRIFLE = {
				name                    = "X-13 Kinetic Penetrator",
				areaOfEffect            = 16,
				avoidFeature			= false,
				colormap                = "0.43 0.376 0.0667 0.3   0.85 0.7215 0.086 1",
				craterBoost             = 0,
				craterMult              = 0,
				cegtag					= "snipertrail",
				customParams              = {
					reaim_time = 1, -- Keep aiming at target to prevent sideways gun, which can lead to teamkill.
					burst = Shared.BURST_RELIABLE,
					allowedpitcherror = 10,
					allowedheadingerror = 10,
					light_radius = 120,
					shield_disruption = 4*30,
					armorpiercing = 0.10,
					aimdelay = aimTime,
					aimdelay_min = aimTimeMin,
					aimdelay_bonus = 0.25,
					shield_damage = 2400,
					aimdelayresettime = 60,
					groundnoexplode = 1,
				},
				damage                  = {
					default = 1200.01,
				},
				explosionGenerator      = "custom:gauss_hit_m",
				fireTolerance           = 512, -- 2.8 degrees
				impactOnly              = true,
				impulseBoost            = 0,
				impulseFactor           = 0,
				interceptedByShieldType = 1,
				noSelfDamage            = true,
				noExplode				= true,
				range                   = 1400,
				reloadtime              = 0.1,
				rgbColor                = "0.85 0.7215 0.086",
				size                    = 5,
				sizeDecay               = 0,
				soundHit                = "explosion/ex_med5",
				soundStart              = "weapon/cannon/sniper_shot",
				turret                  = true,
				weaponType              = "Cannon",
				weaponVelocity          = 1200,
			},
		},
		featureDefs            = {
			DEAD = {
				blocking         = true,
				featureDead      = "HEAP",
				footprintX       = 2,
				footprintZ       = 2,
				object           = "sharpshooter_dead.s3o",
			},
			HEAP = {
				blocking         = false,
				footprintX       = 2,
				footprintZ       = 2,
				object           = "debris2x2b.s3o",
			},
		},
	}
}
