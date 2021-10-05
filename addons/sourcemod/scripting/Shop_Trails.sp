#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <shop>
#include <smartdm>

#undef REQUIRE_PLUGIN
#include <clientprefs>
#include <multicolors>
#tryinclude <zombiereloaded>
#tryinclude <zriot>
#tryinclude <ToggleEffects>

#define PLUGIN_VERSION	"2.2.2"
#define CATEGORY	"trails"

new Handle:g_hCookie;
new bool:g_bShouldSee[MAXPLAYERS + 1];

new bool:toggleEffects = false;

new Handle:hKvTrails;

new iTeam[MAXPLAYERS+1];
new g_SpriteModel[MAXPLAYERS + 1] = {-1, ...};
new ItemId:selected_id[MAXPLAYERS+1];

new Handle:prchArray;

public Plugin:myinfo =
{
	name = "[Shop] Trails",
	author = "FrozDark (HLModders LLC)",
	description = "Trails that folows a player",
	version = PLUGIN_VERSION,
	url = "http://www.hlmod.ru/"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	MarkNativeAsOptional("ZR_IsClientHuman"); 
	MarkNativeAsOptional("ZR_IsClientZombie"); 
	MarkNativeAsOptional("ZRiot_IsClientHuman"); 
	MarkNativeAsOptional("ZRiot_IsClientZombie"); 

	return APLRes_Success;
}

public OnPluginStart()
{
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i))
		{
			iTeam[i] = GetClientTeam(i);
		}
	}
	
	prchArray = CreateArray(ByteCountToCells(PLATFORM_MAX_PATH));
	
	RegAdminCmd("sm_trails_reload", Command_TrailsReload, ADMFLAG_ROOT, "Reloads trails config list");
	
	if (Shop_IsStarted()) Shop_Started();
	
	g_hCookie = RegClientCookie("sm_shop_trails", "1 - enabled, 0 - disabled", CookieAccess_Private);
}

public OnPluginEnd()
{
	Shop_UnregisterMe();
	for (new i = 1; i <= MaxClients; i++)
	{
		KillTrail(i);
	}
}

public OnAllPluginsLoaded()
{
	toggleEffects = LibraryExists("specialfx");
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "specialfx"))
	{
		toggleEffects = true;
	}
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "specialfx"))
	{
		toggleEffects = false;
	}
}

public OnClientCookiesCached(client)
{
	g_bShouldSee[client] = GetCookieBool(client, g_hCookie);
}

bool GetCookieBool(int iClient, Handle hCookie)
{
	char sBuffer[4];
	GetClientCookie(iClient, hCookie, sBuffer, 4);
	return (StringToInt(sBuffer) == 0 && sBuffer[0] != 0)?false:true;
}

public void OnClientDisconnect(int client)
{
	SetCookieBool(client, g_hCookie, g_bShouldSee[client]);
	g_bShouldSee[client] = true;
	KillTrail(client);
}

void SetCookieBool(int iClient, Handle hCookie, bool bValue)
{
	if ( bValue ) {
		SetClientCookie(iClient, hCookie, "1");
	}
	else {
		SetClientCookie(iClient, hCookie, "0");
	}
}

public OnMapStart()
{
	LoadKeyStructure();
	
	decl String:buffer[PLATFORM_MAX_PATH];
	for (new i = 0; i < GetArraySize(prchArray); i++)
	{
		GetArrayString(prchArray, i, buffer, sizeof(buffer));
		Downloader_AddFileToDownloadsTable(buffer);
		PrecacheModel(buffer, true);
	}
}

LoadKeyStructure()
{
	if (hKvTrails == INVALID_HANDLE)
	{
		hKvTrails = CreateKeyValues("Trails");
		
		decl String:_buffer[PLATFORM_MAX_PATH];
		Shop_GetCfgFile(_buffer, sizeof(_buffer), "trails.txt");
		
		if (!FileToKeyValues(hKvTrails, _buffer)) SetFailState("\"%s\" not found", _buffer);
		
		KvRewind(hKvTrails);
	}
}

