class PortalTracer : LineTracer
{
	Line portal;
	
	override ETraceStatus TraceCallback()
    {
		if (results.hitType == TRACE_HitWall
			&& results.hitLine.special == 156 && results.hitLine.args[2] <= 1)
		{
			portal = results.hitLine;
			return TRACE_Stop;
		}
		
        return TRACE_Skip;
    }
}

class Weather : Actor
{
	const FADE_TRANSITION = ceil(TICRATE * 0.125);
	
	private transient PortalTracer pt;
	private int amount;
	private int precipVol;
	private int windVol;
	private int thunderVol;
	
	private int rateTimer;
	private double pVolume;
	
	private double wVolume;
	
	private double lightning;
	private double prevLightning;
	private bool bInFlash;
	private Color prevLightningColor;
	private int lightningColorTimer;
	private int lightningTimer;
	
	private int thunderTimer;
	private double tVolume;
	
	private double fog;
	private double prevFog;
	private bool bFadingOut;
	private Color prevFogColor;
	private int fogColorTimer;
	
	PrecipitationType current;
	
	float weather_amount;
	property weather_amount : weather_amount;
	
	float weather_precip_vol ;
	property weather_precip_vol  : weather_precip_vol ;
	
	float weather_wind_vol;
	property weather_wind_vol : weather_wind_vol;
	
	float weather_thunder_vol;
	property weather_thunder_vol : weather_thunder_vol;
	
	bool weather_no_fog;
	property weather_no_fog : weather_no_fog;
	
	bool weather_no_lightning;
	property weather_no_lightning : weather_no_lightning;
	
	name weather_precipitationtype;
	property weather_precipitationtype : weather_precipitationtype;
	
	Default
	{
		FloatBobPhase 0;
		Radius 0;
		Height 0;
		Tag "Weather Spawner";
		
		+NOBLOCKMAP
		+NOSECTOR
		+SYNCHRONIZED
		+DONTBLAST
		+NOTONAUTOMAP
		
		weather.weather_amount 3;
		weather.weather_precip_vol 1;
		weather.weather_wind_vol 1;
		weather.weather_thunder_vol 1;
		weather.weather_precipitationtype "MaxRain"; 
	}
	
	override void beginplay()
	{
	
		Setprecipitationtype(weather_precipitationtype);
		Super.beginplay();
	}
	
	clearscope Color BlendColors(Color c1, Color c2, double t)
	{
		int c1r, c1g, c1b;
		c1r = (c1 & 0xFF0000) >> 16;
		c1g = (c1 & 0xFF00) >> 8;
		c1b = c1 & 0xFF;
		
		int c2r, c2g, c2b;
		c2r = (c2 & 0xFF0000) >> 16;
		c2g = (c2 & 0xFF00) >> 8;
		c2b = c2 & 0xFF;
		
		int rr, rg, rb;
		rr = int(c1r*(1-t) + c2r*t) << 16;
		rg = int(c1g*(1-t) + c2g*t) << 8;
		rb = c1b*(1-t) + c2b*t;
		
		return Color(0xFF000000 | rr | rg | rb);
	}
	
	clearscope double, Color GetFog(double t = 1) const
	{
		Color fc = 0;
		if ((!current || !current.GetBool("foggy")) && fog > 0)
			fc = prevFogColor;
		else if (current && fogColorTimer >= 0)
		{
			double r = (fogColorTimer + 1-t) / FADE_TRANSITION;
			if (r > 1)
				r = 1;
			
			fc = BlendColors(prevFogColor, current.GetColor("fog"), 1-r);
		}
		else if (current)
			fc = current.GetColor("fog");
		
		return clamp(prevFog,0,1)*(1-t) + clamp(fog,0,1)*t, fc;
	}
	
