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
	HUDFont weapPromptFnt;
	Int ArrowTimer;
	int lasttickgrenade;
	int hinttimer;
	double hintfade;
	int randomhint;
	DynamicValueInterpolator hookinterpx;
	DynamicValueInterpolator hookinterpy;

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
		// DOOM Hudfont:
		fnt = "HUDFONT_DOOM";
		mHUDFont = HUDFont.Create(fnt, fnt.GetCharWidth("0"), Mono_CellLeft, 1, 1);
		Arrowtimer = 66;
		weapPromptFnt = HUDFont.Create(Font.GetFont('BigUpper'));
		hookinterpx = DynamicValueInterpolator.Create(0,10,1,5);
		hookinterpy = DynamicValueInterpolator.Create(0,10,1,5);
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
			If(!automapactive)
			{
				drawcrosshairs();
				drawkillstreak();
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
			If(!automapactive)
			{
				drawcrosshairs();
				drawkillstreak();
				drawdeathhints(mSmallFontNS);
			}
		}
	}
	
	override void Tick()
	{
		super.Tick();
		BDPPlayerPawn BDPplr = BDPPlayerPawn(cplayer.mo);
		int stamina;
		If(BDPplr)
		{
			stamina = BDPplr.stamina;
		}
		if (stamina > 0)
		{
			stambarFadeTime = Clamp(stambarFadeTime + 1, 0, STAMFADEWAIT);
		}
		else
		{
			stambarFadeTime = Clamp(stambarFadeTime - 1, 0, STAMFADEWAIT);
		}
		
		int teleport = CPlayer.mo.CountInv("TeleporterTimer");
		if (teleport > 0)
		{
			TeleFadeTime = Clamp(TeleFadeTime + 1, 0, TELEFADEWAIT);
		}
		else
		{
			TeleFadeTime = Clamp(TeleFadeTime - 1, 0, TELEFADEWAIT);
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
		
		if (CPlayer.mo.FindInventory("PowerShield", true) || CPlayer.mo.FindInventory("PowerShield2", true))
		{
			DrawImage("HASARMR", (179, 169), DI_ITEM_LEFT_TOP);
		}
		
		DrawGrenadeIndicator(mIndexfnt, (334, 194), box: (22,22),TRUE);
		
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
	bool DrawGrenadeIndicator(HUDFont fnt, vector2 pos, int flags = 0, vector2 box = (-1,-1), bool reversed = FALSE)
	{
		If(ArrowTimer <= 66)
		ArrowTimer++;
	
		//let gammo = CPlayer.mo.FindInventory("GrenadeAmmo");
		//if (gammo)
		//{
			string nade = "";
			string nade2 = "";
			int nade1ammo = 0;
			int nade2ammo = 0;
			// Pick the grenade icon based on the amount of
			// NadeType in inventory:
			int nadeAmt = (CPlayer.mo.CountInv("NadeType"));
			switch (nadeAmt)
			{
			case 1:
				nade2 = "GRNDA"; 
				nade = "PIPBE";
				nade2ammo = (CPlayer.mo.CountInv("AmmoFragGrenade"));
				nade1ammo = (CPlayer.mo.CountInv("AmmoPipeBomb"));
				break;
			case 0:
				nade = "GRNDA"; 
				nade2 = "PIPBE";
				nade1ammo = (CPlayer.mo.CountInv("AmmoFragGrenade"));
				nade2ammo = (CPlayer.mo.CountInv("AmmoPipeBomb"));
				break;
			}
			if (nade)
			{
				If(nade1ammo > 0)
				{
					DrawImage(nade, pos, flags, box: box);
					//DrawString(fnt, String.Format("%d", gammo.amount), pos + (box.x / 2, -4), flags|DI_TEXT_ALIGN_RIGHT);
					DrawString(
					msmallfont,
					String.Format("%d",nade1ammo),
					pos + ((box.x / 6) + 5, -8),
					DI_TEXT_ALIGN_RIGHT,
					Font.CR_White
					//scale:(0.8, 0.8)
					);
				}
				If(nade2ammo > 0)
				{
					If(reversed)
					pos = (pos + (17, 0));
					else
					pos = (pos + (-17, 0));
					DrawImage(nade2, pos, flags, box: (11,11), scale:(0.5,0.5));
					DrawString(
						msmallfont,
						String.Format("%d",nade2ammo),
						pos + ( 3, -4),
						DI_TEXT_ALIGN_RIGHT,
						Font.CR_White,
						scale:(0.5, 0.5)
					);
				}
				
				
				If(lasttickgrenade != CPlayer.mo.CountInv("NadeType"))
				{
					ArrowTimer = 0;
				}
				LastTickGrenade = CPlayer.mo.CountInv("NadeType");
				
				
				
				
				
				
				
				
				
				return true;
			}
		//}
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
				//DrawString(mIndexfnt, String.Format("%d",invsel.amount), pos + (box.x / 2, -4), DI_TEXT_ALIGN_RIGHT|flags);
				DrawString(
				mconfont,
				String.Format("%d",invsel.amount),
				pos + (box.x / 4, -5),
				DI_TEXT_ALIGN_RIGHT|flags,
				scale:(0.8, 0.8)
				);
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
		if (CPlayer.mo.CountInv("PowerShield") || CPlayer.mo.CountInv("PowerShield2"))
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
			iconpos.x -= (iconsize.x + hofs);
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
			//name pwr = CPlayer.mo.FindInventory("NoFatality") ? 'HASBERK2' : 'HASBERK';
			DrawImage('HASBERK', iconPos + smallIconOfs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_TOP);
			smallIconOfs.y = (smallIconOfs.y + 5);
		}
		if (CPlayer.mo.FindInventory("PowerBoost", true))
		{
			//name pwr = CPlayer.mo.FindInventory("NoFatality") ? 'HASBERK2' : 'HASBERK';
			DrawImage('HASBSTR', iconPos + smallIconOfs, DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_TOP);
			smallIconOfs.y = (smallIconOfs.y + 5);
		}
		if (CPlayer.mo.CountInv("PowerShield") || CPlayer.mo.CountInv("PowerShield2"))
			{
				DrawImage("HASARMR", iconPos + smallIconOfs,DI_SCREEN_LEFT_BOTTOM|DI_ITEM_LEFT_TOP);
			}
		BDPPlayerPawn BDPplr = BDPPlayerPawn(Cplayer.mo);
		If(BDPplr && BDPplr.extralives > 0)
		{
			DrawString(
				mconFont, 
				String.Format("%d", BDPplr.extralives), 
				iconPos + (13, -5),
				iconflags|DI_TEXT_ALIGN_RIGHT,
				translation: Font.CR_White,
				scale:(0.8, 0.8)
			);
		}
		
		// Armor:
		iconPos.x += iconSpacing;
		let armor = BasicArmor(CPlayer.mo.FindInventory("BasicArmor"));
		if (armor && armor.amount > 0)
		{
			// armor icon
			//Should always show as energy armor if equipped
			If(CPlayer.mo.FindInventory("PowerShield"))
			{
				DrawImage("ARM2G0",iconpos,iconflags);
			}
			else
			{
				DrawInventoryIcon(armor, iconPos, iconflags); 
			}
			// power shield icon
			
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
				String.Format("%d%", Clamp(armor.savepercent * 100, 0, 99)),
				iconPos + (7, -5),
				numFlags,
				translation: GetArmorAbsorbColor(armor),
				scale:(0.8, 0.8)
			);
		}
		
		// Selected item:
		iconPos.x += iconSpacing;
		DrawSelectedInventory(iconPos, iconflags);
		
		
	}
	
	int stambarFadeTime; //modified in Tick()
	const STAMFADEWAIT = 10;
	const STAMFADEHALF = STAMFADEWAIT / 2;
	
	void DrawStaminaBar(vector2 pos, int flags = 0)
	{		
		BDPPlayerPawn BDPplr = BDPPlayerPawn(Cplayer.mo);
		if (!BDPplr || !BDPplr.istactical)
			return;
		
		int amt = BDPplr.stamina;
		if (amt <= 0 && stambarFadeTime < STAMFADEHALF)
		{
			return;
		}
			
		int maxAmt = 100;
		int realAmt = maxAmt - amt;
		
		int alpha = LinearMap(stambarFadeTime, STAMFADEHALF, STAMFADEWAIT, 0, 255);
		alpha = Clamp(alpha, 0, 255);
		int red = Linearmap(realAmt, maxAmt, 0, 0, 255);
		int green = Linearmap(realAmt, maxAmt / 2, maxAmt, 100, 255);
		If(!bdpplr.exhausted)
		{
			Fill(Color(alpha, red, green, 0), pos.x, pos.y, realAmt, 2, flags);
		}
		else
		{
			Fill(Color(alpha, 255, 0, 0), pos.x, pos.y, realAmt, 2, flags);
		}
		DrawString(mConfont, "Stamina", pos + (0,-5), flags|DI_TEXT_ALIGN_LEFT, alpha: LinearMap(alpha, 0, 255, 0., 1.), scale: (0.5, 0.5));
	}
	
	int teleFadeTime; //modified in Tick()
	const TELEFADEWAIT = 10;
	const TELEFADEHALF = TELEFADEWAIT / 2;
	
	void DrawTeleBar(vector2 pos, int flags = 0)
	{		
		let TeleportItem = CPlayer.mo.FindInventory("TeleporterTimer");
		if (!TeleportItem)
			return;
		
		int amt = TeleportItem.amount;
		if (amt <= 0 && TeleFadeTime < TELEFADEHALF)
		{
			return;
		}
			
		int maxAmt = TeleportItem.MaxAmount;
		int realAmt = maxAmt - amt;
		
		int alpha = LinearMap(TeleFadeTime, TELEFADEHALF, TELEFADEWAIT, 0, 255);
		alpha = Clamp(alpha, 0, 255);
		
		Fill(Color(alpha, 255, 0, 0), pos.x, pos.y, -Amt, 2, flags);
		DrawString(mConfont, "Teleporter", pos + (0,-5), flags|DI_TEXT_ALIGN_RIGHT, alpha: LinearMap(alpha, 0, 255, 0., 1.), scale: (0.5, 0.5));
	}
	
	void DrawRightcorner(vector2 basePos = (18, -19))
	{
		int iconflags = DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_CENTER_BOTTOM;
		int numFlags = iconflags|DI_TEXT_ALIGN_CENTER;
		
		vector2 iconPos = basePos;
		int iconSpacing = -46;
		vector2 numOfs = (-2, 1);
		
		if(CPlayer.mo.player.readyweapon && Cplayer.mo.player.readyweapon is "Tenderizer")
		{
			DrawTeleBar(iconPos + (-32, -29), iconflags);
		}
		
		int MagAmt;
		int ammo3Amt;
		Class<Inventory> Ammo3;
		let weap = BDPWeaponBase(CPlayer.mo.player.ReadyWeapon);
		if (weap)
		{
			Ammo3 = Weap.Ammotype3;
			If(Ammo3)
			{
				ammo3amt = CPlayer.mo.countinv(ammo3);
			}
			if(weap.bDUALWEAPON)
			{
				let dualweap = BDPWeaponBase(CPlayer.mo.FindInventory(weap.DualWeapon));
				MagAmt = Weap.mag + DualWeap.mag;
			}
			else
			{
				MagAmt = Weap.mag;
			}
		}
		
		
		
		
		
		
		Ammo ammo1, ammo2;
		int ammo1amt, ammo2amt;
		[ammo1, ammo2, ammo1amt, ammo2amt] = GetCurrentAmmo();
		
		
		if (ammo3)
		{
			iconPos.x += iconSpacing;
			DrawInventoryIcon(CPlayer.mo.findinventory(ammo3), iconPos, iconFlags);
			DrawString(
				mHudfont, 
				String.Format("%d", ammo3amt), 
				iconPos + numOfs,
				numFlags,
				Font.CR_White
			);
		}
		if (ammo2)
		{
			iconPos.x += iconSpacing;
			DrawInventoryIcon(ammo2, iconPos, iconFlags);
			DrawString(
				mHudfont, 
				String.Format("%d", ammo2amt), 
				iconPos + numOfs,
				numFlags,
				Font.CR_White
			);
		}
		if (ammo1)
		{
			iconPos.x += iconSpacing;
			
			DrawInventoryIcon(ammo1, iconPos, iconFlags);
			
			DrawString(
				mHudfont, 
				String.Format("%d", ammo1amt), 
				iconPos + numOfs,
				numFlags,
				Font.CR_White
			);
		}
		if (weap && weap.magcapacity)
		{
			iconPos.x += iconSpacing;
			DrawInventoryIcon(weap, iconPos, iconFlags);
			DrawString(
				mHudfont, 
				String.Format("%d", MagAmt), 
				iconPos + numOfs,
				numFlags,
				Font.CR_White
			);
		}
		
		iconPos += (iconSpacing * 1, 17);
		DrawGrenadeIndicator(mIndexfnt, iconPos, iconFlags, (22,22));
		
		let plr = BDPPlayerPawn(CPlayer.mo);
		if (plr && plr.focusWeapon && !automapactive)
		{
			textureID focusicon = geticon(plr.focusweapon,0);
			DrawString(weapPromptFnt, plr.focusWeaponPrompt, (-22, -48), DI_SCREEN_RIGHT_BOTTOM|DI_TEXT_ALIGN_RIGHT, scale: (0.5, 0.5));
			Drawtexture(focusicon,(-22,-51),DI_SCREEN_RIGHT_BOTTOM|DI_ITEM_RIGHT_BOTTOM);
		}
		
		
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
				else if (item is "PowerRage")
				{
					iconName = "DDMGA0";
					col = Font.CR_RED;
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
				if (iconName && !(item is "PowerBloodOnVisor") && !(item is "PowerBlueBloodOnVisor") && !(item is "PowerGreenBloodOnVisor") && !(item is "VisorAmp"))
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
					//DEBUG
					/*
					numpos.x = (numpos.x + 25);
					DrawString(
						mConfont, 
						item.getclassname(), 
						numpos, 
						flags|DI_TEXT_ALIGN_LEFT,
						translation: col,
						scale: (0.8, 0.8)
					);
					numpos.x = (numpos.x - 25);
					*/
					
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
		BDPPlayerPawn BDPplr = BDPPlayerPawn(Cplayer.mo);
		If(BDPplr && BDPplr.scoremaster)
		{
			DrawString(
			fnt, 
			String.Format("Score: %d", Cplayer.mo.score), 
			pos,
			flags,
			Font.CR_White
			);
			pos.y += Ystep;
		}
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
		DrawKeys((-4, pos.y), DI_SCREEN_RIGHT_TOP|DI_ITEM_RIGHT_TOP, (8,8));
	}
	
	void DrawCrosshairs()
	{		
		// Get player
		BDPPlayerPawn BDPplr = BDPPlayerPawn(Cplayer.mo);
		If(BDPplr && BDPplr.health > 0)
		{
			let curvehicle = Veh_Manager(BDPplr.FindInventory("Veh_Manager"));
			
			string crosshair = bdpplr.crosshair;
			vector2 retsize = bdpplr.crosshairscale;
			
			Color crossTint = 0;
			Actor aimAct = bdpplr.aimActor; 
			
			if(curvehicle && curvehicle.disableweaps)
			{
				crosshair = curvehicle.crosshair;
				retsize = curvehicle.crosshair_scale;
				aimAct = BDPVehicle(curvehicle.veh).aimActor;
			}
			
			bool hostileAim = aimAct && aimAct.isHostile(bdpplr) && aimAct.bISMONSTER && !(aimAct is "BDPVehicle") && !aimAct.bSHADOW;
			
			If(aimAct && aimAct is "BASEHEADSHOT")
			{
				hostileAim = true;
			}
			if(hostileAim) crossTint = Color(0xC4, 0xD0,0,0);
			vector2 midpos = (0,0);
			
			double trans = CVar.GetCVAR("bdp_crosshair_trans",Cplayer).GetFloat();
			//if(Screen.GetHeight() >= 1440)
			//{
				HLSBS.DrawImage(crosshair..0, midpos, HLSBS.SS_SCREEN_CENTER, trans, scale:retsize / 1.33, tint:crossTint);
			/*}
			else if(Screen.GetHeight() <= 720)
			{
				HLSBS.DrawImage(crosshair..1, midpos, HLSBS.SS_SCREEN_CENTER, trans, scale:retsize * 1.5 , tint:crossTint);
			}
			else
			{
				HLSBS.DrawImage(crosshair, midpos, HLSBS.SS_SCREEN_CENTER, trans, scale:retsize, tint:crossTint);
			}*/
			return;
		}
	}
	
	void Drawkillstreak()
	{		
		// Get player
		BDPPlayerPawn BDPplr = BDPPlayerPawn(Cplayer.mo);
		
		If(BDPplr && BDPplr.killstreak > 2)
		{
			int killstreakcount = BDPplr.killstreak;
			double killalpha;
			If(BDPplr.killstreaktimer <= 30)
			{
				killalpha = ( BDPplr.killstreaktimer * 0.03);
			}
			Else
			{
				killalpha = 1.0;
			}
			
			DrawString(weapPromptFnt, string.format("X %i", killstreakcount), (-5, 24), DI_SCREEN_CENTER|DI_TEXT_ALIGN_LEFT, Font.CR_UNTRANSLATED, killalpha, scale: (0.5, 0.5));
			DrawImage("KILLSKLL", (-13,32), DI_SCREEN_CENTER, killalpha, scale: (0.5, 0.5));
		}
		
			
	}
	void DrawDeathHints(HUDFont fnt)
	{
		If(cplayer.mo.health > 0)
		{
			hinttimer = 0;
			hintfade = 0;
		}
		Else if(hinttimer < 150)
		{
			hinttimer++;
			randomhint = random(0,33);
		}
		Else if(hintfade < 1.0)
		{
			hintfade += 0.02;
		}
		BDPPlayerPawn BDPplr = BDPPlayerPawn(cplayer.mo);
		bool nightmare = BDPplr.ultranightmare;
		If(hinttimer >= 150 && !nightmare)
		{
			DrawString(Fnt, string.format(stringtable.localize(deathstring[randomhint])), (0, -80), DI_SCREEN_CENTER_BOTTOM|DI_TEXT_ALIGN_CENTER, Font.CR_White, hintfade, scale: (0.75, 0.75));
		}
	}
	static const String DeathString[] =
	{
		"$DHINT0",
		"$DHINT1",
		"$DHINT2",
		"$DHINT3",
		"$DHINT4",
		"$DHINT5",
		"$DHINT6",
		"$DHINT7",
		"$DHINT8",
		"$DHINT9",
		"$DHINT10",
		"$DHINT11",
		"$DHINT12",
		"$DHINT13",
		"$DHINT14",
		"$DHINT15",
		"$DHINT16",
		"$DHINT17",
		"$DHINT18",
		"$DHINT19",
		"$DHINT20",
		"$DHINT21",
		"$DHINT22",
		"$DHINT23",
		"$DHINT24",
		"$DHINT25",
		"$DHINT26",
		"$DHINT27",
		"$DHINT28",
		"$DHINT29",
		"$DHINT29",
		"$DHINT30",
		"$DHINT31",
		"$DHINT32",
		"$DHINT33",
		"$DHINT34",
		"$DHINT35",
		"$DHINT36",
		"$DHINT37",
		"$DHINT38",
		"$DHINT39"
		
	};
}

