#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>

#include <multicolors>
#include <shop>

#undef REQUIRE_PLUGIN
#tryinclude <zombiereloaded>
#tryinclude <zriot>
#define REQUIRE_PLUGIN

#define CATEGORY	"trails"
#define MAXEDICTS (iMaxEntities - 150)

Cookie g_hCookie;
bool g_bShouldSee[MAXPLAYERS + 1];

KeyValues hKvTrails;

static int iMaxEntities;

int
	iTeam[MAXPLAYERS+1],
 	g_SpriteModel[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

ItemId selected_id[MAXPLAYERS+1];

bool g_bLate = false;

public Plugin myinfo =
{
	name = "[Shop] Trails",
	author = "FrozDark (HLModders LLC)",
	description = "Trails that folows a player",
	version = "2.3.1",
	url = "http://www.hlmod.ru/"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	MarkNativeAsOptional("ZR_IsClientHuman");
	MarkNativeAsOptional("ZR_IsClientZombie");
	MarkNativeAsOptional("ZRiot_IsClientHuman");
	MarkNativeAsOptional("ZRiot_IsClientZombie");

	g_bLate = late;

	return APLRes_Success;
}

public void OnPluginStart()
{
	iMaxEntities = GetMaxEntities();

	g_hCookie = new Cookie("sm_shop_trails", "1 - enabled, 0 - disabled", CookieAccess_Private);

	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iTeam[i] = GetClientTeam(i);
		}
	}

	RegAdminCmd("sm_trails_reload", Command_TrailsReload, ADMFLAG_ROOT, "Reloads trails config list");

	if (g_bLate && Shop_IsStarted())
	{
		Shop_Started();
	}
}

public void OnPluginEnd()
{
	Shop_UnregisterMe();
	for (int i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i))
			continue;

		KillTrail(i);
	}
}

public void OnClientCookiesCached(int client)
{
	char sCookieValue[4];
	g_hCookie.Get(client, sCookieValue, sizeof(sCookieValue));
	g_bShouldSee[client] = (sCookieValue[0] == '\0' ? true : view_as<bool>(StringToInt(sCookieValue)));
}

public void OnClientDisconnect(int client)
{
	g_bShouldSee[client] ? g_hCookie.Set(client, "1") : g_hCookie.Set(client, "0");
	g_bShouldSee[client] = true;
	KillTrail(client);
}

public void OnMapStart()
{
	LoadKeyStructure();
	ReadDownloadsFile();
	ReadKvFile();
}

void ReadDownloadsFile()
{
	char FilePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, FilePath, sizeof(FilePath), "configs/shop/trails_dlist.txt");
	File file = OpenFile(FilePath, "r");
	if (file == null)
	{
		LogError("Failed to open trails_dlist.txt file. Make sure it exists in configs/shop/ folder.");
		return;
	}

	char Line[PLATFORM_MAX_PATH];
	while(!file.EndOfFile() && file.ReadLine(Line, sizeof(Line)))
	{
		TrimString(Line);
		AddFileToDownloadsTable(Line);
	}
	delete file;
}

void ReadKvFile()
{
	char FilePath[PLATFORM_MAX_PATH], MaterialPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, FilePath, sizeof(FilePath), "configs/shop/trails.txt");
	KeyValues Kv = new KeyValues("Trails");
	Kv.ImportFromFile(FilePath);
	Kv.GotoFirstSubKey();
	do
	{
		Kv.GetString("material", MaterialPath, sizeof(MaterialPath));
		PrecacheModel(MaterialPath);
	}
	while(Kv.GotoNextKey());
	delete Kv;
}

void LoadKeyStructure()
{
	if (hKvTrails == null)
	{
		hKvTrails = new KeyValues("Trails");

		char _buffer[PLATFORM_MAX_PATH];
		Shop_GetCfgFile(_buffer, sizeof(_buffer), "trails.txt");

		if (!hKvTrails.ImportFromFile(_buffer)) SetFailState("\"%s\" not found", _buffer);

		hKvTrails.Rewind();
	}
}