	clearscope double, Color GetLightning(double t = 1) const
	{
		Color lc = 0;
		if ((!current || !current.GetBool("stormy")) && lightning > 0)
			lc = prevLightningColor;
		else if (current && lightningColorTimer >= 0)
		{
			double r = (lightningColorTimer + 1-t) / FADE_TRANSITION;
			if (r > 1)
				r = 1;
			
			lc = BlendColors(prevLightningColor, current.GetColor("lightning"), 1-r);
		}
		else if (current)
			lc = current.GetColor("lightning");
		
		return clamp(prevLightning,0,1)*(1-t) + clamp(lightning,0,1)*t, lc;
	}
	
	clearscope int InLightningFlash() const
	{
		return bInFlash || lightning > 0;
	}
	
	void Reset(PrecipitationType t = null)
	{
		bool wasFoggy;
		bool wasStormy;
		if (current)
		{
			if (current.GetBool("foggy"))
			{
				wasFoggy = true;
				prevFogColor = current.GetColor("fog");
			}
			
			if (current.GetBool("stormy"))
			{
				wasStormy = true;
				prevLightningColor = current.GetColor("lightning");
			}
		}
		
		current = t;
		if (current)
		{
			if (current.GetBool("stormy"))
			{
				if (thunderTimer <= 0)
					thunderTimer = random[Weather](current.GetTime("minthunder"), current.GetTime("maxthunder"));
				if (lightningTimer <= 0)
					lightningTimer = random[Weather](current.GetTime("minlightning"), current.GetTime("maxlightning"));
				
				if (wasStormy)
					lightningColorTimer = FADE_TRANSITION;
				else
					lightningColorTimer = -1;
			}
			else
			{
				thunderTimer = lightningTimer = 0;
				lightningColorTimer = -1;
			}
			
			if (!current.GetType("precipitation"))
				rateTimer = 0;
			
			if (current.GetBool("foggy") && wasFoggy)
				fogColorTimer = FADE_TRANSITION;
			else
				fogColorTimer = -1;
		}
		else
		{
			rateTimer = thunderTimer = lightningTimer = 0;
			fogColorTimer = lightningColorTimer = -1;
		}
	}
	
	private Vector2 GetCeilingPortalOffset(Sector sec, double z)
	{
		Vector2 ofs;
		if (!sec || !sec.Portals[Sector.ceiling])
			return ofs;
		
		double portz = sec.GetPortalPlaneZ(Sector.ceiling);
		while (sec.Portals[Sector.ceiling] && z > portz)
		{
			ofs += sec.GetPortalDisplacement(Sector.ceiling);
			sec = level.sectorPortals[sec.portals[Sector.ceiling]].mDestination;
			if (!sec)
				break;
			
			portz = sec.GetPortalPlaneZ(Sector.ceiling);
		}
		
		return ofs;
	}
	
	private Vector2, Vector2 VisPortalOffset(Line origin, Line dest, Vector2 dir)
	{
		Vector2 ofs;
		if (!origin || !dest)
			return ofs, dir;
		
		ofs = (dest.v1.p + dest.delta/2) - (origin.v1.p + origin.delta/2);
		
		double angDiff = DeltaAngle(VectorAngle(origin.delta.x,origin.delta.y), VectorAngle(-dest.delta.x,-dest.delta.y));
		dir = RotateVector(dir, angDiff);
		
		return ofs, dir;
	}
	
	private bool, double CheckSky(Sector sec, Vector2 spot, double z)
	{
		bool sky;
		double ceilz;
		
		if (!sec)
			return sky, ceilz;
		
		Sector ceilSec;
		[ceilz, ceilSec] = sec.HighestCeilingAt(spot);
		if (ceilSec.GetTexture(Sector.ceiling) == skyflatnum)
		{
			double top = sec.NextHighestCeilingAt(spot.x, spot.y, z, z+1);
			if (top == ceilz)
				sky = true;
		}
		
		return sky, ceilz;
	}
	
