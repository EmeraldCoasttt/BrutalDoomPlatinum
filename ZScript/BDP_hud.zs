// This HUD is based on DoomStatusBar to have access to the vanilla
// statusbar in statusbar mode, while redrawing everything in
// fullscreen mode:
class BDP_HUD : DoomStatusBar
{
	HUDFont mIndexfnt;
	HUDFont mSmallFont;
	HUDFont mSmallFontNS;
	HUDFont mConfont;
	HUDFont mDiginumber;

	static clearscope double LinearMap(double val, double source_min, double source_max, double out_min, double out_max) 
	{
		return (val - source_min) * (out_max - out_min) / (source_max - source_min) + out_min;
	}
	
	override void Init()
	{
		super.Init();
		// non-monospaced Indexfont:
		Font fnt = "INDEXFONT_DOOM";
		mIndexfnt = HUDFont.Create(fnt, 1, false);
		// Smallfont with shadow:
		fnt = "SMALLFONT";
		mSmallFont = HUDFont.Create(fnt, 0, false, 1, 1);
		// Smallfont without shadow:
		mSmallFontNS = HUDFont.Create(fnt, 0, false);
		// Confont:
		fnt = "CONFONT";
		mConfont = HUDFont.Create(fnt, 0, false, 0, 1);
		// BD numeric font (monospaced):
		fnt = "DIGINUMBER";
		mDiginumber = HUDFont.Create(fnt, fnt.GetCharWidth("0"), true);
	}
	
	override void Draw (int state, double TicFrac)
	{
		// Call only the BaseStatusBar's super.Draw() because
		// we don't want DoomStatusBar's Draw() (it'd override
		// our fullscreen stuff):
		BaseStatusBar.Draw (state, TicFrac);

		// In statusbar mode, draw vanilla statusbar,
		// then draw our extra stuff:
		if (state == HUD_StatusBar)
		{
			BeginStatusBar();
			DrawMainBar (TicFrac);
			DrawExtraStatusbarStuff();
			// in statusbar mode powerup indicators are drawn
			// at the bottom right, above the statusbar:
			DrawFullscreenPowerups((290, 158));		
			// I have to duplicate this here because otherwise
			// it'll be blocked by the 'Mag' image:
			if (isInventoryBarVisible())
			{
				DrawInventoryBarEx(diparms, (48, 169), 7, DI_ITEM_LEFT_TOP);
			}
		}
		
		// Fullscreen mode is fully custom:
		else if (state == HUD_Fullscreen)
		{
			BeginHUD();
			DrawLeftCorner();
			DrawRightcorner();
			DrawTopRight(mSmallFontNS, (-4, 1));
			DrawFullscreenPowerups((0, -11), DI_SCREEN_CENTER_BOTTOM);
			if (isInventoryBarVisible())
			{
				DrawInventoryBarEx(diparms, (-20, 150), 6, flags: DI_SCREEN_RIGHT_TOP, box: (20,20), vertical: true);
			}
		}
	}
	
	override void Tick()
	{
		super.Tick();
		int stamina = CPlayer.mo.CountInv("UsedStamina");
		if (stamina > 0)
		{
			stambarFadeTime = Clamp(stambarFadeTime + 1, 0, STAMFADEWAIT);
		}
		else
		{
			stambarFadeTime = Clamp(stambarFadeTime - 1, 0, STAMFADEWAIT);
		}
	}
	
	// This is more or less directly converted from SBARINFO,
	// since we can safely use explicit fullscreen offsets
	// in statusbar mode:
	void DrawExtraStatusbarStuff()
	{		
		if (CPlayer.mo.FindInventory("PowerStrength", true))
		{
			name pwr = CPlayer.mo.FindInventory("NoFatality") ? 'HASBERK2' : 'HASBERK';
			DrawImage(pwr, (143, 169), DI_ITEM_LEFT_TOP);
		}
		
		if (CPlayer.mo.FindInventory("PowerShield", true))
		{
			DrawImage("HASARMR", (179, 169), DI_ITEM_LEFT_TOP);
		}
		
		DrawGrenadeIndicator(mIndexfnt, (334, 194), box: (22,22));
		
		// Mag:
		DrawImage("STARMS", (104,168), DI_ITEM_LEFT_TOP);
		
		Ammo ammo1, ammo2;
		int ammo1amt, ammo2amt;
		[ammo1, ammo2, ammo1amt, ammo2amt] = GetCurrentAmmo();
		
		if (ammo2)
		{
			DrawString(
				mDiginumber, 
				String.Format("%d", ammo2amt), 
				(122, 173),
				DI_TEXT_ALIGN_CENTER|DI_NOSHADOW
			);
		}
		
		DrawStaminaBar((106, 166));
	}
	
