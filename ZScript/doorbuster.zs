
// DoorBuster class by Agent_Ash aka jekyllgrim

// Call BDP_DoorBuster.DestroyDoor to destroy a door
// in front of the calling actor.
// It's a Thinker because if we decide to spawn some
// extra debris falling from the top of the door,
// it'll initialize itself to handle those.

class BDP_DoorBuster : Thinker
{
	static const color debrisColors[] =
	{
		"1a1a1a",
		"353535",
		"2e2321",
		"24201e",
		"655f5d",
		"462f25"
	};

	// whether it can break locked doors:
	enum ELockBreaking
	{
		LB_None, 		// cannot break locked doors
		LB_CheckKey,	// can break only if has key
		LB_All			// can always break locked doors
	}

	int duration;
	int init_duration;
	Vector2 origin;
	Sector debrisSector;
	Vector2 doorDelta;
	double doorLength;
	double debrisZ;
	int debrisNum;
	class<Actor> debrisType;


	static bool DestroyDoor(
			Actor source, 
			// distance: how far the effect extends. Source's radius is
			// automatically added to this.
			double distance = 64, 
			name newCeilTex = 'BDASHWL', 
			name newFloorTex = '', 
			sound sfx = "world/destroywall", 
			// DebrisDensity: determines the number of debris. For example at 8.0
			// it'll spawn 1 piece of debris per each 8x8 square of the door
			// surface area. Smaller values mean MORE debris, but 0 means "do not
			// spawn". Debris position is still randomized regardless of this.
			double debrisDensity = 8.0, //= 1 piece per each 16x16 square
			class<Actor> debrisType = "WallChunk",
			class<Actor> AfterdebrisType = "WallChunk2",
			// spawnAfter: if true, a separate thinker will keep spawning some debris
			// along the top line of the door, falling down, once it's been destroyed
			bool spawnAfterDebris = true,
			// afterDebrisType: if null, uses particles, otherwise uses this actor class
			class<Actor> afterDebrisType = null,
			// breakLocks: interaction with locks
			ELockBreaking breakLocks = LB_NONE,
			// debug: print debug strings
			bool debug = false
		)
	{
		if (!source)
		{
			if (debug)
			{
				Console.Printf("\cKDestoryDoor:\c- no valid source");
			}
			return false;
		}
		double checkdist = Clamp(distance, source.radius, PLAYERMISSILERANGE);
		Vector2 checkDir = (source.angle, source.pitch);
		double checkz = source.height * 0.5;
		// Adjust vertical offset to match player's aim if source is a player:
		if (source.player)
		{
			let ppawn = PlayerPawn(source.player.mo);
			if (ppawn)
			{
				checkz = ppawn.height * 0.5 - ppawn.floorclip + ppawn.AttackZOffset*ppawn.player.crouchFactor;
			}
		}

		FLineTraceData trac;
		source.LineTrace(checkDir.x, checkdist, checkDir.y, TRF_SOLIDACTORS|TRF_BLOCKUSE|TRF_BLOCKSELF, checkz, source.radius, data: trac);
		// Hit nothing:
		if (!trac.HitLine)
		{
			if (debug)
			{
				Console.Printf("\cKDestoryDoor:\c- couldn't hit a line");
			}
			return false;
		}
		Line l = trac.HitLine;
		if (trac.LineSide != Line.front)
		{
			if (debug)
			{
				Console.Printf("\cKDestoryDoor:\c- hit the back of a line somehow)");
			}
			return false; //somehow we hit the back of a line, abort
		}

		// Detect if a door and if locked:
		int lock = l.locknumber;
		bool isDoor = false;
		switch (l.special)
		{
		case Generic_Door:
			lock = l.Args[4];
			isDoor = true;
			break;
		case Door_LockedRaise:
		case Door_Animated:
			lock = l.Args[3];
			isDoor = true;
			break;
		case Door_Open:
		case Door_Raise:
			isDoor = true;
			break;
		}
		if (!isDoor)
		{
			if (debug)
			{
				Console.Printf("\cKDestoryDoor:\c- this is not a door");
			}
			return false;
		}
		if (lock)
		{
			if (breakLocks == LB_None)
			{
				if (debug)
					Console.Printf("\cKDestoryDoor:\c- hit a locked door but isn't allowed to destroy them");
				return false;
			}
			if (breakLocks == LB_CheckKey && !source.CheckKeys(lock, false, true))
			{
				if (debug)
					Console.Printf("\cKDestoryDoor:\c- hit a locked door but has no key for it");
				return false;
			}
		}

		Sector doorSector = l.backsector;
		if (!doorSector)
		{
			if (debug)
			{
				Console.Printf("\cKDestoryDoor:\c- couldn't obtain the door sector");
			}
			return false;
		}
		if (doorSector.PlaneMoving(Sector.ceiling))
		{
			if (debug)
			{
				Console.Printf("\cKDestoryDoor:\c- door is currently moving, don't bust");
			}
			return false;
		}

		Vector2 checkPos = trac.HitLocation.xy;
		let special = l.special;
		double doorFloorZ = doorSector.floorplane.ZAtPoint(checkPos);
		// The door will only be raised to the lowest neighboring ceiling:
		double nextLowestCeiling = doorSector.FindLowestCeilingSurrounding();
		double doorHeight = nextLowestCeiling - doorFloorZ;
		for (int i = 0; i < doorSector.Lines.Size(); i++)
		{
			Line sl = doorSector.Lines[i];
			if (!sl)
				continue;
			// purge door special from all lines of the doorsector
			// that have it:
			if (sl.special == special)
			{
				sl.special = 0;
			}
			// Offset all top textures attached to the door sector
			// that don't have the Upper Unpegged flag downward,
			// to keep them in place when the sector moves:
			if (sl.flags & Line.ML_DONTPEGTOP)
				continue;
			Side s = sl.sidedef[Line.front];
			if (s)
			{
				s.SetTextureYOffset(Side.top, -doorHeight);
			}
			s = l.sidedef[Line.back];
			if (s)
			{
				s.SetTextureYOffset(Side.top, -doorHeight);
			}
		}

		// move plane:
		doorsector.MoveCeiling(doorHeight, doorsector.ceilingplane.PointToDist(checkpos, nextLowestCeiling), 0, 1, false);
		// modify textures, if necessary:
		if (newFloorTex)
		{
			TextureID tex = TexMan.CheckForTexture(newFloorTex);
			if (tex && tex.isValid())
			{
				doorsector.SetTexture(Sector.floor, tex);
			}
		}
		if (newCeilTex)
		{
			TextureID tex = TexMan.CheckForTexture(newCeilTex);
			if (tex && tex.isValid())
			{
				doorsector.SetTexture(Sector.ceiling, tex);
			}
		}

		if (debug)
		{
			Console.Printf("\cKDestoryDoor:\c- \cDsuccess!\c- Hit an unlocked door (\cd%d\c-) that was \cd%.1f\c- units away.\n"
				"New door sector height: \cd%.1f\c-\n"
				"New textures: %s\n",
				special, 
				trac.Distance, 
				doorSector.ceilingPlane.ZAtPoint(checkPos),
				TexMan.GetName(doorSector.GetTexture(Sector.ceiling))
			);
		}

		if (sfx)
		{
			// Need an actor to play the sound:
			let as = Actor.Spawn("Actor", (l.v1.p + l.delta*0.5, source.pos.z + source.height*0.5));
			if (as)
			{
				as.A_StartSound(sfx);
				as.Destroy();
			}
		}
		if(source)
		{
			Source.A_Quake(5,12,0,800);
		}
		double doorAngle = atan2(l.delta.y, l.delta.x) + 90; 
		double doorLength = l.delta.Length();
		if (debrisDensity > 0)
		{
			FSpawnParticleParams junk;
			class<Actor> debris = debristype;
			double doorArea = doorLength * doorHeight;
			int debrisNum = round((doorArea / (debrisDensity**2)));
			if (debug)
			{
				Console.Printf("\cKDestoryDoor:\c-: Spawning debris. Door area: \cg%d\c- (%dx%d). Debris density: \cd1 per %dx%d\c-. Total debris: \cg%d\c-", doorArea, doorLength, doorHeight, debrisDensity, debrisDensity, debrisNum);
			}
			if (!debristype)
			{
				junk.flags = SPF_ROLL|SPF_REPLACE;
				junk.style = STYLE_Normal;
				junk.startalpha = 1.0;
				junk.accel.z = -Level.Gravity / 800;
			}
			for (int i = debrisNum; i > 0; i--)
			{
				// Offset alongside the line:
				vector3 junk_pos = (l.v1.p + l.delta * frandom[dbp](0.1, 0.9), doorFloorZ + doorHeight * frandom[dbp](0.1, 0.9));
				vector3 junk_vel;
				junk_vel.xy = Actor.RotateVector((15 * (frandom[dbp](0.05, 1.0)), 0), doorAngle + frandom[dbp](-15, 15));
				junk_vel.z = junk.vel.xy.Length() * 0.5;

				if (debris)
				{
					let deb = Actor.Spawn(debris, junk_pos);
					if (deb)
					{
						deb.vel = junk_vel;
					}
				}
				else
				{
					junk.color1 = BDP_DoorBuster.debrisColors[random[dbp](0, BDP_DoorBuster.debrisColors.Size()-1)];
					junk.pos = junk_pos;
					junk.vel = junk_vel;
					junk.lifetime = random[dbp](20, 30);
					junk.size = frandom[dbp](8, 25);
					junk.sizestep = -(junk.size / junk.lifetime);
					junk.rollvel = frandom[dbp](-15, 15);
					Level.SpawnParticle(junk);
				}
			}
		}

		if (spawnAfterDebris && debrisDensity > 0.0)
		{
			if (debug)
				Console.Printf("\cKDestoryDoor:\c-: spawning lingering debris.");
			BDP_DoorBuster.SpawnRemainingDebris(TICRATE * random[gbf](1, 4), doorsector, l.delta, debrisDensity * 10, afterDebrisType);
		}
		
		return true;
	}