	private bool InLiquid(Sector sec, Vector3 spot)
	{
		if (sec.MoreFlags & Sector.SECMF_UNDERWATER)
			return true;
		else
		{
			let hsec = sec.GetHeightSec();
			if (hsec)
			{
				if ((hsec.MoreFlags & Sector.SECMF_UNDERWATERMASK)
					&& (spot.z < hsec.floorPlane.ZAtPoint(spot.xy)
					|| (!(hsec.MoreFlags & Sector.SECMF_FAKEFLOORONLY) && spot.z > hsec.ceilingPlane.ZAtPoint(spot.xy))))
				{
					return true;
				}
			}
			else
			{
				for (uint i = 0; i < sec.Get3DFloorCount(); ++i)
				{
					let ffloor = sec.Get3DFloor(i);
					if (!(ffloor.flags & F3DFloor.FF_EXISTS)
						|| (ffloor.flags & F3DFloor.FF_SOLID)
						|| !(ffloor.flags & F3DFloor.FF_SWIMMABLE))
					{
						continue;
					}
					
					if (ffloor.top.ZAtPoint(spot.xy) > spot.z && ffloor.bottom.ZAtPoint(spot.xy) <= spot.z)
						return true;
				}
			}
		}
		
		return false;
	}
	
	private bool In3DFloor(Sector sec, Vector3 spot)
	{
		for (uint i = 0; i < sec.Get3DFloorCount(); ++i)
		{
			let ffloor = sec.Get3DFloor(i);
			if (!(ffloor.flags & F3DFloor.FF_EXISTS) || !(ffloor.flags & F3DFloor.FF_SOLID))
				continue;
			
			if (ffloor.top.ZAtPoint(spot.xy) >= spot.z && ffloor.bottom.ZAtPoint(spot.xy) < spot.z)
				return true;
		}
		
		return false;
	}
	
	void SpawnPrecipitation(Actor origin, class<Precipitation> precip, Vector2 dir, double dist, double z, bool outdoors = true, bool indoors = false)
	{
		if (!origin || !precip)
			return;
		
		if (dist < 0)
			dist = 0;
		
		bool skyCheck;
		double ceilz;
		Sector sec;
		
		Vector2 xyOfs = dir * dist;
		Vector2 spawnSpot = origin.pos.xy + xyOfs;
		Vector2 portalSpot = origin.Vec2Offset(xyOfs.x, xyOfs.y);
		
		// Did we enter a portal? If so, spawn some precipitation in it
		if (portalSpot != spawnSpot)
		{
			sec = level.PointInSector(portalSpot);
			[skyCheck, ceilz] = CheckSky(sec, portalSpot, z);
			if ((outdoors && skyCheck) || (indoors && !skyCheck))
			{	
				Vector3 spawnPos = (portalSpot+GetCeilingPortalOffset(sec,z), min(z,ceilz));
				sec = level.PointInSector(spawnPos.xy);
				if (level.IsPointInLevel(spawnPos) && !InLiquid(sec, spawnPos) && !In3DFloor(sec, spawnPos))
				{
					Spawn(precip, spawnPos, ALLOW_REPLACE);
					
					// Shift the position a little
					dist *= frandom[Weather](0.8,1.2);
					dir = RotateVector(dir, frandom[Weather](-10,10));
					xyOfs = dir * dist;
				}
			}
		}
		
		if (!pt)
			pt = new("PortalTracer");
		
		// If we hit a visual only portal, get the offsets to the location it's looking at
		Vector2 visOfs;
		pt.portal = null;
		pt.Trace((origin.pos.xy,-32768), origin.CurSector, (dir,0), dist, 0);
		if (pt.portal)
			[visOfs, xyOfs] = VisPortalOffset(pt.portal, pt.portal.GetPortalDestination(), xyOfs);
		
		// Now that we've accounted for portals, spawn it regularly
		spawnSpot = origin.pos.xy + xyOfs + visOfs;
		sec = level.PointInSector(spawnSpot);
		
		// Is there sky at the very top?
		[skyCheck, ceilz] = CheckSky(sec, spawnSpot, z);
		if ((!outdoors && skyCheck) || (!indoors && !skyCheck))
		{
			if (!origin.CurSector.Portals[Sector.ceiling])
				return;
			
			// If not, maybe the portal above the player leads to a valid area?
			spawnSpot += GetCeilingPortalOffset(origin.CurSector,z);
			sec = level.PointInSector(spawnSpot);
			[skyCheck, ceilz] = CheckSky(sec, spawnSpot, z);
			if ((!outdoors && skyCheck) || (!indoors && !skyCheck))
				return;
		}
		
		Vector3 spawnPos = (spawnSpot+GetCeilingPortalOffset(sec,z), min(z,ceilz));
		sec = level.PointInSector(spawnPos.xy);
		if (!level.IsPointInLevel(spawnPos) || InLiquid(sec, spawnPos) || In3DFloor(sec, spawnPos))
			return;
				
		Spawn(precip, spawnPos, ALLOW_REPLACE);
	}
	