	// Draws grenade indicator. Returns false if for some reason
	// the pointer to the grenade item wasn't obtained:
	bool DrawGrenadeIndicator(HUDFont fnt, vector2 pos, int flags = 0, vector2 box = (-1,-1))
	{
		let gammo = CPlayer.mo.FindInventory("GrenadeAmmo");
		if (gammo)
		{
			string nade = "";
			// Pick the grenade icon based on the amount of
			// NadeType in inventory:
			int nadeAmt = (CPlayer.mo.CountInv("NadeType"));
			switch (nadeAmt)
			{
			case 3:
				nade = "GRNDC"; break;
			case 2:
				nade = "PIPBE"; break;
			case 1:
				nade = "GRNDB"; break;
			case 0:
				nade = "GRNDA"; break;
			}
			if (nade)
			{
				DrawImage(nade, pos, flags, box: box);
				DrawString(fnt, String.Format("%d", gammo.amount), pos + (box.x / 2, -4), flags|DI_TEXT_ALIGN_RIGHT);
				return true;
			}
		}
		return false;
	}

	// For whatever reason the base DrawInventoryBar() in Zscript behaves differently
	// from its SBARINFO analog, and is also generally less flexible.
	// This is a copy of the function from statusbarcore but with the following
	// additions:
	// - automatically scales the icon to box if scaleToBox is true
	// - allows explicitly specifying the box, bypassing the boxsize defined in the parms struct
	// - centers the icon in the box (more or less... couldn't get it to work perfectly)
	void DrawInventoryBarEx(InventoryBarState parms, Vector2 position, int numfields, int flags = 0, double bgalpha = 1., bool scaleToBox = true, vector2 box = (-1,-1), bool vertical = false) 
	{
		vector2 boxsize = (box.x == -1 && box.y == -1) ? parms.boxsize : box;
		double width = vertical ? boxsize.X : boxsize.X * numfields;
		double height = vertical ? boxsize.Y * numfields : boxsize.Y;
		
		[position, flags] = AdjustPosition(position, flags, width, height);
		
		CPlayer.mo.InvFirst = ValidateInvFirst(numfields);
		if (CPlayer.mo.InvFirst == null) return;	// Player has no listed inventory items.
		
		Vector2 boxscale = scaleToBox ? boxsize : (-1, -1);
		vector2 ofsStep = vertical ? (0, boxsize.y) : (boxsize.x, 0);
		
		// First draw all the boxes
		for(int i = 0; i < numfields; i++) 
		{
			DrawTexture(parms.box, position + (ofsStep * i), flags | DI_ITEM_LEFT_TOP, bgalpha, boxsize);
		}
		
		// now the items and the rest
		
		Vector2 itempos = position + (boxsize.x / 2, boxsize.y / 4);
		Vector2 textpos = position + boxsize - (1, 1 + parms.amountfont.mFont.GetHeight());

		int i = 0;
		Inventory item;
		for(item = CPlayer.mo.InvFirst; item != NULL && i < numfields; item = item.NextInv()) 
		{
			for(int j = 0; j < 2; j++) 
			{
				if (j ^ !!(flags & DI_DRAWCURSORFIRST)) 
				{
					if (item == CPlayer.mo.InvSel) 
					{
						double flashAlpha = bgalpha;
						if (flags & DI_ARTIFLASH) flashAlpha *= itemflashFade;
						DrawTexture(parms.selector, position + parms.selectofs + (ofsStep * i), flags | DI_ITEM_LEFT_TOP, flashAlpha, boxscale);
					}
				}
				else 
				{
					DrawInventoryIcon(item, itempos + (ofsStep * i), flags | DI_ITEM_CENTER | DI_DIMDEPLETED, boxsize: boxscale);
				}
			}
			
			if (parms.amountfont != null && (item.Amount > 1 || (flags & DI_ALWAYSSHOWCOUNTERS))) 
			{
				DrawString(parms.amountfont, FormatNumber(item.Amount, 0, 5), textpos + (ofsStep * i), flags | DI_TEXT_ALIGN_RIGHT, parms.cr, parms.itemalpha);
			}
			i++;
		}
		// Is there something to the left/above?
		if (CPlayer.mo.FirstInv() != CPlayer.mo.InvFirst) 
		{
			DrawTexture(parms.left, position + (-parms.arrowoffset.X, parms.arrowoffset.Y), flags | DI_ITEM_CENTER, box: boxscale);
		}
		// Is there something to the right/below?
		if (item != NULL) 
		{
			DrawTexture(parms.right, position + parms.arrowoffset + (width, 0), flags | DI_ITEM_CENTER, box: boxscale);
		}
	}
	
