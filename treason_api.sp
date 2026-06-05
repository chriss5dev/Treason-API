#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <treason>

#define TAPI_VERSION "1.1"
#define TAPI_VERSION_INT 010100
 
public Plugin myinfo =
{
	name = "Treason API",
	author = "chriss5",
	description = "A set of abstractions that make it significantly easier to write SourceMod plugins for Klaus Veen's Treason.",
	version = TAPI_VERSION,
	url = "https://github.com/chriss5dev/Treason-API"
};

//global data containers
int PlayerResourceEntity = -1;
int g_DetectiveIndex = -1;
int g_DoctorIndex = -1;
bool g_IsCarnage = false;
bool g_IsCarnagePreRound = false;

//gamedata stuffs
Handle g_hUpdateRole = INVALID_HANDLE;
Handle g_hSetAbility = INVALID_HANDLE;
Handle g_hResetAbility = INVALID_HANDLE;
Handle g_hSetGadget = INVALID_HANDLE;
Handle g_hResetGadget = INVALID_HANDLE;
int g_RoleOffset = -1;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("Treason API");
	CreateNatives();
	return APLRes_Success;
}

public void OnPluginStart()
{
	SDKSetup();
	HookEvents();
	RegisterCommands();
	PrintToServer("[TAPI] Treason API Loaded! Version %s", TAPI_VERSION);
}

public void OnMapStart()
{
    PlayerResourceEntity = GetPlayerResourceEntity();
}

public void SDKSetup()
{
    Handle hGameConf = LoadGameConfigFile("game.treason");
    if (hGameConf == null)
    {
        SetFailState("Failed to load gamedata file 'game.treason.txt'");
    }

    g_RoleOffset = GameConfGetOffset(hGameConf, "PlayerRole");
    if (g_RoleOffset == -1)
    {
        delete hGameConf;
        SetFailState("Failed to find 'PlayerRole' offset in gamedata");
    }

    StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "PlayerUpdateRole"))
    {
        delete hGameConf;
        SetFailState("Failed to set SDKCall from 'PlayerUpdateRole' signature");
    }
    PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
    g_hUpdateRole = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "PlayerAddAbility"))
    {
        delete hGameConf;
        SetFailState("Failed to set SDKCall from 'PlayerAddAbility' signature");
    }
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); 
	g_hSetAbility = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "PlayerResetAbilities"))
    {
        delete hGameConf;
        SetFailState("Failed to set SDKCall from 'PlayerResetAbilities' signature");
    }
	g_hResetAbility = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "PlayerAddGadget"))
    {
        delete hGameConf;
        SetFailState("Failed to set SDKCall from 'PlayerAddGadget' signature");
    }
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); 
	g_hSetGadget = EndPrepSDKCall();
	
	StartPrepSDKCall(SDKCall_Player);
    if (!PrepSDKCall_SetFromConf(hGameConf, SDKConf_Signature, "PlayerResetGadgets"))
    {
        delete hGameConf;
        SetFailState("Failed to set SDKCall from 'PlayerResetGadgets' signature");
    }
	g_hResetGadget = EndPrepSDKCall();
	
    delete hGameConf;

    if (g_hUpdateRole == null || g_hSetAbility == null || g_hResetAbility == null || g_hSetGadget == null|| g_hResetGadget == null)
    {
        SetFailState("Failed to create SDKCalls");
    }
}

public void CreateNatives()
{
	//tapi
	CreateNative("TAPI_Version", N_TAPI_Version);
	//client data
	CreateNative("GetClientKarma", N_GetClientKarma);
	CreateNative("IsClientZombie", N_IsClientZombie);
	//roles
	CreateNative("GetClientRole", N_GetClientRole);
	CreateNative("SetClientRole", N_SetClientRole);
	//special innocents
	CreateNative("GetDetectiveIndex", N_GetDetectiveIndex);
	CreateNative("GetDoctorIndex", N_GetDoctorIndex);
	//class
	CreateNative("GetClientClass", N_GetClientClass);
	//abilities
	CreateNative("GetClientAbility", N_GetClientAbility);
	CreateNative("GetClientAbilities", N_GetClientAbilities);
	CreateNative("AddClientAbility", N_AddClientAbility);
	CreateNative("ResetClientAbilities", N_ResetClientAbilities);
	//gadgets
	CreateNative("GetClientGadget", N_GetClientGadget);
	CreateNative("GetClientGadgets", N_GetClientGadgets);
	CreateNative("AddClientGadget", N_AddClientGadget);
	CreateNative("ResetClientGadgets", N_ResetClientGadgets);
	//round data
	CreateNative("GetIsCarnage", N_GetIsCarnage);
}