	bool InFade(string type, bool sky)
	{
		bool onlyIndoors = current.GetBool(String.Format("%sonlyindoors", type));
		return (!sky && !onlyIndoors && !current.GetBool(String.Format("%sindoors", type))) || (sky && onlyIndoors);
	}
	
	override void Tick()
	{
		master = players[consoleplayer].camera;
		if (!master)
			return;
		
		bool sky = master.ceilingpic == skyflatnum;
		
		// Fog
		prevFog = fog;
		if (fogColorTimer >= 0)
			--fogColorTimer;
		
		if (current && current.GetBool("foggy"))
		{
			bFadingOut = InFade("fog", sky);
			
			double a = current.GetAlpha("fog");
			if (fog > a)
			{
				fog -= 0.01;
				if (fog < a)
					fog = a;
			}
			else if (bFadingOut)
			{
				int fade = current.GetTime("fogfadeout");
				if (fade <= 0)
					fog = 0;
				else if (fog > 0)
				{
					fog -= a / fade;
					if (fog < 0)
						fog = 0;
				}
			}
			else if (fog < a)
			{
				int fade = current.GetTime("fogfadein");
				if (fade <= 0)
					fog = a;
				else
				{
					fog += a / fade;
					if (fog > a)
						fog = a;
				}
			}
		}
		else if (fog > 0)
		{
			fog -= 0.01;
			if (fog < 0)
				fog = 0;
		}
		
		// Cache sounds
		sound precip;
		sound wind;
		sound thunder;
		if (current)
		{
			precip = current.GetSound("precipitation");
			wind = current.GetSound("wind");
			thunder = current.GetSound("thunder");
		}
		
		// Storm
		prevLightning = lightning;
		if (lightningColorTimer >= 0)
			--lightningColorTimer;
		
		bool stormy = current && current.GetBool("stormy");
		if (stormy)
		{
			--thunderTimer;
			if (thunderTimer <= 0)
			{
				thunderTimer = random[Weather](current.GetTime("minthunder"), current.GetTime("maxthunder"));
				A_StartSound(thunder, CHAN_7, CHANF_OVERLAP, 1, ATTN_NONE);
			}
			
			if (!InFade("lightning", sky) && !IsFrozen())
			{
				--lightningTimer;
				if (lightningTimer <= 0)
				{
					lightningTimer = random[Weather](current.GetTime("minlightning"), current.GetTime("maxlightning"));
					bInFlash = true;
				}
			}
		}
		
		bInFlash = stormy && bInFlash;
		if (bInFlash)
		{
			int fade = current.GetTime("lightningfadein");
			double a = current.GetAlpha("lightning");
			if (fade <= 0)
				lightning = a;
			else if (lightning < a)
				lightning += a / fade;
			
			if (lightning >= a)
			{
				lightning = a;
				bInFlash = false;
			}
		}
		else if (lightning > 0)
		{
			int fade = stormy ? current.GetTime("lightningfadeout") : 3;
			double a = stormy ? current.GetAlpha("lightning") : 0.1;
			if (fade <= 0)
				lightning = 0;
			else
			{
				lightning -= a / fade;
				if (lightning < 0)
					lightning = 0;
			}
		}
		
		// Audio
		A_StartSound(precip, CHAN_5, CHANF_LOOPING, 1, ATTN_NONE);
		A_StartSound(wind, CHAN_6, CHANF_LOOPING, 1, ATTN_NONE);
		
		if (current && precip)
			pVolume = CalculateVolume(pVolume, current.GetVolume("minprecipitation"), current.GetVolume("maxprecipitation"), InFade("precipitation", sky), current.GetTime("precipitationvolumefadein"), current.GetTime("precipitationvolumefadeout"));
		else
		{
			pVolume = CalculateVolume(pVolume, 0, 1, true, TICRATE, TICRATE);
			if (pVolume <= 0)
				A_StopSound(CHAN_5);
		}
		
		if (current && wind)
			wVolume = CalculateVolume(wVolume, current.GetVolume("minwind"), current.GetVolume("maxwind"), InFade("wind", sky), current.GetTime("windvolumefadein"), current.GetTime("windvolumefadeout"));
		else
		{
			wVolume = CalculateVolume(wVolume, 0, 1, true, TICRATE, TICRATE);
			if (wVolume <= 0)
				A_StopSound(CHAN_6);
		}
		
		if (current && thunder)
			tVolume = CalculateVolume(tVolume, current.GetVolume("minthunder"), current.GetTime("maxthunder"), InFade("thunder", sky), current.GetTime("thundervolumefadein"), current.GetTime("thundervolumefadeout"));
		else
		{
			tVolume = CalculateVolume(tVolume, 0, 1, true, TICRATE, TICRATE);
			if (tVolume <= 0)
				A_StopSound(CHAN_7);
		}
		
		if (!precipVol)
			precipVol = weather_precip_vol;
		if (!windVol)
			windVol = weather_wind_vol;
		if (!thunderVol)
			thunderVol = weather_thunder_vol;
		
		A_SoundVolume(CHAN_5, pVolume * clamp(precipVol, 0, 1));
		A_SoundVolume(CHAN_6, wVolume * clamp(windVol, 0, 1));
		A_SoundVolume(CHAN_7, tVolume * clamp(thunderVol, 0, 1));
		
		if (!current)
			return;
		
		// Precipitation
		if (!amount)
			amount = weather_amount;
		
		double multi = min(4, amount);
		if (multi <= 0 || IsFrozen())
			return;
		
		let type = current.GetType("precipitation");
		if (type && ++rateTimer >= current.GetTime("precipitationrate"))
		{
			rateTimer = 0;
			
			double z = master.pos.z + current.GetFloat("precipitationheight");
			double xy = current.GetFloat("precipitationradius");
			double minXY = master == players[consoleplayer].mo && (players[consoleplayer].cheats & CF_CHASECAM) ? 0 : 8;
			bool only = current.GetBool("precipitationonlyindoors");
			bool inside = only || current.GetBool("precipitationindoors");
			int amt = ceil(current.GetInt("precipitationamount") * multi);
			for (int i = 0; i < amt; ++i)
			{
				Vector2 dir = AngleToVector(frandom[Weather](0,360));
				double dist = frandom[Weather](minXY,xy);
				
				SpawnPrecipitation(master, type, dir, dist, z, !only, inside);
			}
		}
	}
	