class BDP_OverlayUI : EventHandler
{	
	Array<Key> foundkeys;
	Array<Actor> foundkeys2;
	
	ui double prevMS, deltatime;

	void AddNewKey(Key k)
	{
		string colors = (
			"Brick.Tan.Gray.Grey.Green.Brown.Gold.Red.Blue.Orange.White.Yellow."
			"Black.LightBlue.Cream.Olive.DarkGreen.DarkRed.DarkBrown.Purple."
			"DarkGray.Cyan.Ice.Fire.Sapphire.Teal" 
		);
		foundkeys.push(k);
		
			String keyname = k.GetClassName();
			Array<String> keytype;
			StringHelper.SplitByUppercase(keyname, keytype);
			// Find first valid key color.
			for(int i = 0; i < keytype.Size(); i++)
			{
				if(colors.IndexOf(keytype[i]) == -1) continue;
				Color kcol = Color(keytype[i]);
				k.SetShade(kcol);
			}
		
		
	}
	
	void AddNewKey2(Actor k, String kcol)
	{
		foundkeys2.push(k);
		k.SetShade(kcol);
			
		
		
	}
	
	override void WorldLoaded(WorldEvent e)
	{
		foundkeys.Clear();
		let key_it = ThinkerIterator.Create("Key");
		Key foundkey;
		while( foundkey = Key(key_it.Next()) ) AddNewKey(foundkey);
		
		
	}	
	override void WorldThingSpawned(WorldEvent e)
	{
		if(e.Thing is "Key") AddNewKey(Key(e.Thing));
		Else if(e.thing is "BDBlueCard")
		{
			AddNewKey2(e.thing, "Blue");
		}
		Else if(e.thing is "BDRedCard")
		{
			AddNewKey2(e.thing, "Red");
		}
		Else if(e.thing is "BDYellowCard")
		{
			AddNewKey2(e.thing, "Orange");
		}
		Else if(e.thing is "BDBlueSkull")
		{
			AddNewKey2(e.thing, "Blue");
		}
		Else if(e.thing is "BDRedSkull")
		{
			AddNewKey2(e.thing, "Red");
		}
		Else if(e.thing is "BDYellowSkull")
		{
			AddNewKey2(e.thing, "Orange");
		}
		Else if(e.thing is "NewAllMap")
		{
			AddNewKey2(e.thing, "green");
		}
	}
	
	
	