public void RegisterCommands()
{
	//tapi
	RegConsoleCmd("tapi", Cmd_TAPI);
	RegConsoleCmd("tapi_int", Cmd_TAPI_INT);
	//get
	RegAdminCmd("tapi_getability", Cmd_GetAbility, ADMFLAG_ROOT);
	RegAdminCmd("tapi_getgadget", Cmd_GetGadget, ADMFLAG_ROOT);
	RegAdminCmd("tapi_getrole", Cmd_GetRole, ADMFLAG_ROOT);
/* 	//set
	RegAdminCmd("tapi_addability", Cmd_GetRole, ADMFLAG_ROOT);
	RegAdminCmd("tapi_addgadget", Cmd_GetRole, ADMFLAG_ROOT);
	RegAdminCmd("tapi_setrole", Cmd_GetRole, ADMFLAG_ROOT);
	//reset or clear
	RegAdminCmd("tapi_resetabilities", Cmd_GetRole, ADMFLAG_ROOT);
	RegAdminCmd("tapi_resetgadgets", Cmd_GetRole, ADMFLAG_ROOT); */
}

public void HookEvents()
{
	HookEvent("round_start", E_RoundStart);
	HookEvent("preround_start", E_PreRoundStart);
	HookEvent("player_death", E_PlayerDeath);
	HookEvent("ability_resus_detective_used", E_ResuscitateDetective);
	HookEvent("ability_resuscitate_used", E_Resuscitate);
}

// EVENTS
public void E_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_DetectiveIndex = event.GetInt("detectiveindex");
	g_DoctorIndex = event.GetInt("doctorindex");
	g_IsCarnage = event.GetBool("iscarnage");
}

public void E_PreRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_DetectiveIndex = 0;
	g_DoctorIndex = 0;
	g_IsCarnagePreRound = event.GetBool("iscarnage");
	g_IsCarnage = false;
}

public void E_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	int user = GetClientOfUserId(userid);
	
	if(user == g_DetectiveIndex)
	{g_DetectiveIndex = 0;}
	if(user == g_DoctorIndex)
	{g_DoctorIndex = 0;}
}

public void E_Resuscitate(Event event, const char[] name, bool dontBroadcast)
{
	//foreach(int i in clientIndex[]) sim
	for (int i = 1; i <= MaxClients; i++)
	{	
		if (IsClientInGame(i) && GetClientRole(i) == TR_Detective)
		{
			g_DetectiveIndex = i;
		}
	}
}

public void E_ResuscitateDetective(Event event, const char[] name, bool dontBroadcast)
{
	//foreach(int i in clientIndex[]) sim
	for (int i = 1; i <= MaxClients; i++)
	{	
		if (IsClientInGame(i) && GetClientRole(i) == TR_Doctor)
		{
			g_DoctorIndex = i;
		}
	}
}

// COMMANDS
public Action Cmd_TAPI(int client, int args)
{
	// Print TAPI version to console
	PrintToConsole(client, "[TAPI] Server is running TAPI version %s", TAPI_VERSION);
	
	return Plugin_Handled;
}

public Action Cmd_TAPI_INT(int client, int args)
{
	// Print TAPI integer version to console
	PrintToConsole(client, "[TAPI] Server is running TAPI version %d", TAPI_VERSION_INT);
	
	return Plugin_Handled;
}