public Shop_Started()
{
	LoadKeyStructure();
	
	decl String:name[64], String:description[64];
	KvGetString(hKvTrails, "name", name, sizeof(name), "Trails");
	KvGetString(hKvTrails, "description", description, sizeof(description));
	
	new CategoryId:category_id = Shop_RegisterCategory(CATEGORY, name, description);
	
	decl String:item[64], String:item_name[64], String:item_description[64], String:buffer[PLATFORM_MAX_PATH];
	KvRewind(hKvTrails);
	if (KvGotoFirstSubKey(hKvTrails))
	{
		ClearArray(prchArray);
		do
		{
			KvGetString(hKvTrails, "material", buffer, sizeof(buffer));
			if (!File_ExtEqual(buffer, "vmt")) continue;
			
			KvGetSectionName(hKvTrails, item, sizeof(item));
			
			if (Shop_StartItem(category_id, item))
			{
				KvGetString(hKvTrails, "name", item_name, sizeof(item_name), item);
				KvGetString(hKvTrails, "description", item_description, sizeof(item_description));
				Shop_SetInfo(item_name, item_description, KvGetNum(hKvTrails, "price", 500), KvGetNum(hKvTrails, "sell_price", -1), Item_Togglable, KvGetNum(hKvTrails, "duration", 86400));
				Shop_SetCallbacks(OnItemRegistered, OnEquipItem);
				
				if (KvJumpToKey(hKvTrails, "Attributes", false))
				{
					Shop_KvCopySubKeysCustomInfo(view_as<KeyValues>(hKvTrails));
					KvGoBack(hKvTrails);
				}
				
				Shop_EndItem();
			}
		}
		while (KvGotoNextKey(hKvTrails));
		
		KvRewind(hKvTrails);
	}
	
	Shop_AddToFunctionsMenu(FuncToggleVisibilityDisplay, FuncToggleVisibility);
}

public FuncToggleVisibilityDisplay(int client, char[] buffer, int maxlength)
{
	Format(buffer, maxlength, "Trails: %s", g_bShouldSee[client] ? "Visible" : "Hidden");
}

public bool:FuncToggleVisibility(int client)
{
	g_bShouldSee[client] = !g_bShouldSee[client];
	CPrintToChat(client, "{green}[Shop] {default}Shop trails is %s{default}.", g_bShouldSee[client] ? "{blue}visible":"{red}hidden");
	return false;
}

public OnItemRegistered(CategoryId:category_id, const String:category[], const String:item[], ItemId:item_id)
{
	if (KvJumpToKey(hKvTrails, item))
	{
		decl String:buffer[PLATFORM_MAX_PATH];
		KvGetString(hKvTrails, "material", buffer, sizeof(buffer));
		Downloader_AddFileToDownloadsTable(buffer);
		PrecacheModel(buffer, true);
		PushArrayString(prchArray, buffer);
		
		KvSetNum(hKvTrails, "id", _:item_id);
		KvRewind(hKvTrails);
	}
}

public Action:Command_TrailsReload(client, args)
{
	if (hKvTrails != INVALID_HANDLE)
	{
		CloseHandle(hKvTrails);
		hKvTrails = INVALID_HANDLE;
	}
	
	OnPluginEnd();
	Shop_Started();
	
	ReplyToCommand(client, "Trails config list reloaded successfully!");
	
	return Plugin_Handled;
}

public ShopAction:OnEquipItem(client, CategoryId:category_id, const String:category[], ItemId:item_id, const String:item[], bool:isOn, bool:elapsed)
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

public OnMapEnd()
{
	for (new client = 1; client <= MAXPLAYERS; client++)
	{
		g_SpriteModel[client] = -1;
	}
}

public OnClientDisconnect_Post(client)
{
	iTeam[client] = 0;
	selected_id[client] = INVALID_ITEM;
	g_SpriteModel[client] = -1;
}

public PlayerSpawn(Handle:event,const String:name[],bool:dontBroadcast)
{
	CreateTimer(1.0, GiveTrail, GetEventInt(event, "userid"));
}

public PlayerTeam(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	iTeam[client] = GetEventInt(event, "team");
}

public PlayerDeath(Handle:event,const String:name[],bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	KillTrail(client);
}

public Action:GiveTrail(Handle:timer, any:userid)
{
	SpriteTrail(GetClientOfUserId(userid));
}

public ZRiot_OnClientHuman(client)
{
	SpriteTrail(client);
}

public ZR_OnClientHumanPost(client, bool:respawn, bool:protect)
{
	SpriteTrail(client);
}

public ZR_OnClientInfected(client, attacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	SpriteTrail(client);
}

public ZRiot_OnClientZombie(client)
{
	SpriteTrail(client);
}

