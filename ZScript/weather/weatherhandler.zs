class PrecipitationType : Object
{
	private bool bInitialized;
	
	private Dictionary fields;
	private Dictionary defaultFields;
	private string name;
	
	void Initialize(string n)
	{
		if (bInitialized)
			return;
		
		bInitialized = true;
		self.name = n;
		fields = Dictionary.Create();
		defaultFields = Dictionary.Create();
	}
	
	void SetDefaultsFrom(Dictionary d, bool checkTerminator = false)
	{
		let it = DictionaryIterator.Create(d);
		while (it.Next())
		{
			string v = it.Value();
			if (checkTerminator && v == "\\0")
				v = "";
			
			defaultFields.Insert(it.Key(), v);
		}
	}
	
	void SetDefaults()
	{
		let it = DictionaryIterator.Create(fields);
		while (it.Next())
			defaultFields.Insert(it.Key(), it.Value());
	}
	
	void Reset()
	{
		let it = DictionaryIterator.Create(defaultFields);
		while (it.Next())
			fields.Insert(it.Key(), it.Value());
	}
	
	// Getters
	
	string GetName()
	{
		return self.name;
	}
	
	string GetValue(string k)
	{
		return fields.At(k);
	}
	
	bool GetBool(string k)
	{
		return !!fields.At(k).ToInt();
	}
	
	int GetInt(string k)
	{
		return fields.At(k).ToInt();
	}
	
	double GetFloat(string k)
	{
		return fields.At(k).ToDouble();
	}
	
	string GetDefaultValue(string k)
	{
		return defaultFields.At(k);
	}
	
	bool GetDefaultBool(string k)
	{
		return !!defaultFields.At(k).ToInt();
	}
	
	int GetDefaultInt(string k)
	{
		return defaultFields.At(k).ToInt();
	}
	
	double GetDefaultFloat(string k)
	{
		return defaultFields.At(k).ToDouble();
	}
	
	// Wrappers
	
	string GetLocalizedString(string k)
	{
		return StringTable.Localize(GetValue(k));
	}
	
	string GetDefaultLocalizedString(string k)
	{
		return StringTable.Localize(GetDefaultValue(k));
	}
	
	int GetTime(string k)
	{
		return ceil(GetFloat(String.Format("%stime", k)) * TICRATE);
	}
	
	Color GetColor(string k)
	{
		return Color(GetInt(String.Format("%scolor", k)));
	}
	
	double GetAlpha(string k)
	{
		return GetFloat(String.Format("%salpha", k));
	}
	
	sound GetSound(string k)
	{
		return sound(GetValue(String.Format("%ssound", k)));
	}
	
	double GetVolume(string k)
	{
		return GetFloat(String.Format("%svolume", k));
	}
	
	class<Precipitation> GetType(string k)
	{
		return (class<Precipitation>)(GetValue(String.Format("%stype", k)));
	}
	
	// Setters
	
	void SetValue(string k, string v)
	{
		fields.Insert(k, v);
	}
	
	void SetBool(string k, bool v)
	{
		fields.Insert(k, String.Format("%d", v));
	}
	
	void SetInt(string k, int v)
	{
		fields.Insert(k, String.Format("%d", v));
	}
	
	void SetFloat(string k, double v)
	{
		fields.Insert(k, String.Format("%f", v));
	}
}

struct ParserError
{
	string message;
	uint index;
}

enum EParserTokens
{
	PT_TYPE,
	PT_OPEN,
	PT_CLOSE,
	PT_ASSIGN,
	PT_BOOLFIELD,
	PT_INTFIELD,
	PT_FLOATFIELD,
	PT_STRINGFIELD,
	PT_NUMBER,
	PT_STRING,
	
	PT_OPENSTRING = 1000,
	PT_INVALID
}

class WeatherHandler : StaticEventHandler
{
	private Dictionary nameTypes;
	private Dictionary symbols;
	private Dictionary boolFields;
	private Dictionary intFields;
	private Dictionary floatFields;
	private Dictionary stringFields;
	
	private ParserError error;
	
	Array<PrecipitationType> precipTypes;
	
	// Parsing
	
	private void SetError(string msg, uint i = 0)
	{
		error.message = msg;
		error.index = i;
	}
	
	private bool HasError()
	{
		return error.message != "";
	}
	
	private void ThrowError(string lumpName, Array<string> words)
	{
		string e = String.Format("\c[Red]WTHRINFO Error: %s", error.message);
		if (error.index < words.Size())
			e.AppendFormat(" [%s]", words[error.index]);
		e.AppendFormat(" in lump %s", lumpName);
		
		console.printf("%s", e);
		console.printf("\c[Red]WTHRINFO parsing failed");
		precipTypes.Clear();
	}
	