public Action Cmd_GetAbility(int client, int args)
{
	if(args == 1)
	{
		int slot = GetCmdArgInt(1);
		int ability = GetClientAbility(client, slot);
		
		if(slot>2)
		{PrintToConsole(client, "Client has ability %d in slot %d. This slot ID may be invalid.", ability, slot);}
		else if(ability < 0 || ability > 16)
		{PrintToConsole(client, "Client has ability %d in slot %d. This ability ID may be invalid.", ability, slot);}
		else
		{PrintToConsole(client, "Client has ability %d in slot %d.", ability, slot);}
	}
	else
	{
		PrintToConsole(client, "usage: tapi_getability <slot> (slots start from 0)");
	}
	return Plugin_Handled;
}

public Action Cmd_GetGadget(int client, int args)
{
	if(args == 1)
	{
		int slot = GetCmdArgInt(1);
		int gadget = GetClientGadget(client, slot);
		
		if(slot>1)
		{PrintToConsole(client, "Client has gadget %d in slot %d. This slot ID may be invalid.", gadget, slot);}
		else if(gadget < 0 || gadget > 20)
		{PrintToConsole(client, "Client has gadget %d in slot %d. This gadget ID may be invalid.", gadget, slot);}
		else
		{PrintToConsole(client, "Client has gadget %d in slot %d.", gadget, slot);}
	}
	else
	{
		PrintToConsole(client, "usage: tapi_getgadget <slot> (slots start from 0)");
	}
	return Plugin_Handled;
}

public Action Cmd_GetRole(int client, int args)
{
	if(args == 0)
	{
		int role;
		
		if(client==0)
		{PrintToConsole(client, "Source client of this command can not be the server.");}
		else if(!IsClientInGame(client))
		{PrintToConsole(client, "Source client of this command instance is invalid.");}
		else if(role < 0 || role > 6)
		{
			role = GetClientRole(client);
			PrintToConsole(client, "Client has role ID %d. This role ID is invalid.", role);
		}
		else
		{
			role = GetClientRole(client);
			PrintToConsole(client, "Client has role ID %d.", role);
		}
	}
	else
	{
		PrintToConsole(client, "usage: tapi_getrole");
	}
	return Plugin_Handled;
}

// NATIVES
public int N_TAPI_Version(Handle plugin, int numParams)
{
	return TAPI_VERSION_INT;
}

public int N_GetClientKarma(Handle plugin, int numParams)
{
	// PRE must exist
	if(PlayerResourceEntity == -1) {return -1;}		
	
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	
	// Read from netprop
	int karma = GetEntProp(PlayerResourceEntity, Prop_Send, "m_iKarma", 4, client);
	
	return karma;
}

public int N_IsClientZombie(Handle plugin, int numParams)
{
	// PRE must exist
	if(PlayerResourceEntity == -1) {return -1;}
	
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	
	// Read from netprop
	int isZombie = GetEntProp(PlayerResourceEntity, Prop_Send, "m_bIsZombie", 1, client);
	
	return isZombie;
}

public any N_GetClientRole(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	
	if(IsClientInGame(client))
	{
		// Scan client for Ghost Radar
		for (int i = 0; i < 3; i++)
		{
			treasonAbility ability = GetClientAbility(client, i);
			
			if(ability == TAbility_GhostRadar)
			{return TR_Ghost;}
		}
		// Scan client for Ghost Transform
		for (int i = 0; i < 3; i++)
		{
			treasonAbility ability = GetClientAbility(client, i);
			
			if(ability == TAbility_GhostTransform)
			{return TR_None;}
		}
		//otherwise we good to check server memory
		int role = GetEntData(client, g_RoleOffset, 1);
		return role;
	}
	return TA_None;
}

public any N_SetClientRole(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	// Get client index (parameter 1)
	int role = GetNativeCell(2);
	
	if(role <= 5 && role >= 0 && IsClientInGame(client))
	{
		SetEntData(client, g_RoleOffset, role);
		SDKCall(g_hUpdateRole, client, 0);
		return true;
	}
	return false;
}