	// Equivalent to a SBARINFO function
	void DrawSelectedInventory(vector2 pos, int flags = 0)
	{
		let invsel = CPlayer.mo.InvSel;
		if (invsel)
		{
			vector2 box = (46,46);
			DrawInventoryIcon(invsel, pos, flags, boxsize:box);
			if (invsel.amount > 1)
			{
				DrawString(mIndexfnt, String.Format("%d",invsel.amount), pos + (box.x / 2, -4), DI_TEXT_ALIGN_RIGHT|flags);
			}
		}
	}
	
	// Armor's absorpotion is printed separately from amount in this HUD,
	// and the color of that number matches absorption:
	int GetArmorAbsorbColor(BasicArmor armor)
	{
		if (!armor)
			return Font.CR_UNTRANSLATED;
		
		// PowerShield forces 100% absorption for the current armor
		// and gets its own color:
		if (CPlayer.mo.CountInv("PowerShield"))
			return Font.CR_Cyan;
		
		double sp = armor.savepercent;
		// Demo armor (66% absorb):
		if (sp >= 0.66)
			return Font.CR_Red;
		
		// Blue armor:
		if (sp >= 0.5)
			return Font.CR_Blue;
		
		// Green armor:
		return Font.CR_Green;
	}
	
	// The remaining armor amount color doesn't match armor type,
	// in contrast to Doom, since that is handled by absorpotion number.
	// This number simply changes color based on the amount:
	int GetArmorAmountColor(int amount)
	{
		if (amount > 100)
			return Font.CR_Blue;
		
		if (amount > 10)
			return Font.CR_Green;
		
		return Font.CR_Yellow;
	}
	
	int GetHealthColor(int health)
	{
		/*int hmax = CPlayer.mo.GetMaxHealth(true);
		int health = CPlayer.health;
		if (health <= (hmax * 0.25))
			return Font.CR_Red;
		return Font.CR_Green;*/
		
		if (health > 70)
			return Font.CR_Green;
		
		if (health > 40)
			return Font.CR_Yellow;
		
		return Font.CR_Red;
	}
	
	// Returns the icon or the spawn sprite of the key
	// as a textureID:
	protected TextureID GetKeyTexture(Key inv) 
	{		
		TextureID icon;	
		if (!inv) 
			return icon;
			
		TextureID AltIcon = inv.AltHUDIcon;
		if (!AltIcon.Exists()) 
			return icon;	// Setting a non-existent AltIcon hides this key.

		if (AltIcon.isValid()) 
			icon = AltIcon;
		else if (inv.SpawnState && inv.SpawnState.sprite) 
		{
			let state = inv.SpawnState;
			if (state) 
				icon = state.GetSpriteTexture(0);
			else 
				icon.SetNull();
		}
		// missing sprites map to TNT1A0. So if that gets encountered, use the default icon instead.
		if (icon.isNull() || TexMan.GetName(icon) == 'tnt1a0') 
			icon = inv.Icon; 

		return icon;
	}
	
	void DrawKeys(vector2 pos, int flags = 0, vector2 box = (-1,-1)) 
	{	
		int hofs = 1;
		vector2 iconpos = pos;
		
		int count = Key.GetKeyTypeCount();			
		for(int i = 0; i < count; i++)
		{
			Key inv = Key(CPlayer.mo.FindInventory(Key.GetKeyType(i)));
			TextureID icon = GetKeyTexture(inv);
			if (icon.IsNull()) 
				continue;
			
			vector2 iconsize;
			if (box.x == -1 && box.y == -1)
				iconsize = TexMan.GetScaledSize(icon);
			else
				iconsize = box;
			DrawTexture(icon, iconpos, flags, box: box);
			iconpos.x += (iconsize.x + hofs);
		}
	}
	