	override void OnRegister()
	{
		CreateLookupTables();
		
		int lumpNum = 0;
		do
		{
			lumpNum = Wads.FindLump("WTHRINFO", lumpNum);
			if (lumpNum < 0)
				break;
			
			string lump = Wads.ReadLump(lumpNum);
			Array<string> words;
			Array<int> tokens;
			
			// Remove line comments
			int cInd = 0;
			do
			{
				cInd = lump.IndexOf("//", cInd);
				if (cInd < 0)
					break;
				
				int end = lump.IndexOf("\n", cInd+2);
				if (end < 0)
					end = lump.Length();
				
				lump.Remove(cInd, (end+1)-cInd);
			}
			while (true);
			
			// Remove block comments
			cInd = 0;
			do
			{
				cInd = lump.IndexOf("/*", cInd);
				if (cInd < 0)
					break;
				
				int end = lump.IndexOf("*/", cInd+2);
				if (end < 0)
				{
					SetError("Dangling block comment");
					break;
				}
				
				lump.Remove(cInd, (end+2)-cInd);
			}
			while (true);
			
			if (HasError())
			{
				ThrowError(Wads.GetLumpFullName(lumpNum), words);
				return;
			}
			
			// Sanitize
			lump.Replace("\t", " "); 
			lump.Replace("\r", " ");
			lump.Replace("\n", " ");
			lump.Split(words, " ", TOK_SKIPEMPTY);
			
			Tokenize(words, tokens);
			Parse(tokens);
			if (HasError())
			{
				ThrowError(Wads.GetLumpFullName(lumpNum), words);
				return;
			}
			
			CreatePrecipitation(words);
			++lumpNum;
		} while (true);
	}
	
	// Look up tables for each data field
	void CreateLookupTables()
	{
		nameTypes = Dictionary.Create();
		nameTypes.Insert("precipitation", String.Format("%d", PT_TYPE));
		
		symbols = Dictionary.Create();
		symbols.Insert("{", String.Format("%d", PT_OPEN));
		symbols.Insert("}", String.Format("%d", PT_CLOSE));
		symbols.Insert("=", String.Format("%d", PT_ASSIGN));
		
		boolFields = Dictionary.Create();
		boolFields.Insert("stormy", "0");
		boolFields.Insert("foggy", "0");
		boolFields.Insert("fogindoors", "0");
		boolFields.Insert("precipitationindoors", "0");
		boolFields.Insert("thunderindoors", "0");
		boolFields.Insert("lightningindoors", "0");
		boolFields.Insert("windindoors", "0");
		boolFields.Insert("fogonlyindoors", "0");
		boolFields.Insert("precipitationonlyindoors", "0");
		boolFields.Insert("thunderonlyindoors", "0");
		boolFields.Insert("lightningonlyindoors", "0");
		boolFields.Insert("windonlyindoors", "0");
		
		intFields = Dictionary.Create();
		intFields.Insert("precipitationamount", "0");
		intFields.Insert("lightningcolor", "0xFFFFFFFF");
		intFields.Insert("fogcolor", "0xFF696969");
		
		floatFields = Dictionary.Create();
		floatFields.Insert("fogalpha", "0");
		floatFields.Insert("fogfadeintime", "0.1");
		floatFields.Insert("fogfadeouttime", "0.1");
		floatFields.Insert("minprecipitationvolume", "0.3");
		floatFields.Insert("maxprecipitationvolume", "1");
		floatFields.Insert("precipitationvolumefadeintime", "0.2");
		floatFields.Insert("precipitationvolumefadeouttime", "1");
		floatFields.Insert("minwindvolume", "0.3");
		floatFields.Insert("maxwindvolume", "1");
		floatFields.Insert("windvolumefadeintime", "0.2");
		floatFields.Insert("windvolumefadeouttime", "1");
		floatFields.Insert("minthundervolume", "0.3");
		floatFields.Insert("maxthundervolume", "1");
		floatFields.Insert("thundervolumefadeintime", "0.2");
		floatFields.Insert("thundervolumefadeouttime", "1");
		floatFields.Insert("minthundertime", "15");
		floatFields.Insert("maxthundertime", "30");
		floatFields.Insert("lightningalpha", "0");
		floatFields.Insert("minlightningtime", "15");
		floatFields.Insert("maxlightningtime", "30");
		floatFields.Insert("lightningfadeintime", "0.02");
		floatFields.Insert("lightningfadeouttime", "0.1");
		floatFields.Insert("precipitationratetime", "0");
		floatFields.Insert("precipitationradius", "1024");
		floatFields.Insert("precipitationheight", "384");
		
		stringFields = Dictionary.Create();
		stringFields.Insert("precipitationtype", "\\0");
		stringFields.Insert("precipitationtag", "\\0");
		stringFields.Insert("precipitationsound", "\\0");
		stringFields.Insert("windsound", "\\0");
		stringFields.Insert("thundersound", "\\0");
	}
	
