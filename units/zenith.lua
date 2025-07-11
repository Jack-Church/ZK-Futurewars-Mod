local meteor_shared = {
	name                    = "Gigaton Asteroid",
	accuracy                = 700,
	alwaysVisible           = 1,
	areaOfEffect            = 720,
	avoidFriendly           = false,
	avoidFeature            = false,
	avoidGround             = false,
	cegTag                  = "meteorbig_tag",
	collideFriendly         = true,
	craterBoost             = 100,
	craterMult              = 20,
	customParams              = {
		light_color = "2.4 1.5 0.6",
		light_radius = 600,
		script_reload = "10",
		restrict_in_widgets = 1,
		light_camera_height = 3500,
		light_color = "0.75 0.4 0.15",
		light_radius = 220,
		numprojectiles1 = 24,
		projectile1 = "zenith_fragment_dummy",
		velspread1 = "8, 6, 8, _, 18, _",
		noairburst = "March of progress",
		onexplode = "The unity prevails",
	},
	damage                  = {
		default = 14000,
	},
	edgeEffectiveness       = 0.8,
	explosionGenerator      = "custom:big_meteor_smash",
	fireStarter             = 70,
	flightTime              = 3600,
	impulseBoost            = 250,
	impulseFactor           = 0.5,
	interceptedByShieldType = 8, -- Only by rafflesia
	noSelfDamage            = false,
	model                   = "asteroid_big.dae",
	range                   = 420000,
	reloadtime              = 10,
	smokeTrail              = true,
	soundHit                = "weapon/cannon/supergun_bass_boost",
	startVelocity           = 1500,
	textures                = {
		"null",
		"null",
		"null",
	},
	size					= 240,
	turret                  = true,
	turnrate                = 25000,
	weaponAcceleration      = 200,
	weaponType              = "MissileLauncher",
	weaponVelocity          = 1000,
}

local MergeWithDefault = Spring.Utilities.MergeWithDefault