	// Keys and Hitmarkers
	override void RenderOverlay(RenderEvent e)
	{	
		// Get player
		BDPPlayerPawn BDPplr = BDPPlayerPawn(e.Camera);
		if(!BDPplr)
		{
			let BDPcam = BDPVehCamera(e.Camera);
			if(BDPcam) BDPplr = BDPPlayerPawn(BDPcam.source);
			if(!BDPplr) return;
		}
		
		
		
		// Draw HUD projections
		if(!automapactive && BDPplr.scanneractive) 
		{
			DrawKeys(e);
		}
		
		If(BDPplr && BDPplr.health > 0)
		{
			Actor aimAct = bdpplr.aimActor2; 
			bool hostileAim = aimAct && aimAct.isHostile(bdpplr) && aimAct.bISMONSTER && !(aimAct is "BDPVehicle") && !aimAct.bSHADOW;
			if(aimAct)
			{
				// Project KeyNAV
				HLViewProjection viewproj = HLSBS.GetEventViewerProj(e);
				bool infront;
				vector2 apos;
				[infront, apos] = HLSBS.GetActorHUDPos (
					viewproj,
					aimAct, 0, 0, aimAct.height / 2
				);
				string crosshair = bdpplr.targetercrosshair;
				vector2 retsize = bdpplr.targetercrosshairscale;
				if(infront && crosshair)
				{
					double dist = e.Camera.Distance3D(aimAct);
					vector2 distscale = (1,1);
					distscale *= dist/200.;
					distscale.x = clamp(distscale.x, 2.0, 2.0);
					distscale.y = clamp(distscale.y, 2.0, 2.0);
					double trans = CVar.GetCVAR("bdp_crosshair_trans",BDPplr.player).GetFloat();
					
					HLSBS.DrawImage(crosshair..0, apos, 0, trans, scale:retsize / 1.33, absolute:true);
				}
			}
		}
		
		// Keep track of time, always.
		if(!prevMS)
		{
			prevMS = MSTime();
			return;
		}
		double ftime = MSTime()-prevMS;
		prevMS = MSTime();
		double dtime = 1000.0 / 60.;
		deltatime = (ftime/dtime);
	}
	