	// Convert lump strings into tokens
	void Tokenize(out Array<string> words, out Array<int> tokens)
	{
		bool open = false;
		bool dontSpace = false;
		for (uint i = 0; i < words.Size(); ++i)
		{
			string word = words[i].MakeLower();
			if (word == "")
			{
				words.Delete(i--);
				continue;
			}
			
			// Catch strings
			int lInd = word.IndexOf("\"");
			if (lInd >= 0)
			{
				int rInd = word.RightIndexOf("\"");
				uint count = 0;
				int index = 0;
				do
				{
					index = word.IndexOf("\"", index);
					if (index < 0)
						break;
					
					++count;
					++index;
				} while (true);
				
				if (count > 2
					|| (!open && (lInd > 0 || (count > 1 && rInd < word.Length()-1)))
					|| (open && (count > 1 || rInd < word.Length()-1)))
				{
					// Invalid
					open = true;
					break;
				}
				else
				{
					if (count == 2)
					{
						tokens.Insert(0, PT_STRING);
						continue;
					}
					else if (!open)
					{
						tokens.Insert(0, PT_STRING);
						open = true;
						dontSpace = word.Length() == 1;
						continue;
					}
					else
					{
						open = false;
						if (word.Length() > 1)
							words[i-1].AppendFormat(" %s", words[i]);
						else
							words[i-1].AppendFormat("%s", words[i]);
						
						words.Delete(i--);
						continue;
					}
				}
			}
			
			if (open)
			{
				if (dontSpace)
					words[i-1].AppendFormat("%s", words[i]);
				else
					words[i-1].AppendFormat(" %s", words[i]);
				
				dontSpace = false;
				words.Delete(i--);
				continue;
			}
			
			// Tokenize normally
			if (nameTypes.At(word) != "")
				tokens.Insert(0, PT_TYPE);
			else if (symbols.At(word) != "")
				tokens.Insert(0, symbols.At(word).ToInt());
			else if (boolFields.At(word) != "")
				tokens.Insert(0, PT_BOOLFIELD);
			else if (intFields.At(word) != "")
				tokens.Insert(0, PT_INTFIELD);
			else if (floatFields.At(word) != "")
				tokens.Insert(0, PT_FLOATFIELD);
			else if (stringFields.At(word) != "")
				tokens.Insert(0, PT_STRINGFIELD);
			else if (tokens.Size() >= 2 && tokens[0] == PT_ASSIGN && (tokens[1] == PT_INTFIELD || tokens[1] == PT_FLOATFIELD))
				tokens.Insert(0, PT_NUMBER);
			else
				tokens.Insert(0, PT_INVALID);
		}
		
		if (open)
			tokens.Insert(0, PT_OPENSTRING);
	}
	