bool:SpriteTrail(client)
{
	if (!client)
	{
		return false;
	}

	KillTrail(client);
	
	if (selected_id[client] == INVALID_ITEM || iTeam[client] == 0 || IsFakeClient(client))
	{
		return false;
	}
	if (!IsPlayerAlive(client) || !(1 < iTeam[client] < 4))
	{
		return true;
	}
	
	decl String:item[SHOP_MAX_STRING_LENGTH];
	item[0] = '\0';
	Shop_GetItemById(selected_id[client], item, sizeof(item));
	
	if (!item[0] || !KvJumpToKey(hKvTrails, item))
	{
		PrintToServer("Item %s is not exists");
		return false;
	}
	
	g_SpriteModel[client] = CreateEntityByName("env_spritetrail");
	if (g_SpriteModel[client] != -1) 
	{
		decl String:buffer[PLATFORM_MAX_PATH], Float:dest_vector[3];
		
		DispatchKeyValueFloat(g_SpriteModel[client], "lifetime", KvGetFloat(hKvTrails, "lifetime", 1.0));
		
		KvGetString(hKvTrails, "startwidth", buffer, sizeof(buffer), "10");
		DispatchKeyValue(g_SpriteModel[client], "startwidth", buffer);
		
		KvGetString(hKvTrails, "endwidth", buffer, sizeof(buffer), "6");
		DispatchKeyValue(g_SpriteModel[client], "endwidth", buffer);
		
		KvGetString(hKvTrails, "material", buffer, sizeof(buffer));
		DispatchKeyValue(g_SpriteModel[client], "spritename", buffer);
		DispatchKeyValue(g_SpriteModel[client], "renderamt", "255");
		
		KvGetString(hKvTrails, "color", buffer, sizeof(buffer));
		DispatchKeyValue(g_SpriteModel[client], "rendercolor", buffer);
		
		IntToString(KvGetNum(hKvTrails, "rendermode", 1), buffer, sizeof(buffer));
		DispatchKeyValue(g_SpriteModel[client], "rendermode", buffer);
		
		DispatchSpawn(g_SpriteModel[client]);
		
		KvGetVector(hKvTrails, "position", dest_vector);
		
		decl Float:or[3], Float:ang[3],
		Float:fForward[3],
		Float:fRight[3],
		Float:fUp[3];
		
		GetClientAbsOrigin(client, or);
		GetClientAbsAngles(client, ang);
		
		GetAngleVectors(ang, fForward, fRight, fUp);

		or[0] += fRight[0]*dest_vector[0] + fForward[0]*dest_vector[1] + fUp[0]*dest_vector[2];
		or[1] += fRight[1]*dest_vector[0] + fForward[1]*dest_vector[1] + fUp[1]*dest_vector[2];
		or[2] += fRight[2]*dest_vector[0] + fForward[2]*dest_vector[1] + fUp[2]*dest_vector[2];
		
		TeleportEntity(g_SpriteModel[client], or, NULL_VECTOR, NULL_VECTOR);
		
		SetVariantString("!activator");
		AcceptEntityInput(g_SpriteModel[client], "SetParent", client); 
		SetEntPropFloat(g_SpriteModel[client], Prop_Send, "m_flTextureRes", 0.05);
		SetEntPropEnt(g_SpriteModel[client], Prop_Send, "m_hOwnerEntity", client);
		
		// if (hide)
		// {
		SDKHook(g_SpriteModel[client], SDKHook_SetTransmit, Hook_TrailShouldHide);
		// }
	}
	KvRewind(hKvTrails);
	
	return true;
}

public Action:Hook_TrailShouldHide(entity, client)
{
	if (toggleEffects && !ShowClientEffects(client) || !g_bShouldSee[client])
	{
		return Plugin_Handled;
	}
	
	if (g_SpriteModel[client] == entity || iTeam[client] < 2)
	{
		return Plugin_Continue;
	}
	// new owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	// if (owner != -1 && iTeam[owner] != iTeam[client])
	// {
		// return Plugin_Handled;
	// }
	return Plugin_Continue;
}

KillTrail(client)
{
	if (g_SpriteModel[client] > MaxClients && IsValidEdict(g_SpriteModel[client]))
	{
		AcceptEntityInput(g_SpriteModel[client], "kill");
	}
	
	g_SpriteModel[client] = -1;
}

stock File_GetExtension(const String:path[], String:buffer[], size)
{
	new extpos = FindCharInString(path, '.', true);
	
	if (extpos == -1)
	{
		buffer[0] = '\0';
		return;
	}

	strcopy(buffer, size, path[++extpos]);
}

stock File_ExtEqual(const String:path[], const String:ext[], bool:caseSensetive = false)
{
	decl String:buf[4];
	File_GetExtension(path, buf, sizeof(buf));
	return StrEqual(buf, ext, caseSensetive);
}
