return { 
	tankheavyassault = {
		unitname            = "tankheavyassault",
		name                = "Colossus",
		description         = "Near-Impervious Assault Tank",
		acceleration        = 0.2,
		brakeRate           = 0.624,
		buildCostMetal      = 5500,
		builder             = false,
		buildPic            = "tankheavyassault.png",
		canGuard            = true,
		canMove             = true,
		canPatrol           = true,
		category            = "LAND",
		collisionVolumeOffsets = "0 0 0",
		collisionVolumeScales  = "70 70 100",
		collisionVolumeType    = "cylZ",
		selectionVolumeOffsets = "0 0 0",
		selectionVolumeScales  = "96 96 96",
		selectionVolumeType    = "ellipsoid",
		corpse              = "DEAD",
		customParams        = {
			bait_level_default = 0,
			decloak_footprint  = 5,
			nanoregen = 30,
			nano_maxregen = 20,
			dontfireatradarcommand = '1',
			outline_x = 110,
			outline_y = 110,
			outline_yoff = 13.5,
		},
		explodeAs           = "BIG_UNIT",
		footprintX          = 4,
		footprintZ          = 4,
		iconType            = "tankskirm",
		idleAutoHeal        = 5,
		idleTime            = 1800,
		leaveTracks         = true,
		health              = 38500,
		maxSlope            = 18,
		speed               = 1.5,
		maxWaterDepth       = 22,
		movementClass       = "TANK4",
		noAutoFire          = false,
		noChaseCategory     = "TERRAFORM FIXEDWING SATELLITE GUNSHIP SUB",
		objectName          = "corgol_512.dae",
		script              = "tankheavyassault.lua",
		selfDestructAs      = "BIG_UNIT",
		sfxtypes            = {
			explosiongenerators = {
				"custom:LARGE_MUZZLE_FLASH_FX",
			},
		},
		sightDistance       = 650,
		trackOffset         = 8,
		trackStrength       = 10,
		trackStretch        = 1,
		trackType           = "StdTank",
		trackWidth          = 50,
		turninplace         = 0,
		turnRate            = 400,
		weapons             = {
			{
				def                = "CANNON",
				badTargetCategory  = "FIXEDWING GUNSHIP",
				onlyTargetCategory = "SWIM LAND SINK TURRET FLOAT SHIP HOVER GUNSHIP FIXEDWING",
			},
			{
				def                = "MINIGUN",
				badTargetCategory  = "FIXEDWING UNARMED",
				onlyTargetCategory = "FIXEDWING LAND SINK TURRET SHIP SWIM FLOAT GUNSHIP HOVER",
			},
			{
				def                = "MINIGUN2",
				badTargetCategory  = "FIXEDWING UNARMED",
				onlyTargetCategory = "FIXEDWING LAND SINK TURRET SHIP SWIM FLOAT GUNSHIP HOVER",
			},
		},
		weaponDefs          = {
			CANNON = {
				name                    = "Oblivion Cannon",
				accuracy                = 0,
				areaOfEffect            = 120,
				avoidFeature            = false,
				avoidGround             = true,
				craterBoost             = 10,
				craterMult              = 1.7,
				cegtag                  = "cyclops_plasma_trail",
				damage                  = {
					default = 5200.01,
				},
				explosionGenerator      = "custom:lrpc_expl",
				edgeEffectiveness		= 0.1,
				fireTolerance           = 1820, -- 10 degrees
				impulseBoost            = 2,
				impulseFactor           = 1.3,
				interceptedByShieldType = 1,
				noSelfDamage            = true,
				range                   = 680,
				reloadtime              = 8,
				rgbColor                = "0.615 0.447 0.412",
				soundHit                = "weapon/cannon/supergun_bass_boost",
				soundStart              = "weapon/cannon/behe_fire2",
				size                    = 12,
				turret                  = true,
				weaponType              = "Cannon",
				weaponVelocity          = 1200,
			},
			MINIGUN = {
				name                    = "Hellfire Minigun",
				areaOfEffect            = 100,
				craterBoost             = 0,
				craterMult              = 0,
				cegTag                  = "flamer",
				customParams            = {
					light_camera_height = 2000,
					light_color = "1 0.5 0.2",
					light_radius = 120,
					setunitsonfire = "1",
					hideweapon = 1,
				},
				damage                  = {
					default = 50.1,
				},
				explosionGenerator      = "custom:napalm_tiny",
				fireStarter             = 100,
				flighttime              = 10,
				impulseBoost            = 0,
				impulseFactor           = 0,
				interceptedByShieldType = 1,
				noSelfDamage            = true,
				range                   = 680,
				reloadtime              = 1,
				mygravity               = 0.33,
				rgbColor                = "1 0.5 0.2",
				soundHit				= "flamethrowerhit",
				soundHitVolume          = 2.2,
				soundStart              = "flamethrowerfire",
				soundStartVolume        = 3.5,
				stages                  = 10,
				separation              = 1.5,
				size					= 4.5,
				weaponType              = "Cannon",
				weaponVelocity          = 1000,
			},
			MINIGUN2 = {
				name                    = "Hellfire Minigun (x2) (Manual Fire)",
				areaOfEffect            = 100,
				craterBoost             = 0,
				burst                   = 303,
				burstrate				= 1/30,
				craterMult              = 0,
				cegTag                  = "flamer",
				customParams            = {
					light_camera_height = 2000,
					light_color = "1 0.5 0.2",
					light_radius = 120,
					setunitsonfire = "1",
					stats_custom_tooltip_1 = " - Spreads Over Burst",
					stats_custom_tooltip_entry_1 = "33 degrees/sec",
					stats_custom_tooltip_2 = "   - Max deviation",
					stats_custom_tooltip_entry_2 = "22.5 degrees",
				},
				damage                  = {
					default = 50.1,
				},
				explosionGenerator      = "custom:napalm_phoenix",
				fireStarter             = 100,
				flighttime              = 10,
				impulseBoost            = 0,
				impulseFactor           = 0,
				interceptedByShieldType = 1,
				noSelfDamage            = true,
				range                   = 680,
				reloadtime              = 75,
				mygravity               = 0.33,
				rgbColor                = "1 0.5 0.2",
				soundHit				= "flamethrowerhit",
				soundHitVolume          = 2.2,
				soundStart              = "flamethrowerfire",
				soundStartVolume        = 3.5,
				stages                  = 10,
				separation              = 1.5,
				size					= 4.5,
				weaponType              = "Cannon",
				weaponVelocity          = 1000,
			},
		},
		featureDefs         = {
			DEAD = {
				blocking         = true,
				featureDead      = "HEAP",
				footprintX       = 4,
				footprintZ       = 4,
				object           = "golly_d.s3o",
			},
			HEAP = {
				blocking         = false,
				footprintX       = 4,
				footprintZ       = 4,
				object           = "debris4x4c.s3o",
			},
		},
	}
}