	double CalculateVolume(double v, double mi, double ma, bool fadeOut, int fis, int fos)
	{
		v = clamp(v, 0, 1);
		
		if (fadeOut)
		{
			if (v > mi)
			{
				if (fos <= 0)
					v = mi;
				else
				{
					double diff = ma - mi;
					if (diff <= 0)
						diff = 1;
					
					v -= diff / fos;
					if (v < mi)
						v = mi;
				}
			}
			else if (v < mi)
			{
				v += 1. / TICRATE;
				if (v > mi)
					v = mi;
			}
		}
		else 
		{
			if (v < ma)
			{
				if (fis <= 0)
					v = ma;
				else
				{
					double diff = ma - mi;
					if (diff <= 0)
						diff = 1;
					
					v += diff / fis;
					if (v > ma)
						v = ma;
				}
			}
			else if (v > ma)
			{
				v -= 1. / TICRATE;
				if (v < ma)
					v = ma;
			}
		}
		
		return v;
	}
	
	// General helpers and ACS ScriptCall functionality
	
	static Weather Get()
	{
		ThinkerIterator it = ThinkerIterator.Create("Weather", Thinker.STAT_DEFAULT);
		return Weather(it.Next());
	}
	
	static PrecipitationType GetPrecipitationType(string name)
	{
		let wh = WeatherHandler(StaticEventHandler.Find("WeatherHandler"));
		if (!wh)
			return null;
		
		return wh.Find(name);
	}
	