return { 
	zenith = {
		unitname                      = "zenith",
		name                          = "Zenith",
		description                   = "Meteor Controller - Globally Revealed at 95%% completion",
		activateWhenBuilt             = true,
		buildCostMetal                = 64000,
		builder                       = false,
		buildingGroundDecalDecaySpeed = 30,
		buildingGroundDecalSizeX      = 11,
		buildingGroundDecalSizeY      = 11,
		buildingGroundDecalType       = "zenith_aoplane.dds",
		buildPic                      = "zenith.png",
		category                      = "SINK",
		collisionVolumeOffsets        = "0 0 0",
		collisionVolumeScales         = "90 194 90",
		collisionVolumeType           = "cylY",
		corpse                        = "DEAD",
		customParams                  = {
			--keeptooltip = "any string I want",
			neededlink  = 750,
			pylonrange  = 330,
			modelradius    = "45",
			bait_level_default = 0,
			superweapon = 1,
			superweaponcoef    = 0.3,
			reveal_losunit = "los_superwep",
			reveal_onprogress = 0.95,
		},
		energyUse                     = 0,
		explodeAs                     = "SUPERCOOKED",
		fireState                     = 0,
		footprintX                    = 8,
		footprintZ                    = 8,
		iconType                      = "mahlazer",
		idleAutoHeal                  = 5,
		idleTime                      = 1800,
		health                        = 42000,
		maxSlope                      = 18,
		maxWaterDepth                 = 0,
		noChaseCategory               = "FIXEDWING GUNSHIP SUB STUPIDTARGET",
		objectName                    = "zenith.s3o",
		onoffable                     = true,
		script                        = "zenith.lua",
		selfDestructAs                = "SUPERCOOKED",
		sightDistance                 = 660,
		useBuildingGroundDecal        = true,
		workerTime                    = 0,
		yardMap                       = "oooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooooo",
		weapons                       = {
			{
				def                = "METEOR",
				badTargetCateogory = "MOBILE",
				onlyTargetCategory = "SWIM LAND SINK TURRET FLOAT SHIP HOVER GUNSHIP",
			},
			{
				def                = "GRAVITY_NEG",
				onlyTargetCategory = "NONE",
			},
		},
		weaponDefs                    = {
			GRAVITY_NEG = {
				name                    = "Attractive Gravity (fake)",
				alwaysVisible           = 1,
				collideFeature          = false,
				collideFriendly         = false,
				collideEnemy            = false,
				avoidFriendly           = false,
				canAttackGround         = false,
				coreThickness           = 0.5,
				craterBoost             = 0,
				craterMult              = 0,
				customParams            = {
					light_radius = 0,
					script_reload = "10",
					reveal_unit = 20,
					singuimmune = 1,
				},
				damage                  = {
					default = 0.001,
					planes  = 0.001,
				},
				duration                = 0.9,
				explosionGenerator      = "custom:NONE",
				impactOnly              = true,
				impulseBoost            = 0,
				impulseFactor           = 0,
				intensity               = 0.7,
				interceptedByShieldType = 1,
				noSelfDamage            = true,
				noExplode               = true,
				range                   = 420000,
				reloadtime              = 10,
				rgbColor                = "0 0 1",
				rgbColor2               = "1 0.5 1",
				size                    = 32,
				soundStart              = "weapon/gravity_fire",
				soundStartVolume        = 0.6,
				thickness               = 32,
				tolerance               = 5000,
				turret                  = true,
				waterWeapon             = true,
				weaponType              = "LaserCannon",
				weaponVelocity          = 6000,
			},
			FRAGMENT_DUMMY = {
				name                    = "Asteroid Debris",
				accuracy                = 400,
				alwaysVisible           = true,
				areaOfEffect            = 350,
				avoidFeature            = false,
				craterBoost             = 1,
				craterMult              = 2,
				cegTag                  = "meteor_trail",
				customParams              = {
					projectile1 = "zenith_fragment",
					noairburst = "Perkeleen Perkele",
					timeddeploy = 75,
					light_camera_height = 2500,
					light_color = "0.25 0.13 0.05",
					light_radius = 500,
					shield_damage = 2200,
					bogus = 1,
				},
				damage                  = {
					default = 0,
				},
				--explosionGenerator      = "custom:smr_big",
				model                   = "asteroid.s3o",
				firestarter             = 180,
				impulseBoost            = 0,
				impulseFactor           = 0.42,
				interceptedByShieldType = 8, -- Only by rafflesia
				myGravity               = 0.08,
				range                   = 420000,
				reloadtime              = 12,
				rgbColor                = "1 0.5 0.2",
				size                    = 3,
				soundHit                = "nosound",
				soundStart              = "nosound",
				soundStartVolume        = 3.2,
				sprayangle              = 2500,
				turret                  = true,
				waterweapon             = true,
				weaponType              = "Cannon",
				weaponVelocity          = 320,
			},
			FRAGMENT = {
				name                    = "Asteroid Fragment",
				accuracy                = 400,
				alwaysVisible           = true,
				areaOfEffect            = 350,
				avoidFeature            = false,
				craterBoost             = 1,
				craterMult              = 2,
				cegTag                  = "meteor_trail",
				customParams              = {
					light_camera_height = 2500,
					light_color = "0.25 0.13 0.05",
					light_radius = 500,
					armorpiercing = 1,
				},
				damage                  = {
					default = 3280,
				},
				explosionGenerator      = "custom:smr_big",
				model                   = "asteroid.s3o",
				firestarter             = 180,
				impulseBoost            = 0,
				impulseFactor           = 0.42,
				interceptedByShieldType = 8, -- Only by rafflesia
				myGravity               = 0.10,
				range                   = 420000,
				reloadtime              = 12,
				rgbColor                = "1 0.5 0.2",
				size                    = 3,
				soundHit                = "weapon/cannon/supergun_bass_boost", --it's effectively an asteroid, so why not use the asteroid sounds?
				soundStart              = "nosound",
				soundStartVolume        = 3.2,
				sprayangle              = 2500,
				turret                  = true,
				weaponType              = "Cannon",
				weaponVelocity          = 320,
			},
			
			METEOR      = MergeWithDefault(meteor_shared, {
				customParams = {
					cruisealt = 2200,
					cruisedist = 820,
					cruise_nolock = 1,
					cruiserandomradius = 1200,
					cruise_ignoreterrain = "1",
					armorpiercing = 1,
				},
			}, true),
			
			METEOR_AIM  = MergeWithDefault(meteor_shared, {
				startVelocity           = 1500,
				turnRate                = 25000,
				weaponAcceleration      = 600,
				weaponVelocity          = 1200,
			}, true),

			METEOR_FLOAT = MergeWithDefault(meteor_shared, {
				startVelocity           = 1500,
				turnRate                = 6000,
				weaponAcceleration      = 200,
				weaponVelocity          = 300,
				wobble                  = 30000,
			}, true),
			
			METEOR_UNCONTROLLED = MergeWithDefault(meteor_shared, {
				turnrate                = 2000,
				weaponAcceleration      = 50,
				weaponType              = "MissileLauncher",
				weaponVelocity          = 400,
			}, true),
		},
		featureDefs                   = {
			DEAD  = {
				blocking         = true,
				featureDead      = "HEAP",
				footprintX       = 8,
				footprintZ       = 8,
				object           = "zenith_dead.s3o",
				collisionVolumeOffsets = "0 0 0",
				collisionVolumeScales  = "90 194 90",
				collisionVolumeType    = "cylY",
			},
			HEAP  = {
				blocking         = false,
				footprintX       = 3,
				footprintZ       = 3,
				object           = "debris4x4c.s3o",
			},

		},
	} 
}