	ui void DrawKeys(RenderEvent e)
	{
		Actor rendersrc = e.Camera;
		// Very important to note here that, Keys should NEVER be removed
		// from this Array. RenderOverlay runs at your NATIVE framerate and thus
		// runs faster than the Play-scopes ability to write to foundkeys.
		// This means, you can potentially get access out of bounds depending 
		// on performance which is, really bad.
		for(int i = 0; i < foundkeys.Size(); i++)
		{
			Key k = foundkeys[i];
			if(k && !k.Owner)
			{
				// Project KeyNAV
				HLViewProjection viewproj = HLSBS.GetEventViewerProj(e);
				bool infront;
				vector2 apos;
				[infront, apos] = HLSBS.GetActorHUDPos (
					viewproj,
					k, 0, 0, k.height*1.5
				);
				if(infront) 
				{
					int keytint = k.fillcolor;
					double dist = rendersrc.Distance3D(k);
					vector2 distscale = (1,1);
					distscale *= dist/200.;
					distscale.x = clamp(distscale.x, 2.0, 2.0);
					distscale.y = clamp(distscale.y, 2.0, 2.0);
					
					HLSBS.DrawImage("BDPNAV", apos, 0, 1, distscale, tint:keytint, absolute:true);
					HLSBS.DrawString3D(
						"BigFont", 
						String.Format("%dm",dist/UNIT_METER), 
						apos, 0, 
						Font.CR_WHITE, 
						scale:(2,2),
						distance: 300.
					);
				}
			}
		}
		for(int i = 0; i < foundkeys2.Size(); i++)
		{
			Actor k = foundkeys2[i];
			if(k)
			{
				// Project KeyNAV
				HLViewProjection viewproj = HLSBS.GetEventViewerProj(e);
				bool infront;
				vector2 apos;
				[infront, apos] = HLSBS.GetActorHUDPos (
					viewproj,
					k, 0, 0, k.height*1.5
				);
				if(infront) 
				{
					int keytint = k.fillcolor;
					double dist = rendersrc.Distance3D(k);
					vector2 distscale = (1,1);
					distscale *= dist/200.;
					distscale.x = clamp(distscale.x, 2.0, 2.0);
					distscale.y = clamp(distscale.y, 2.0, 2.0);
					
					HLSBS.DrawImage("BDPNAV", apos, 0, 1, distscale, tint:keytint, absolute:true);
					HLSBS.DrawString3D(
						"BigFont", 
						String.Format("%dm",dist/UNIT_METER), 
						apos, 0, 
						Font.CR_WHITE, 
						scale:(2,2),
						distance: 300.
					);
				}
			}
		}
	}
	
	
	
}