public void Shop_Started()
{
	LoadKeyStructure();

	char name[64], description[64];
	hKvTrails.GetString("name", name, sizeof(name), "Trails");
	hKvTrails.GetString("description", description, sizeof(description));

	CategoryId category_id = Shop_RegisterCategory(CATEGORY, name, description);

	char item[64], item_name[64], item_description[64], buffer[PLATFORM_MAX_PATH];
	hKvTrails.Rewind();
	if (hKvTrails.GotoFirstSubKey())
	{
		do
		{
			hKvTrails.GetString("material", buffer, sizeof(buffer));
			if (!File_ExtEqual(buffer, "vmt")) continue;

			hKvTrails.GetSectionName(item, sizeof(item));

			if (Shop_StartItem(category_id, item))
			{
				hKvTrails.GetString("name", item_name, sizeof(item_name), item);
				hKvTrails.GetString("description", item_description, sizeof(item_description));
				Shop_SetInfo(item_name, item_description, hKvTrails.GetNum("price", 500), hKvTrails.GetNum("sell_price", -1), Item_Togglable, hKvTrails.GetNum("duration", 86400));
				Shop_SetCallbacks(OnItemRegistered, OnEquipItem);

				if (hKvTrails.JumpToKey("Attributes", false))
				{
					Shop_KvCopySubKeysCustomInfo(view_as<KeyValues>(hKvTrails));
					hKvTrails.GoBack();
				}

				Shop_EndItem();
			}
		}
		while (hKvTrails.GotoNextKey());

		hKvTrails.Rewind();
	}

	Shop_AddToFunctionsMenu(FuncToggleVisibilityDisplay, FuncToggleVisibility);
}

public void FuncToggleVisibilityDisplay(int client, char[] buffer, int maxlength)
{
	Format(buffer, maxlength, "Trails: %s", g_bShouldSee[client] ? "Visible" : "Hidden");
}

public bool FuncToggleVisibility(int client)
{
	g_bShouldSee[client] = !g_bShouldSee[client];
	CPrintToChat(client, "{green}[Shop] {default}Shop trails is %s{default}.", g_bShouldSee[client] ? "{blue}visible":"{red}hidden");
	return false;
}

public void OnItemRegistered(CategoryId category_id, const char[] category, const char[] item, ItemId item_id)
{
	if (hKvTrails.JumpToKey(item))
	{
		hKvTrails.SetNum("id", view_as<int>(item_id));
		hKvTrails.Rewind();
	}
}

public Action Command_TrailsReload(int client, int args)
{
	if (hKvTrails != null)
	{
		delete hKvTrails;
	}

	OnPluginEnd();
	Shop_Started();

	ReplyToCommand(client, "Trails config list reloaded successfully!");

	return Plugin_Handled;
}

public ShopAction OnEquipItem(int client, CategoryId category_id, const char[] category, ItemId item_id, const char[] item, bool isOn, bool elapsed)
{
	if (isOn || elapsed)
	{
		OnClientDisconnect(client);

		selected_id[client] = INVALID_ITEM;

		return Shop_UseOff;
	}

	Shop_ToggleClientCategoryOff(client, category_id);

	selected_id[client] = item_id;

	SpriteTrail(client);

	return Shop_UseOn;
}

public void OnMapEnd()
{
	for (int client = 1; client <= MAXPLAYERS; client++)
	{
		g_SpriteModel[client] = INVALID_ENT_REFERENCE;
	}
}

public void OnClientDisconnect_Post(int client)
{
	iTeam[client] = 0;
	selected_id[client] = INVALID_ITEM;
	g_SpriteModel[client] = INVALID_ENT_REFERENCE;
}

public void PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int client = GetClientOfUserId(userid);
	if (!IsValidClient(client))
		return;

	CreateTimer(1.0, Timer_GiveTrail, userid, TIMER_FLAG_NO_MAPCHANGE);
}

public void PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client, true))
		return;

	iTeam[client] = event.GetInt("team");
	if (iTeam[client] != 0 && iTeam[client] != 1)
		return;

	KillTrail(client);
}

public void PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client))
		return;

	KillTrail(client);
}

public Action Timer_GiveTrail(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(client < 1 || !IsClientInGame(client))
		return Plugin_Stop;

	SpriteTrail(client);
	return Plugin_Continue;
}

public void ZRiot_OnClientHuman(int client)
{
	SpriteTrail(client);
}

public void ZR_OnClientHumanPost(int client, bool respawn, bool protect)
{
	SpriteTrail(client);
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	SpriteTrail(client);
}

public void ZRiot_OnClientZombie(int client)
{
	SpriteTrail(client);
}