public int N_GetDetectiveIndex(Handle plugin, int numParams)
{
	if(g_DetectiveIndex > 0 && IsPlayerAlive(g_DetectiveIndex))
	{
		return g_DetectiveIndex;
	}
	else
	{
		//foreach(int i in clientIndex[]) sim
		for (int i = 1; i <= MaxClients; i++)
		{	
			if (IsClientInGame(i) && GetClientRole(i) == TR_Detective)
			{
				return i;
			}
		}
	}
	return 0;
}

public int N_GetDoctorIndex(Handle plugin, int numParams)
{
	if(g_DoctorIndex > 0 && IsPlayerAlive(g_DoctorIndex))
	{
		return g_DoctorIndex;
	}
	else
	{
		//foreach(int i in clientIndex[]) sim
		for (int i = 1; i <= MaxClients; i++)
		{	
			if (IsClientInGame(i) && GetClientRole(i) == TR_Doctor)
			{
				return i;
			}
		}
	}
	return 0;
}

public any N_GetClientClass(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	if(IsClientInGame(client))
	{
		// Scan client for class-exclusive abilities
		for (int i = 0; i < 3; i++) {
			int ability = GetEntProp(client, Prop_Send, "m_nAbilities", 1, i);
			
			switch(ability)
			{
				case TA_Adrenaline: return TC_Light; //light
				case TA_Medkit: return TC_Med; //medium
				case TA_Shield: return TC_Heavy; //heavy
			}
		}
	}
	return TC_None;
}

public any N_GetClientAbility(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	// Get ability slot (parameter 2)
	int slot = GetNativeCell(2);
	
	if(IsClientInGame(client) && slot < 3)
	{
		int ability = GetEntProp(client, Prop_Send, "m_nAbilities", 1, slot);
		return ability;
	}
	return TA_None;
}

public any N_GetClientAbilities(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	int abilities[3];
	int size = GetNativeCell(3);
	if(IsClientInGame(client))
	{
		abilities[0] = GetEntProp(client, Prop_Send, "m_nAbilities", 1, 0);
		abilities[1] = GetEntProp(client, Prop_Send, "m_nAbilities", 1, 1);
		abilities[2] = GetEntProp(client, Prop_Send, "m_nAbilities", 1, 2);
		SetNativeArray(2, abilities, size);
		return true;
	}
	return false;
}

public any N_ResetClientAbilities(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	if(IsClientInGame(client))
	{
		SDKCall(g_hResetAbility, client);
		return true;
	}
	return false;
}

public any N_AddClientAbility(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	int ability = GetNativeCell(2);
	if(IsClientInGame(client))
	{
		SDKCall(g_hSetAbility, client, ability);
		return true;
	}
	return false;
}

public any N_GetClientGadget(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	// Get gadget slot (parameter 2)
	int slot = GetNativeCell(2);
	
	if(IsClientInGame(client) && slot < 2)
	{
		int gadget = GetEntProp(client, Prop_Send, "m_nGadgets", 1, slot);
		return gadget;
	}
	return TG_None;
}

public any N_GetClientGadgets(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	int gadgets[2];
	int size = GetNativeCell(3);
	if(IsClientInGame(client))
	{
		gadgets[0] = GetEntProp(client, Prop_Send, "m_nGadgets", 1, 0);
		gadgets[1] = GetEntProp(client, Prop_Send, "m_nGadgets", 1, 1);
		SetNativeArray(2, gadgets, size);
		return true;
	}
	return false;
}

public any N_ResetClientGadgets(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	if(IsClientInGame(client))
	{
		SDKCall(g_hResetGadget, client);
		return true;
	}
	return false;
}

public any N_AddClientGadget(Handle plugin, int numParams)
{
	// Get client index (parameter 1)
	int client = GetNativeCell(1);
	int gadget = GetNativeCell(2);
	if(IsClientInGame(client))
	{
		SDKCall(g_hSetGadget, client, gadget);
		return true;
	}
	return false;
}

public any N_GetIsCarnage(Handle plugin, int numParams)
{
	// Get "includePreRound" (parameter 1)
	bool includePreRound = GetNativeCell(1);
	
	if(includePreRound)
	{return g_IsCarnagePreRound;}
	else
	{return g_IsCarnage;}
}