	static void SetPrecipitationType(string name)
	{
		let wthr = Weather.Get();
		if (wthr)
			wthr.Reset(Weather.GetPrecipitationType(name));
	}
	
	static string GetPrecipitationTypeName()
	{
		string n = "";
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			n = wthr.current.GetName();
		
		return n;
	}
	
	static string GetPrecipitationTypeTag()
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return "";
		
		string t = wthr.current.GetLocalizedString("precipitationtag");
		if (t == "")
			t = wthr.current.GetName();
		
		return t;
	}
	
	static void SetPrecipitationTypeTag(string t)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetValue("precipitationtag", t);
	}
	
	static void SetPrecipitationTypeDefaults()
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetDefaults();
	}
	
	static void ResetPrecipitationType()
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.Reset();
	}
	
	static void SetPrecipitationClass(string cls)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetValue("precipitationtype", cls);
	}
	
	static void SetPrecipitationProperties(double rate = -1, int amt = -1, double rad = -1, double h = -1, int indoors = -1, int indoorsOnly = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (rate >= 0)
			wthr.current.SetFloat("precipitationratetime", rate);
		if (amt >= 0)
			wthr.current.SetInt("precipitationamount", amt);
		if (rad >= 0)
			wthr.current.SetFloat("precipitationradius", rad);
		if (h >= 0)
			wthr.current.SetFloat("precipitationheight", h);
		if (indoors >= 0)
			wthr.current.SetBool("precipitationindoors", !!indoors);
		if (indoorsOnly >= 0)
			wthr.current.SetBool("precipitationonlyindoors", !!indoorsOnly);
	}
	
	static void SetPrecipitationSound(string s)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetValue("precipitationsound", s);
	}
	
	static void SetPrecipitationVolume(double mi = -1, double ma = -1, double fadeIn = -1, double fadeOut = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (mi >= 0)
			wthr.current.SetFloat("minprecipitationvolume", mi);
		if (ma >= 0)
			wthr.current.SetFloat("maxprecipitationvolume", ma);
		if (fadeIn >= 0)
			wthr.current.SetFloat("precipitationvolumefadeintime", fadeIn);
		if (fadeOut >= 0)
			wthr.current.SetFloat("precipitationvolumefadeouttime", fadeOut);
	}
	
	static void SetWindProperties(int indoors = -1, int indoorsOnly = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (indoors >= 0)
			wthr.current.SetBool("windindoors", !!indoors);
		if (indoorsOnly >= 0)
			wthr.current.SetBool("windonlyindoors", !!indoorsOnly);
	}
	
	static void SetWindSound(string s)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetValue("windsound", s);
	}
	
	static void SetWindVolume(double mi = -1, double ma = -1, double fadeIn = -1, double fadeOut = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (mi >= 0)
			wthr.current.SetFloat("minwindvolume", mi);
		if (ma >= 0)
			wthr.current.SetFloat("maxwindvolume", ma);
		if (fadeIn >= 0)
			wthr.current.SetFloat("windvolumefadeintime", fadeIn);
		if (fadeOut >= 0)
			wthr.current.SetFloat("windvolumefadeouttime", fadeOut);
	}
	
	static void ToggleStorm(bool enabled)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetBool("stormy", enabled);
	}
	
	static void SetThunderInterval(double mi = -1, double ma = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (mi >= 0)
			wthr.current.SetFloat("minthundertime", mi);
		if (ma >= 0)
			wthr.current.SetFloat("maxthundertime", ma);
	}
	
	static void SetThunderProperties(int indoors = -1, int indoorsOnly = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (indoors >= 0)
			wthr.current.SetBool("thunderindoors", !!indoors);
		if (indoorsOnly >= 0)
			wthr.current.SetBool("thunderonlyindoors", !!indoorsOnly);
	}
	
	static void SetThunderSound(string s)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetValue("thundersound", s);
	}
	
	static void SetThunderVolume(double mi = -1, double ma = -1, double fadeIn = -1, double fadeOut = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (mi >= 0)
			wthr.current.SetFloat("minthundervolume", mi);
		if (ma >= 0)
			wthr.current.SetFloat("maxthundervolume", ma);
		if (fadeIn >= 0)
			wthr.current.SetFloat("thundervolumefadeintime", fadeIn);
		if (fadeOut >= 0)
			wthr.current.SetFloat("thundervolumefadeouttime", fadeOut);
	}
	
	static void SetLightningInterval(double mi = -1, double ma = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (mi >= 0)
			wthr.current.SetFloat("minlightningtime", mi);
		if (ma >= 0)
			wthr.current.SetFloat("maxlightningtime", ma);
	}
	
	static void SetLightningProperties(double a = -1, int col = -1, double fadeIn = -1, double fadeOut = -1, int indoors = -1, int indoorsOnly = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (a >= 0)
			wthr.current.SetFloat("lightningalpha", a);
		if (col >= 0)
			wthr.current.SetInt("lightningcolor", col);
		if (fadeIn >= 0)
			wthr.current.SetFloat("lightningfadeintime", fadeIn);
		if (fadeOut >= 0)
			wthr.current.SetFloat("lightningfadeouttime", fadeOut);
		if (indoors >= 0)
			wthr.current.SetBool("lightningindoors", !!indoors);
		if (indoorsOnly >= 0)
			wthr.current.SetBool("lightningonlyindoors", !!indoorsOnly);
	}
	
	static void ToggleFog(bool enabled)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			wthr.current.SetBool("foggy", enabled);
	}
	
	static void SetFogProperties(double a = -1, int col = -1, double fadeIn = -1, double fadeOut = -1, int indoors = -1, int indoorsOnly = -1)
	{
		let wthr = Weather.Get();
		if (!wthr || !wthr.current)
			return;
		
		if (a >= 0)
			wthr.current.SetFloat("fogalpha", a);
		if (col >= 0)
			wthr.current.SetInt("fogcolor", col);
		if (fadeIn >= 0)
			wthr.current.SetFloat("fogfadeintime", fadeIn);
		if (fadeOut >= 0)
			wthr.current.SetFloat("fogfadeouttime", fadeOut);
		if (indoors >= 0)
			wthr.current.SetBool("fogindoors", !!indoors);
		if (indoorsOnly >= 0)
			wthr.current.SetBool("fogonlyindoors", !!indoorsOnly);
	}
	
	static string GetStringProperty(string k, bool localized = false)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return localized ? wthr.current.GetLocalizedString(k) : wthr.current.GetValue(k);
		
		return "";
	}
	
	static bool GetBoolProperty(string k)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return wthr.current.GetBool(k);
		
		return false;
	}
	
	static int GetIntProperty(string k)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return wthr.current.GetInt(k);
		
		return 0;
	}
	
	static double GetFloatProperty(string k)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return wthr.current.GetFloat(k);
		
		return 0;
	}
	
	static string GetDefaultStringProperty(string k, bool localized = false)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return localized ? wthr.current.GetDefaultLocalizedString(k) : wthr.current.GetDefaultValue(k);
		
		return "";
	}
	
	static bool GetDefaultBoolProperty(string k)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return wthr.current.GetDefaultBool(k);
		
		return false;
	}
	
	static int GetDefaultIntProperty(string k)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return wthr.current.GetDefaultInt(k);
		
		return 0;
	}
	
	static double GetDefaultFloatProperty(string k)
	{
		let wthr = Weather.Get();
		if (wthr && wthr.current)
			return wthr.current.GetDefaultFloat(k);
		
		return 0;
	}
}