	void DrawLeftCorner(vector2 basePos = (28, -11))
	{
		// Elements are placed relative to screen bottom left
		// and anchored at their center:
		int iconflags = DI_SCREEN_LEFT_BOTTOM|DI_ITEM_CENTER_BOTTOM;
		// Numbers are also centered:
		int numFlags = iconflags|DI_TEXT_ALIGN_CENTER;
		
		// Base position of the leftmost element as provided by the 
		// argument. All other positions are calculated from this 
		// one:
		vector2 iconPos = basePos;
		// Spacing between icons:
		int iconSpacing = 46;
		// Base offset of the number position from the icon position:
		vector2 numOfs = (0, 2);
		// offsets used by power shield and power strength icons:
		vector2 smallIconOfs = (-14, -30);
		
		DrawStaminaBar(iconPos + (-14, -37), iconflags);
	
		// Mugshot (leftmost):
		DrawTexture(GetMugShot(5), iconPos + (3,0), iconflags);
		DrawString(
			mSmallFont, 
			String.Format("%d", CPlayer.health), 
			iconPos + numOfs, 
			numFlags, 
			translation: GetHealthColor(CPlayer.health)
		);
		if (CPlayer.mo.FindInventory("PowerStrength", true))
		{
			name pwr = CPlayer.mo.FindInventory("NoFatality") ? 'HASBERK2' : 'HASBERK';
			DrawImage(pwr, iconPos + smallIconOfs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_TOP);
		}
		
		// Armor:
		iconPos.x += iconSpacing;
		let armor = BasicArmor(CPlayer.mo.FindInventory("BasicArmor"));
		if (armor && armor.amount > 0)
		{
			// armor icon
			DrawInventoryIcon(armor, iconPos, iconflags); 
			// power shield icon
			if (CPlayer.mo.CountInv("PowerShield"))
			{
				DrawImage("HASARMR", iconPos + smallIconOfs,DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_TOP);
			}
			// armor amount
			DrawString(
				mSmallFont,
				String.Format("%d", armor.amount), 
				iconPos + numOfs, 
				numFlags, 
				translation: GetArmorAmountColor(armor.amount)
			);
			// armor absorption
			DrawString(
				mconfont, 
				String.Format("%d%%", Clamp(armor.savepercent * 100, 0, 99)),
				iconPos + (7, -3),
				numFlags,
				translation: GetArmorAbsorbColor(armor),
				scale:(0.4, 0.4)
			);
		}
		
		// Selected item:
		iconPos.x += iconSpacing;
		DrawSelectedInventory(iconPos, iconflags);
		
		DrawKeys((iconpos.x - 16, -2), DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_BOTTOM, (6,6));
	}
	
	int stambarFadeTime; //modified in Tick()
	const STAMFADEWAIT = 60;
	const STAMFADEHALF = STAMFADEWAIT / 2;
	
	void DrawStaminaBar(vector2 pos, int flags = 0)
	{		
		let staminaItem = CPlayer.mo.FindInventory("UsedStamina");
		if (!staminaItem)
			return;
		
		int amt = staminaItem.amount;
		if (amt <= 0 && stambarFadeTime < STAMFADEHALF)
		{
			return;
		}
			
		int maxAmt = staminaItem.MaxAmount;
		int realAmt = maxAmt - amt;
		
		int alpha = LinearMap(stambarFadeTime, STAMFADEHALF, STAMFADEWAIT, 0, 255);
		alpha = Clamp(alpha, 0, 255);
		int red = Linearmap(realAmt, maxAmt, 0, 0, 255);
		int green = Linearmap(realAmt, maxAmt / 2, maxAmt, 100, 255);
		
		Fill(Color(alpha, red, green, 0), pos.x, pos.y, realAmt, 2, flags);
		DrawString(mConfont, "Stamina", pos + (0,-5), flags|DI_TEXT_ALIGN_LEFT, alpha: LinearMap(alpha, 0, 255, 0., 1.), scale: (0.5, 0.5));
	}
	
	void DrawRightcorner(vector2 basePos = (-28, -18))
	{
		int iconflags = DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_CENTER_BOTTOM;
		int numFlags = iconflags|DI_TEXT_ALIGN_CENTER;
		
		vector2 iconPos = basePos;
		int iconSpacing = -44;
		vector2 numOfs = (-2, 1);
		
		Ammo ammo1, ammo2;
		int ammo1amt, ammo2amt;
		[ammo1, ammo2, ammo1amt, ammo2amt] = GetCurrentAmmo();
		
		if (ammo1)
		{
			DrawInventoryIcon(ammo1, iconPos, iconFlags);
			DrawString(
				mDiginumber, 
				String.Format("%02d", ammo1amt), 
				iconPos + numOfs,
				numFlags
			);
		}
		if (ammo2)
		{
			iconPos.x += iconSpacing;
			DrawInventoryIcon(ammo2, iconPos, iconFlags);
			DrawString(
				mDiginumber, 
				String.Format("%d", ammo2amt), 
				iconPos + numOfs,
				numFlags
			);
		}
		
		iconPos += (iconSpacing * 1.4, 12);
		DrawGrenadeIndicator(mIndexfnt, iconPos, iconFlags, (22,22));
	}
	