	static void SpawnRemainingDebris(int duration, Sector sec, Vector2 doorDelta, double density, class<Actor> debrisType)
	{
		let m = new('BDP_DoorBuster');
		if (m)
		{
			m.duration = duration;
			m.init_duration = duration;
			m.debristype = debristype;
			m.doorDelta = doorDelta;
			m.doorLength = doorDelta.Length();
			m.debrisNum = round(m.doorLength / density);
			m.debrisSector = sec;
			m.origin = sec.centerspot;
			m.debrisZ = sec.ceilingplane.ZAtPoint(m.origin);
		}
	}
	
	override void Tick()
	{
		if (duration <= 0)
		{
			Destroy();
			return;
		}
		if (Level.isFrozen())
		{
			return;
		}

		for (int i = debrisNum; i > 0; i--)
		{
			vector3 junk_pos = (origin, debrisz);
			junk_pos.xy += doorDelta * frandom[dbp](-0.5, 0.5);

			if (debrisType)
			{
				let def = GetDefaultByType(debrisType);
				if (def)
				{
					Actor.Spawn(debrisType, junk_pos - (0,0,def.height));
				}
			}
			else
			{
				FSpawnParticleParams junk;
				junk.flags = SPF_ROLL|SPF_REPLACE;
				junk.style = STYLE_Normal;
				junk.startalpha = 1.0;
				junk.accel.z = -Level.gravity / 800;
				junk.lifetime = random[dbp](20, 35);
				junk.size = frandom[dbp](8, 15);
				junk.sizestep = -(junk.size / junk.lifetime);
				// Offset alongside the line:
				junk.color1 = BDP_DoorBuster.debrisColors[random[dbp](0, BDP_DoorBuster.debrisColors.Size()-1)];
				junk.pos = junk_pos;
				junk.rollvel = frandom[dbp](-8, 8);
				Level.SpawnParticle(junk);
			}
		}
		debrisNum = round(debrisNum * (duration / double(init_duration)));

		duration--;
	}
}

