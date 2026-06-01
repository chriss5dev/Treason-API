#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <treason>

// "Y.M.D.Revision"
#define TAPI_VERSION "2026.5.29.1"
// "YYYYMMDDR"
#define TAPI_VERSION_INT 202605291
 
public Plugin myinfo =
{
	name = "Treason API",
	author = "chriss5",
	description = "Creates natives, enums, and constants to simplify the process of fetching data from Klaus Veen's Treason.",
	version = TAPI_VERSION,
	url = "http://www.sourcemod.net/"
};

int PlayerResourceEntity = -1;
int g_DetectiveIndex = -1;
int g_DoctorIndex = -1;
bool g_IsCarnage = false;
bool g_IsCarnagePreRound = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("Treason API");
	CreateNatives();
	return APLRes_Success;
}

public void OnPluginStart()
{
	HookEvents();
	RegisterCommands();
	PrintToServer("[TAPI] Treason API Loaded! Version %s", TAPI_VERSION);
}

public void OnMapStart()
{
    PlayerResourceEntity = GetPlayerResourceEntity();
}

public void CreateNatives()
{
	CreateNative("TAPI_Version", N_TAPI_Version);
	CreateNative("GetClientKarma", N_GetClientKarma);
	CreateNative("IsClientZombie", N_IsClientZombie);
	CreateNative("GetClientRole", N_GetClientRole);
	CreateNative("GetDetectiveIndex", N_GetDetectiveIndex);
	CreateNative("GetDoctorIndex", N_GetDoctorIndex);
	CreateNative("GetClientClass", N_GetClientClass);
	CreateNative("GetClientAbility", N_GetClientAbility);
	CreateNative("GetClientAbilities", N_GetClientAbilities);
	CreateNative("GetClientGadget", N_GetClientGadget);
	CreateNative("GetClientGadgets", N_GetClientGadgets);
	CreateNative("GetIsCarnage", N_GetIsCarnage);
}

public void RegisterCommands()
{
	RegConsoleCmd("tapi", Cmd_TAPI);
	RegConsoleCmd("tapi_int", Cmd_TAPI_INT);
	RegAdminCmd("tapi_getability", Cmd_GetAbility, ADMFLAG_ROOT);
	RegAdminCmd("tapi_getgadget", Cmd_GetGadget, ADMFLAG_ROOT);
	RegAdminCmd("tapi_getrole", Cmd_GetRole, ADMFLAG_ROOT);
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
		// Scan client for role-exclusive abilities
		for (int i = 0; i < 3; i++) {
			treasonAbility ability = GetClientAbility(client, i);
			
			if(ability == TA_GhostRadar)
			{return TR_Ghost;}
			else if(!g_IsCarnage)
			{
				switch(ability)
				{
					// has innocent-only abilities?
					case TA_ClueRadar,TA_TeamRadar: return TR_Innocent;
					
					// has traitor-only abilities?
					case TA_TRadar,TA_Zombie: return TR_Traitor;
					
					// has detective-only abilities?
					case TA_DRadar,TA_DetectiveRes: return TR_Detective;
					
					// has doctor-only abilities?
					case TA_RangeHeal,TA_RangeAdrenaline,TA_DoctorRes,TA_BodyRadar: return TR_Doctor;
				}
			}
			else if(g_IsCarnage && IsPlayerAlive(client))
			{
				return TR_Annihilator;
			}
		}
	}
	return TA_None;
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

public any N_GetIsCarnage(Handle plugin, int numParams)
{
	// Get "includePreRound" (parameter 1)
	bool includePreRound = GetNativeCell(1);
	
	if(includePreRound)
	{return g_IsCarnagePreRound;}
	else
	{return g_IsCarnage;}
}