class MoveTracer : LineTracer
{
	bool bHitPortal;
	bool bHitWater;
	
	void Reset()
	{
		bHitPortal = bHitWater = false;
		results.hitType = TRACE_HitNone;
		results.ffloor = null;
		results.crossedWater = results.crossed3DWater = null;
	}
	
	override ETraceStatus TraceCallback()
    {
		if (results.crossedWater || results.crossed3DWater)
		{
			bHitWater = true;
			results.hitPos = results.crossedWater ? results.crossedWaterPos : results.crossed3DWaterPos;
			return TRACE_Stop;
		}
		
		switch (results.HitType)
		{
			case TRACE_CrossingPortal:
				results.hitType = TRACE_HitNone;
				bHitPortal = true;
				break;
				
			case TRACE_HitWall:
				if (results.tier == TIER_Middle
					&& (results.hitLine.flags & Line.ML_TWOSIDED)
					&& !(results.hitLine.flags & Line.ML_BLOCKEVERYTHING))
				{
					break;
				}
			case TRACE_HitFloor:
			case TRACE_HitCeiling:
				if (results.ffloor
					&& (!(results.ffloor.flags & F3DFloor.FF_EXISTS)
					|| !(results.ffloor.flags & F3DFloor.FF_SOLID)))
				{
					results.ffloor = null;
					break;
				}
				return TRACE_Stop;
				break;
			
			case TRACE_HitActor:
				if (results.hitActor.bSolid
					&& (results.hitActor != players[consoleplayer].camera
					|| (players[consoleplayer].camera == players[consoleplayer].mo && (players[consoleplayer].cheats & CF_CHASECAM))))
					return TRACE_Stop;
				break;
		}
		
		results.distance = 0;
        return TRACE_Skip;
    }
}

class Precipitation : Actor
{
	static const double windTab[] = { 5/32., 10/32., 25/32. };
	const MIN_MAP_UNIT = 1 / 65536.;
	
	private transient MoveTracer moveTracer;
	private bool bKilled;
	
	Default
	{
		FloatBobPhase 0;
		Radius 1;
		Height 2;
		
		+NOBLOCKMAP
		+SYNCHRONIZED
		+WINDTHRUST
		+DONTBLAST
		+NOTONAUTOMAP
	}
	
	override void Tick()
	{
		if (IsFrozen())
			return;
		
		if (bWindThrust)
		{
			int special = CurSector.special;
			switch (special)
			{
				// Wind_East
				case 40:
				case 41:
				case 42: 
					Thrust(windTab[special-40], 0);
					break;
					
				// Wind_North
				case 43:
				case 44:
				case 45: 
					Thrust(windTab[special-43], 90);
					break;
					
				// Wind_South
				case 46:
				case 47:
				case 48: 
					Thrust(windTab[special-46], 270);
					break;
					
				// Wind_West
				case 49:
				case 50:
				case 51: 
					Thrust(windTab[special-49], 180);
					break;
			}
		}
		
		if (!moveTracer)
			moveTracer = new("MoveTracer");
		
		bool bHit;
		if (!(vel ~== (0,0,0)))
		{
			moveTracer.Reset();
			bHit = moveTracer.Trace(pos, CurSector, vel, 1, TRACE_ReportPortals|TRACE_HitSky) || moveTracer.bHitWater;
			if (moveTracer.results.hitType == TRACE_HasHitSky)
			{
				Destroy();
				return;
			}
			
			SetOrigin(moveTracer.results.hitPos - moveTracer.results.hitVector*MIN_MAP_UNIT, true);
			if (moveTracer.bHitPortal)
				vel.xy = RotateVector(vel.xy, DeltaAngle(VectorAngle(vel.x, vel.y), moveTracer.results.srcAngleFromTarget));
			
			if (moveTracer.bHitWater)
				bNoGravity = true;
			
			CheckPortalTransition();
		}
		
		if (!bNoGravity && pos.z > floorz)
			vel.z -= GetGravity();
		
		if (bHit)
		{
			vel = (0,0,0);
			if (!bKilled)
			{
				bKilled = true;
				SetState(FindState("Death"));
				return;
			}
		}
		
		if (!CheckNoDelay())
			return;
		
		if (tics > 0)
			--tics;
		while (!tics)
		{
			if (!SetState(CurState.NextState))
				return;
		}
	}
}