Class WallChunk : Actor
{
	Default
	{
		Scale 0.45;
		Height 2;
		Radius 2;
		+noblockmap;
		bouncefactor 0.20;
		+rollsprite;
		+rollcenter;
		Gravity 0.60;
		+thruactors;
		+MOVEWITHSECTOR;
		+noteleport;
		+forcexybillboard;
	}
	float rollfactor;
	States
	{
	Spawn:
	ContinueSpawn:
		TNT1 A 0 NODELAY
		{
			rollfactor = frandom(-25,25);
		}
		TNT1 A 0 A_JUMP(255,"Spawn1","Spawn2","Spawn3","Spawn4","Spawn5","Spawn6","Spawn7","Spawn8","Spawn9","Spawn10","Spawn11","Spawn12");
	Spawn1:
		WCHN A 0;
		Goto StaySpawned;
	Spawn2:
		WCHN B 0;
		Goto StaySpawned;
	Spawn3:
		WCHN C 0;
		Goto StaySpawned;
	Spawn4:
		WCHN D 0;
		Goto StaySpawned;
	Spawn5:
		WCHN E 0;
		Goto StaySpawned;
	Spawn6:
		WCHN F 0;
		Goto StaySpawned;
	Spawn7:
		WCHN G 0;
		Goto StaySpawned;
	Spawn8:
		WCHN H 0;
		Goto StaySpawned;
	Spawn9:
		WCHN I 0;
		Goto StaySpawned;
	Spawn10:
		WCHN J 0;
		Goto StaySpawned;
	Spawn11:
		WCHN K 0;
		Goto StaySpawned;
	Spawn12:
		WCHN L 0;
		Goto StaySpawned;
	StaySpawned:
		WCHN "#" 1 
		{
			Roll = roll + rollfactor;
		}
		TNT1 "#" 0 A_JumpIf(pos.Z <= floorz, "Floor");
		LOOP;
	Floor:
		WCHN "#" 1;
		LOOP;
		
	}

}


CLASS WallChunk2 : WallChunk
{
	Default
	{
		Mass 500;
	
	}
	States
	{
		Spawn:
			TNT1 A 0 NODELAY
			{
				vel.x = frandom(-0.3,0.3);
				vel.y = frandom(-0.3,0.3);
			}
		Goto ContinueSpawn;
		
		
		
	
	}



}