	// Make sure lump syntax is valid
	void Parse(Array<int> tokens)
	{
		Array<int> traversed;
		bool open = false;
		uint declarationIndex = 0;
		do
		{
			int token = GetToken(tokens);
			if (token < 0)
				break;
			
			int prev = -1;
			int assigned = -1;
			uint s = traversed.Size();
			if (s)
			{
				prev = traversed[s-1];
				if (s > 1)
					assigned = traversed[s-2];
			}
			
			traversed.Push(token);
			
			if (token == PT_OPENSTRING)
			{
				SetError("Invalid string syntax", traversed.Size()-1);
				break;
			}
			else if (token == PT_INVALID)
			{
				SetError("Unknown identifier", traversed.Size()-1);
				break;
			}
			
			switch(token)
			{
				case PT_TYPE:
					if (open)
						SetError("Defined new precipitation type before closing current one", traversed.Size());
					open = true;
					declarationIndex = traversed.Size();
					break;
					
				case PT_OPEN:
					if (prev != PT_STRING || assigned != PT_TYPE)
						SetError("Invalid opening brace", traversed.Size()-1);
					break;
					
				case PT_CLOSE:
					if (prev != PT_OPEN && !IsDataType(prev))
						SetError("Invalid closing brace", traversed.Size()-1);
					open = false;
					break;
					
				case PT_ASSIGN:
					if (!IsDataField(prev))
						SetError("Attempt to assign to an invalid field", traversed.Size()-2);
					break;
					
				case PT_NUMBER:
					if (prev != PT_ASSIGN || (assigned != PT_INTFIELD && assigned != PT_FLOATFIELD))
						SetError("Invalid numeric declaration", traversed.Size()-1);
					break;
					
				case PT_STRING:
					if (prev != PT_TYPE && (prev != PT_ASSIGN || assigned != PT_STRINGFIELD))
						SetError("Invalid string declaration", traversed.Size()-1);
					break;
					
				case PT_BOOLFIELD:
				case PT_INTFIELD:
				case PT_FLOATFIELD:
				case PT_STRINGFIELD:
					if (prev != PT_OPEN && !IsDataType(prev))
						SetError("Invalid field declaration", traversed.Size()-1);
					break;
			}
			
			if (HasError())
				break;
		} while (tokens.Size() > 0);
		
		if (open && !HasError())
			SetError("Precipitation declaration not closed correctly", declarationIndex);
	}
	
	bool IsDataType(int token)
	{
		switch(token)
		{
			case PT_BOOLFIELD:
			case PT_NUMBER:
			case PT_STRING:
				return true;
		}
		
		return false;
	}
	
	bool IsDataField(int token)
	{
		switch(token)
		{
			case PT_INTFIELD:
			case PT_FLOATFIELD:
			case PT_STRINGFIELD:
				return true;
		}
		
		return false;
	}
	
	int GetToken(out Array<int> tokens)
	{
		uint s = tokens.Size();
		if (!s)
			return -1;
		
		int t = tokens[s-1];
		tokens.Pop();
		
		return t;
	}
	
	// Generate precipitation objects from lump
	// Not using a dictionary in the object because ZScript only accepts strings
	// leading to constant conversions from string -> int/double/bool
	void CreatePrecipitation(Array<string> words)
	{
		PrecipitationType cur;
		for (uint i = 0; i < words.Size(); ++i)
		{
			string word = words[i].MakeLower();
			
			if (nameTypes.At(word) != "")
			{
				if (word == "precipitation")
				{
					if (cur)
						cur.SetDefaults();
					
					++i;
					string val = words[i].Mid(1, words[i].Length()-2);
					cur = Find(val);
					if (!cur)
					{
						cur = new("PrecipitationType");
						cur.Initialize(val);
						precipTypes.Push(cur);
					}
					
					cur.SetDefaultsFrom(boolFields);
					cur.SetDefaultsFrom(intFields);
					cur.SetDefaultsFrom(floatFields);
					cur.SetDefaultsFrom(stringFields, true);
					cur.Reset();
				}
			}
			else if (boolFields.At(word) != "")
				cur.SetValue(word, "1");
			else if (intFields.At(word) != "")
			{
				i += 2;
				cur.SetValue(word, words[i]);
			}
			else if (floatFields.At(word) != "")
			{
				i += 2;
				cur.SetValue(word, words[i]);
			}
			else if (stringFields.At(word) != "")
			{
				i += 2;
				cur.SetValue(word, words[i].Mid(1, words[i].Length()-2));
			}
		}
		
		if (cur)
			cur.SetDefaults();
	}
	
	PrecipitationType Find(string name)
	{
		if (name == "")
			return null;
		
		for (uint i = 0; i < precipTypes.Size(); ++i)
		{
			if (precipTypes[i].GetName() ~== name)
				return precipTypes[i];
		}
		
		return null;
	}
	
	// General weather handling
	
	private Weather wthr;
	float noFog;
	float noLightning;
	
	override void WorldTick()
	{
		if (!wthr)
			wthr = Weather.Get();
	}
	
	override void RenderUnderlay(RenderEvent e)
	{
		if (!wthr || automapactive)
			return;
		
		int x, y, w, h;
		[x, y, w, h] = Screen.GetViewWindow();
		
		
		
	
			double fog;
			Color col;
			[fog, col] = wthr.GetFog(e.fracTic);
			Screen.Dim(col, fog, x, y, w, h);
		
	
		
		if (wthr.InLightningFlash())
		{
			double inten;
			Color flash;
			[inten, flash] = wthr.GetLightning(e.fracTic);
			Screen.Dim(flash, inten, x, y, w, h);
		}
	}
}