bool SpriteTrail(int client)
{
	if (!IsValidClient(client))
		return false;

	KillTrail(client);

	if (GetEdictsCount() > MAXEDICTS)
	{
		CPrintToChat(client, "[Shop] Trails: Server reached edicts limit. Please try again later..");
		return false;
	}

	if (selected_id[client] == INVALID_ITEM || iTeam[client] <= 1 || !IsPlayerAlive(client))
	{
		return false;
	}

	char item[SHOP_MAX_STRING_LENGTH];
	item[0] = '\0';
	Shop_GetItemById(selected_id[client], item, sizeof(item));

	if (!item[0] || !hKvTrails.JumpToKey(item))
	{
		PrintToServer("Item '%s' does not exist", item);
		return false;
	}

	int ent = CreateEntityByName("env_spritetrail");
	if (ent != -1)
	{
		char buffer[PLATFORM_MAX_PATH];
		float dest_vector[3];

		DispatchKeyValueFloat(ent, "lifetime", hKvTrails.GetFloat("lifetime", 1.0));

		hKvTrails.GetString("startwidth", buffer, sizeof(buffer), "10");
		DispatchKeyValue(ent, "startwidth", buffer);

		hKvTrails.GetString("endwidth", buffer, sizeof(buffer), "6");
		DispatchKeyValue(ent, "endwidth", buffer);

		hKvTrails.GetString("material", buffer, sizeof(buffer));
		DispatchKeyValue(ent, "spritename", buffer);
		DispatchKeyValue(ent, "renderamt", "255");

		hKvTrails.GetString("color", buffer, sizeof(buffer));
		DispatchKeyValue(ent, "rendercolor", buffer);

		IntToString(hKvTrails.GetNum("rendermode", 1), buffer, sizeof(buffer));
		DispatchKeyValue(ent, "rendermode", buffer);

		DispatchSpawn(ent);

		hKvTrails.GetVector("position", dest_vector);

		float
			or[3],
			ang[3],
			fForward[3],
			fRight[3],
			fUp[3];

		GetClientAbsOrigin(client, or);
		GetClientAbsAngles(client, ang);

		GetAngleVectors(ang, fForward, fRight, fUp);

		or[0] += fRight[0]*dest_vector[0] + fForward[0]*dest_vector[1] + fUp[0]*dest_vector[2];
		or[1] += fRight[1]*dest_vector[0] + fForward[1]*dest_vector[1] + fUp[1]*dest_vector[2];
		or[2] += fRight[2]*dest_vector[0] + fForward[2]*dest_vector[1] + fUp[2]*dest_vector[2];

		TeleportEntity(ent, or, NULL_VECTOR, NULL_VECTOR);

		SetVariantString("!activator");
		AcceptEntityInput(ent, "SetParent", client);
		SetEntPropFloat(ent, Prop_Send, "m_flTextureRes", 0.05);
		SetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity", client);

		SDKHook(ent, SDKHook_SetTransmit, Hook_TrailShouldHide);

		g_SpriteModel[client] = EntIndexToEntRef(ent);
	}
	hKvTrails.Rewind();

	return true;
}

public Action Hook_TrailShouldHide(int entity, int client)
{
	if (!g_bShouldSee[client])
	{
		return Plugin_Handled;
	}

	if (EntRefToEntIndex(g_SpriteModel[client]) == entity || iTeam[client] < 2)
	{
		return Plugin_Continue;
	}
	return Plugin_Continue;
}

void KillTrail(int client)
{
	int ent = EntRefToEntIndex(g_SpriteModel[client]);
	if (ent != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(ent, "kill");
	}

	g_SpriteModel[client] = INVALID_ENT_REFERENCE;
}

stock void File_GetExtension(const char[] path, char[] buffer, int size)
{
	int extpos = FindCharInString(path, '.', true);

	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock bool File_ExtEqual(const char[] path, const char[] ext, bool caseSensetive = false)
{
	char buf[4];
	File_GetExtension(path, buf, sizeof(buf));
	return StrEqual(buf, ext, caseSensetive);
}


bool IsValidClient(int client, bool bAllowFake = false)
{
	if (client < 1 || client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (!bAllowFake && IsFakeClient(client))
		return false;

	return true;
}

stock int GetEdictsCount()
{
	int iCount = 0;
	for (int entity = 1; entity <= iMaxEntities; entity++)
	{
		if(IsValidEdict(entity))
			iCount++;
	}

	return iCount;
}