// Copyright 2017-2019 Nash Muhandes
// All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions
// are met:
//
// 1. Redistributions of source code must retain the above copyright
//    notice, this list of conditions and the following disclaimer.
// 2. Redistributions in binary form must reproduce the above copyright
//    notice, this list of conditions and the following disclaimer in the
//    documentation and/or other materials provided with the distribution.
// 3. The name of the author may not be used to endorse or promote products
//    derived from this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
// IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
// OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
// IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
// INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
// NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
// THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

//===========================================================================
//
// Custom Widgets for Tilt++
// Adds tooltips to widgets
//
// Some redundant duplicates here but whatever; menus are painful to work
// with in general anyway. >:(
//
//===========================================================================

class OptionMenuItemBDPOption : OptionMenuItemOption
{
	String mTooltip;

	OptionMenuItemBDPOption Init(String label, String tooltip, Name command, Name values, CVar graycheck = null, int center = 0)
	{
		mTooltip = tooltip;
		Super.Init(label, command, values, graycheck, center);
		return self;
	}
}

class OptionMenuItemBDPSlider : OptionMenuItemSlider
{
	String mTooltip;

	OptionMenuItemBDPSlider Init(String label, String tooltip, Name command, double min, double max, double step, int showval = 1, CVar graycheck = null)
	{
		mTooltip = tooltip;
		Super.Init(label, command, min, max, step, showval, graycheck);
		return self;
	}
}

//===========================================================================
//
// Tilt++ Menu
//
//===========================================================================

class BDPMenu : OptionMenu
{
	override void Drawer ()
	{
		Super.Drawer();

		String tt;

		if (mDesc.mSelectedItem > 0)
		{
			if (mDesc.mItems[mDesc.mSelectedItem] is "OptionMenuItemBDPOption")
			{
				tt = StringTable.Localize(OptionMenuItemBDPOption(mDesc.mItems[mDesc.mSelectedItem]).mTooltip);
			}

			if (mDesc.mItems[mDesc.mSelectedItem] is "OptionMenuItemBDPSlider")
			{
				tt = StringTable.Localize(OptionMenuItemBDPSlider(mDesc.mItems[mDesc.mSelectedItem]).mTooltip);
			}
		}

		if (tt.Length() > 0)
		{
			Screen.DrawText (OptionFont(), OptionMenuSettings.mFontColorValue,
				(Screen.GetWidth() - OptionFont().StringWidth (tt) * CleanXfac_1) / 2,
				BigFont.GetHeight() * CleanYfac_1 * 2.5,
				tt,
				DTA_CleanNoMove_1, true);
		}
	}
}