	string TicsToSeconds(int tics)
	{
		int totalSeconds = tics / TICRATE;
		int minutes = (totalSeconds / 60) % 60;
		int seconds = totalSeconds % 60;

		return String.Format("%d:%d", minutes, seconds);
	}
	
	// Draw powerups in rows, powerup icon to the left, powerup time to the right.
	// Rows go from the bottom if drawn at the bottom of the screen,
	// or from the top if drawn at the top.
	void DrawFullscreenPowerups(vector2 basepos = (0, -11), int flags = 0)
	{
		vector2 iconPos = basePos + (-1, 0);
		vector2 numPos = basePos + (1, 0);
		// negative spacing if drawing from the bottom:
		int ySpacing = -9; 
		// flip it if drawing from the top:
		if (flags & DI_SCREEN_TOP)
			ySpacing * -1;
		
		// Iterate through player's inventory:
		for (let iitem = CPlayer.mo.Inv; iitem != NULL; iitem = iitem.Inv) 
		{
			let item = Powerup(iitem);
			if (item != null) 
			{
				name iconName = "";
				int col = Font.CR_UNTRANSLATED;
				// We have a bunch of BDP-specific
				// power-ups that don't have icons but they
				// really should:
				if (item is "PowerIronFeet")
				{
					iconName = "SUITA0";
					col = Font.CR_Green;
				}
				else if (item is "PowerInvulnerable")
				{
					iconName = "PINVB0";
					col = Font.CR_Black;
				}
				else if (item is "PowerInvisibility")
				{
					iconName = "PINSA0";
					col = Font.CR_Blue;
				}
				else if (item is "PowerLightAmp")
				{
					iconName = "SVISE0";
					col = Font.CR_Cyan;
				}
				else if (item is "PowerquakeDamage")
				{
					iconName = "SIG2A0";
					col = Font.CR_Purple;
				}
				else if (item is "PowerSpeed2")
				{
					iconName = "SIG4A0";
					col = Font.CR_Yellow;
				}
				// In other cases, check if the power-up has
				// an icon defined, and use that:
				else 
				{
					let icon = item.GetPowerupIcon();
					if (icon.IsValid()) 
						iconName = TexMan.GetName(icon);
				}
				
				// Continue drawing only if we have the icon
				// (don't draw times for dummy powerups):
				if (iconName)
				{
					double alph = item.IsBlinking() ? 0.3 : 1.0;
					DrawImage(
						iconName, 
						iconPos, 
						flags|DI_ITEM_RIGHT_TOP, 
						alph, 
						(8, 8)
					);
					DrawString(
						mConfont, 
						TicsToSeconds(item.EffectTics), 
						numpos, 
						flags|DI_TEXT_ALIGN_LEFT,
						translation: col,
						scale: (0.8, 0.8)
					);
					iconPos.y += ySpacing;
					numpos.y += ySpacing;
				}
			}
		}
	}
	
	void DrawTopRight(HudFont fnt, vector2 basePos = (-4, 1))
	{
		int flags = DI_SCREEN_RIGHT_TOP|DI_TEXT_ALIGN_RIGHT;
		vector2 pos = basePos;
		double Ystep = fnt.mFont.GetHeight();
		if (deathmatch)
		{
			DrawString(
				fnt, 
				String.Format("Frags: %d", CPlayer.fragcount), 
				pos,
				flags,
				Font.CR_DarkRed
			);
			pos.y += Ystep;
		}
		
		DrawString(
			fnt, 
			String.Format("Kills: %d/%d", Level.killed_monsters, Level.total_monsters), 
			pos,
			flags,
			Font.CR_White
		);
		pos.y += Ystep;
		
		DrawString(
			fnt, 
			String.Format("Secrets: %d/%d", Level.found_secrets, Level.total_secrets), 
			pos,
			flags,
			Font.CR_White
		);
		pos.y += Ystep;
	}
}