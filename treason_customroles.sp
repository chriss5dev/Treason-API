#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <dhooks>
#include <treason>
#include <chriss5math>
#define MAXCUSTOMROLES 16
#define REQUIRED_TAPI_VERSION 010301
 
public Plugin myinfo =
{
	name = "Treason Custom Roles",
	author = "chriss5",
	description = "Creates the illusion of custom roles existing in Klaus Veen's Treason. Included in the Treason API.",
	version = "0.97",
	url = "https://github.com/chriss5dev/Treason-API"
};

GlobalForward g_RegisterCustomRolesForward;
GlobalForward g_SoloStoppedRoundEndForward;
GlobalForward g_SoloWinForward;
GlobalForward g_ClearRolesForward;
GlobalForward g_AssignedCustomRoleForward;

ConVar g_cvMinCustomRolesTraitor;
ConVar g_cvMinCustomRolesInnocent;
ConVar g_cvMinCustomRolesSolo;
ConVar g_cvMaxCustomRolesTraitor;
ConVar g_cvMaxCustomRolesInnocent;
ConVar g_cvMaxCustomRolesSolo;
ConVar g_cvAction1Key;
ConVar g_cvEnableDeathmatchMusic;
ConVar g_cvDataForceWinActive;

public CustomRole g_CustomRoles[MAXCUSTOMROLES];
public int g_ClientRoles[MAXPLAYERS+1];
public int g_ClientClasses[MAXPLAYERS+1];
public bool g_TempDisabledClients[MAXPLAYERS+1];
public bool g_RecentlySelectedSoloClients[MAXPLAYERS+1];
Handle g_HudTimer = INVALID_HANDLE;

Handle g_hEndRound = INVALID_HANDLE;

int endConditionOverride = -1;
int potrOverride = -1;
int winnerOverride = -1;
bool forceWinActive = false;
bool g_lastInnocentTriggeredThisRound = false;

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("Treason Custom Roles");
	CreateNatives();
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	if (TAPI_Version() < REQUIRED_TAPI_VERSION)
	{
		SetFailState(
			"[TCR] Treason Custom Roles requires Treason API version %d or later!",
			REQUIRED_TAPI_VERSION
		);
	}
}

// initialize and setup
public void OnPluginStart()
{
	SDKSetup();
	CreateForwards();
	CreateConVars();
	HookEvents();
	RegisterCommands();
	ClearCustomRoles();
	PrintToServer("[TCR] Treason Custom Roles Loaded!");
}

public void OnMapStart()
{
	AddFolderToDownloadsTable("models/props_cluesystem/custom");
	AddFolderToDownloadsTable("models/player/custom");
	AddFolderToDownloadsTable("materials/hud/playercard/custom");
	AddFolderToDownloadsTable("materials/models/player/custom");
	AddFolderToDownloadsTable("materials/models/props_cluesystem/custom");
}

public Action OnClientPreAdminCheck(int client)
{
	char action1Key[16];
	g_cvAction1Key.GetString(action1Key, sizeof(action1Key));
	ClientCommand(client, "bind \"%s\" \"tapi_action1\"", action1Key);
	
	if (!IsFakeClient(client))
	{
		QueryClientConVar(client, "cl_downloadfilter", OnDownloadFilterChecked);
	}
	
	return Plugin_Continue;
}

public void OnDownloadFilterChecked
(
	QueryCookie cookie,
	int client,
	ConVarQueryResult result,
	const char[] cvarName,
	const char[] cvarValue
)
{
	if (!IsClientInGame(client)) {return;}
	
	if (result != ConVarQuery_Okay)
	{
		KickClient(client, "Could not verify your multiplayer download settings.");
		return;
	}
	if (!StrEqual(cvarValue, "all", false))
	{
		KickClient(client, "You must allow all custom downloads to play on this server. You can change this under the \"Multiplayer\" settings tab.");
		return;
	}
}

public void OnClientPutInServer(int client)
{
	g_ClientRoles[client] = 0;
	g_ClientClasses[client] = 0;
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnClientDisconnect(int client)
{
	g_ClientRoles[client] = 0;
	g_ClientClasses[client] = 0;
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (!StrEqual(classname, "prop_physics")) {return;}

	RequestFrame(CheckNewPropPhysics, EntIndexToEntRef(entity));
}

public void CheckNewPropPhysics(any ref)
{
	int entity = EntRefToEntIndex(ref);

	if (entity == INVALID_ENT_REFERENCE || !IsValidEntity(entity)) {return;}

	char model[PLATFORM_MAX_PATH];
	GetEntPropString(entity, Prop_Data, "m_ModelName", model, sizeof(model));

	if (!StrEqual(model, "models/props_cluesystem/pole.mdl", false)) {return;}
	
	HandlePoleEntity(entity);

	PrintToServer("[TCR] Debug - Replaced pole model on entity %d", entity);
}

public void SDKSetup()
{
	Handle hGameConf = LoadGameConfigFile("tapi");
	if (hGameConf == null)
	{
		SetFailState("Failed to load gamedata file 'tapi.txt'");
	}
	
	g_hEndRound = DHookCreateFromConf(hGameConf, "EndRound");
	if (g_hEndRound == INVALID_HANDLE)
	{
		SetFailState("Failed to create EndRound detour");
	}

	if (!DHookEnableDetour(g_hEndRound, false, Detour_EndRound))
	{
		SetFailState("Failed to enable EndRound pre-detour");
	}
	
	delete hGameConf;
	if (g_hEndRound == null)
	{
		SetFailState("Failed to run SDKSetup!");
	}
}

public void OnRegisterCustomRoles()
{
	// nothing
}

// shortcut functions
public void CreateForwards()
{
	g_RegisterCustomRolesForward = new GlobalForward("OnRegisterCustomRoles", ET_Ignore);
	g_SoloStoppedRoundEndForward = new GlobalForward("OnSoloStoppedRoundEnd", ET_Ignore, Param_Cell);
	g_SoloWinForward = new GlobalForward("OnSoloWin", ET_Ignore, Param_Cell, Param_Cell);
	g_ClearRolesForward = new GlobalForward("OnClearCustomRoles", ET_Ignore);
	g_AssignedCustomRoleForward = new GlobalForward("OnClientAssignedCustomRole", ET_Ignore, Param_Cell, Param_Cell);
}

public void CreateConVars()
{
	g_cvEnableDeathmatchMusic = FindConVar("tapi_deathmatchmusic");
	
	g_cvDataForceWinActive = CreateConVar("tapi_data_forcewinactive", "0", "Provides the sate of forceWinActive to other plugins.", FCVAR_SPONLY);

	g_cvAction1Key = CreateConVar("tapi_keybind1", "6", "The key used to forcebind console command \"tapi_action1\" for all clients.");
	g_cvMinCustomRolesTraitor = CreateConVar("tapi_cr_min_traitor", "1", "The minimum amount of custom traitor-roles to consider assigning to traitors at round start, when possible.", _, true, 0.0);
	g_cvMinCustomRolesInnocent = CreateConVar("tapi_cr_min_innocent", "1", "The minimum amount of custom innocent-roles to consider assigning to innocents at round start, when possible.", _, true, 0.0);
	g_cvMinCustomRolesSolo = CreateConVar("tapi_cr_min_solo", "1", "The minimum amount of custom solo-roles to consider assigning to innocents at round start, when possible.", _, true, 0.0);
	g_cvMaxCustomRolesTraitor = CreateConVar("tapi_cr_max_traitor", "2", "The maximum amount of custom traitor-roles to consider assigning to traitors at round start, when possible.", _, true, 0.0);
	g_cvMaxCustomRolesInnocent = CreateConVar("tapi_cr_max_innocent", "2", "The maximum amount of custom innocent-roles to consider assigning to innocents at round start, when possible.", _, true, 0.0);
	g_cvMaxCustomRolesSolo = CreateConVar("tapi_cr_max_solo", "1", "The maximum amount of custom solo-roles to consider assigning to innocents at round start, when possible. In any normal game, you likely don't want this to be greater than 1.", _, true, 0.0);
}

public void CreateNatives()
{
	CreateNative("IsClientSoloCustomRole", N_IsClientSoloCustomRole);
	CreateNative("ClearCustomRole", N_ClearCustomRole);
	CreateNative("GetCustomRoleIndex", N_GetCustomRoleIndex);
	CreateNative("GetCustomRoleID", N_GetCustomRoleID);
	CreateNative("IsCustomRoleValid", N_IsCustomRoleValid);
	CreateNative("SetClientCustomRole", N_SetClientCustomRole);
	CreateNative("ResetClientCustomRole", N_ResetClientCustomRole);
	CreateNative("GetClientCustomRoleIndex", N_GetClientCustomRoleIndex);
	CreateNative("ForceEndRound", N_ForceEndRound);
	CreateNative("RegisterCustomRole", N_RegisterCustomRole);
}

public void HookEvents()
{
	HookEvent("preround_start", E_PreRoundStart);
	HookEvent("round_start", E_RoundStartPre, EventHookMode_Pre);
	HookEvent("round_start", E_RoundStartPost, EventHookMode_Post);
	HookEvent("round_end", E_RoundEnd, EventHookMode_Pre);
	HookEvent("role_revealed", E_AllRoleRevealEvents, EventHookMode_Pre);
	HookEvent("first_body_found", E_AllRoleRevealEvents, EventHookMode_Pre);
	HookEvent("first_role_revealed", E_AllRoleRevealEvents, EventHookMode_Pre);
	HookEvent("ability_resuscitate_used", E_Resuscitate, EventHookMode_Post);
	HookEvent("ability_revive_used", E_Revive, EventHookMode_Post);
	HookEvent("last_innocent", E_LastInnocent, EventHookMode_Pre);
	HookEvent("player_class", E_PlayerChangeClass, EventHookMode_Post);
	//HookEvent("ability_resus_detective_used", E_ResuscitateDetective);
	//HookEvent("ability_resuscitate_used", E_Resuscitate);
}

public void RegisterCommands()
{
	RegConsoleCmd("tapi_action1", CmdAction1);

	//temp
	RegAdminCmd("sm_getcr", CmdGetCustomRole, ADMFLAG_ROOT);
	RegAdminCmd("sm_setcr", CmdSetCustomRole, ADMFLAG_ROOT);
	RegAdminCmd("tapi_listcr", CmdListCustomRoles, ADMFLAG_ROOT);
	RegAdminCmd("sm_listcr", CmdListCustomRoles, ADMFLAG_ROOT);
	
	RegAdminCmd("tcr_get", CmdGetCustomRole, ADMFLAG_ROOT);
	RegAdminCmd("tcr_list", CmdListCustomRoles, ADMFLAG_ROOT);
}

//EVENTS
public void E_PreRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if(forceWinActive)
	{
		//in the case this is accidentally true, set to false
		forceWinActive = false;
		g_cvDataForceWinActive.SetInt(0);
	}
	//reset global bool for whether last_innocent has already happened in the round
	g_lastInnocentTriggeredThisRound = false;
	//unassign all the customroles from clients
	ClearClientCustomRoles();
	//wipe all the registered roles
	ClearCustomRoles();
	//tell all the customrole plugins to register their roles
	PrintToServer("[TCR] Calling Global Forward \"OnRegisterCustomRoles()\"...");
	Call_StartForward(g_RegisterCustomRolesForward);
	Call_Finish();
}

public void E_RoundStartPre(Event event, const char[] name, bool dontBroadcast)
{
	bool isCarnage = event.GetBool("iscarnage");
	if(!isCarnage)
	{
		for(int i = 1;i <= MaxClients; i++)
		{
			if(!IsClientInGame(i)) {continue;}
			
			g_ClientClasses[i] = GetEntProp(i, Prop_Send, "m_iClass");
		}
	}
}

public void E_RoundStartPost(Event event, const char[] name, bool dontBroadcast)
{
	TempDisableRatingPunishments();
	ResetAllKarma();
	
	bool isCarnage = event.GetBool("iscarnage");
	if(!isCarnage)
	{
		AssignCustomRoles();
		
		if(g_HudTimer == INVALID_HANDLE)
		{
			g_HudTimer = CreateTimer(2.0, Timer_HudCustomRoles, _, TIMER_REPEAT);
		}
	}
}

public Action E_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if(g_HudTimer != INVALID_HANDLE)
	{
		KillTimer(g_HudTimer);
		g_HudTimer = INVALID_HANDLE;
	}
	
	if(forceWinActive)
	{
		//reset it so we don't accidentally do this again
		forceWinActive = false;
		g_cvDataForceWinActive.SetInt(0);
		if(endConditionOverride != -1)
		{
			SetEventInt(event, "reason", endConditionOverride);
			endConditionOverride = -1;
		}
		if(potrOverride != -1)
		{
			int userid = GetClientUserId(potrOverride);
			SetEventInt(event, "potr_userid", userid);
			potrOverride = -1;
		}
		if(winnerOverride != -1)
		{
			SetEventInt(event, "winner", winnerOverride);
			winnerOverride = -1;
		}
		ClearClientCustomRoles();
		ClearCustomRoles();
		return Plugin_Changed;
	}
	ClearClientCustomRoles();
	ClearCustomRoles();
	return Plugin_Continue;
}

public Action E_AllRoleRevealEvents(Event event, const char[] name, bool dontBroadcast)
{
	int clientid = event.GetInt("userid");
	int client = GetClientOfUserId(clientid);
	if(IsClientSoloCustomRole(client))
	{
		event.SetInt("role", 5);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	//if dmg will kill them
	if (victim != 0 && damage >= GetClientHealth(victim))
	{
		int user = GetClientUserId(victim);
		CreateTimer(0.1, Timer_HandleClientDeath, user);
	}
	
	return Plugin_Continue;
}

public Action E_LastInnocent(Event event, const char[] name, bool dontBroadcast)
{
	if(g_lastInnocentTriggeredThisRound)
	{return Plugin_Handled;}

	int soloLastAlive = IsSurvivorSoloLastAlive();
	if (soloLastAlive != 0)
	{
		SoloWin(soloLastAlive);
		return Plugin_Handled;
	}
	
	bool innocentAlive = false;
	for(int i = 1;i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) {continue;}
		
		any role = GetClientRole(i);
		// find if there is an alive innocent type
		// (because solo is technically an innocent ID and the handler calling the event doesnt know that, so we have to cancel it if its wrong)
		if(role == TR_Innocent || role == TR_Detective || role == TR_Doctor)
		{
			innocentAlive = true;
			break;
		}
	}
	
	if(!innocentAlive)
	{return Plugin_Handled;}
	
	g_lastInnocentTriggeredThisRound = true;
	return Plugin_Continue;
}

public void E_Resuscitate(Event event, const char[] name, bool dontBroadcast)
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || GetClientRole(i) == TR_None || GetClientRole(i) == TR_Ghost || IsClientZombie(i)) {continue;}
		
		int roleIndex = GetClientCustomRoleIndex(i);
		if(!IsCustomRoleValid(roleIndex)) {continue;}
		
		// find temp disabled custom role clients (non-zombie)
		if(g_TempDisabledClients[i])
		{
			//re-enable them
			g_TempDisabledClients[i] = false;
			InitClientCustomRole(i);
		}
	}
}

public void E_Revive(Event event, const char[] name, bool dontBroadcast)
{
	//unused
}

public void E_PlayerChangeClass(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int newClass = event.GetInt("class");
	
	if(!IsClientInGame(client)) {return;}
	
	g_ClientClasses[client] = newClass;
}

//COMMANDS
public Action CmdAction1(int client, int args)
{
	//make forward here
	return Plugin_Handled;
}

public Action CmdGetCustomRole(int client, int args)
{
	int roleIndex = GetClientCustomRoleIndex(client);
	PrintToChat(client, "CustomRoleIndex: %d", roleIndex);
	return Plugin_Handled;
}

public Action CmdSetCustomRole(int client, int args)
{
	int roleIndex = GetCmdArgInt(1);
	g_ClientRoles[client] = roleIndex;
	PrintToChat(client, "CustomRoleIndex: %d", roleIndex);
	return Plugin_Handled;
}

public Action CmdListCustomRoles(int client, int args)
{
	for(int i = 0;i < MAXCUSTOMROLES; i++)
	{
		if(g_CustomRoles[i].id[0] != '\0')
		{
			char id[32];
			char displayName[32];
			strcopy(id, sizeof(id), g_CustomRoles[i].id);
			strcopy(displayName, sizeof(displayName), g_CustomRoles[i].displayName);
			PrintToConsole(client, "### %s ###", displayName);
			PrintToConsole(client, "Index: %d", i);
			PrintToConsole(client, "ID: %s", id);
		}
	}
	return Plugin_Handled;
}

// custom role handler functions
public void ClearCustomRoles()
{
	for(int i = 0;i < MAXCUSTOMROLES; i++)
	{
		g_CustomRoles[i].id[0] = '\0';
	}
	PrintToServer("[TCR] Calling Global Forward \"OnClearCustomRoles()\"...");
	Call_StartForward(g_ClearRolesForward);
	Call_Finish();
}

public void ClearClientCustomRoles()
{
	for(int i = 1;i <= MaxClients; i++)
	{
		g_TempDisabledClients[i] = false;
		int customRole = g_ClientRoles[i];
		if(customRole != 0 && IsClientInGame(i))
		{
			any class = GetEntProp(i, Prop_Send, "m_iClass");
			if(class != g_ClientClasses[i] && class == g_CustomRoles[customRole].underlyingClass)
			{
				SetEntProp(i, Prop_Send, "m_iClass", g_ClientClasses[i]);
			}
		}
		g_ClientRoles[i] = 0;
	}
}

public any N_IsClientSoloCustomRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client > 0 && client <= MaxClients && IsClientInGame(client))
	{
		//get the CustomRole enum struct data
		CustomRole role;
		role = g_CustomRoles[GetClientCustomRoleIndex(client)];
		
		if(role.underlyingRole == TR_Solo)
		{return true;}
	}
	return false;
}

public void N_ClearCustomRole(Handle plugin, int numParams)
{
	int roleIndex = GetNativeCell(1);
	if(IsCustomRoleValid(roleIndex))
	{
		g_CustomRoles[roleIndex].id[0] = '\0';
	}
}

public int N_RegisterCustomRole(Handle plugin, int numParams)
{
	if(numParams<24)
	{return -1;}
	char id[32];
	if(GetNativeString(1, id, 32) != SP_ERROR_NONE) {PrintToServer("[TCR] Debug - N_RegisterCustomRole failed at parameter 1!"); return -1;}
	char displayName[32];
	if(GetNativeString(2, displayName, 32) != SP_ERROR_NONE) {PrintToServer("[TCR] Debug - N_RegisterCustomRole failed at parameter 2!"); return -1;}
	
	any underlyingRole = GetNativeCell(3);
	any underlyingClass = GetNativeCell(4);
	int prevalence = GetNativeCell(5);
	int weight = GetNativeCell(6);
	int minPlayers = GetNativeCell(7);
	int maxPlayers = GetNativeCell(8);
	int minTraitors = GetNativeCell(9);
	int minInnocents = GetNativeCell(10);
	bool requireDetective = GetNativeCell(11);
	bool requireDoctor = GetNativeCell(12);
	
	int maxHealthBonus = GetNativeCell(13);
	
	bool displayAboveText = GetNativeCell(14);
	int roleColor[3];
	if(GetNativeArray(15, roleColor, 3) != SP_ERROR_NONE) {PrintToServer("[TCR] Debug - N_RegisterCustomRole failed at parameter 15!"); return -1;}
	int roleTextBrightness = GetNativeCell(16);
	char playerModel[PLATFORM_MAX_PATH];
	if(GetNativeString(17, playerModel, PLATFORM_MAX_PATH) != SP_ERROR_NONE) {PrintToServer("[TCR] Debug - N_RegisterCustomRole failed at parameter 17!"); return -1;}
	bool useClassPlayerModels = GetNativeCell(18);
	char poleModel[PLATFORM_MAX_PATH];
	if(GetNativeString(19, poleModel, PLATFORM_MAX_PATH) != SP_ERROR_NONE) {PrintToServer("[TCR] Debug - N_RegisterCustomRole failed at parameter 19!"); return -1;}
	
	bool discardRoleAbilities = GetNativeCell(20);
	bool discardRoleGadgets = GetNativeCell(21);
	bool keepClassAbility = GetNativeCell(22);
	any abilities[3];
	if(GetNativeArray(23, abilities, 3) != SP_ERROR_NONE) {PrintToServer("[TCR] Debug - N_RegisterCustomRole failed at parameter 23!"); return -1;}
	any gadgets[2];
	if(GetNativeArray(24, gadgets, 2) != SP_ERROR_NONE) {PrintToServer("[TCR] Debug - N_RegisterCustomRole failed at parameter 24!"); return -1;}
	bool winIfLastAlive = GetNativeCell(25);
	
	return RegCustomRole
	(
		id,
		displayName,
		
		underlyingRole,
		underlyingClass,
		prevalence,
		weight,
		minPlayers,
		maxPlayers,
		minTraitors,
		minInnocents,
		requireDetective,
		requireDoctor,
		
		maxHealthBonus,
		
		displayAboveText,
		roleColor,
		roleTextBrightness,
		playerModel,
		useClassPlayerModels,
		poleModel,
		
		discardRoleAbilities,
		discardRoleGadgets,
		keepClassAbility,
		abilities,
		gadgets,
		
		winIfLastAlive
	);
}

public int RegCustomRole
(
	const char[] id,
	const char[] displayName,
	
	treasonRole underlyingRole,
	treasonClass underlyingClass,
	int prevalence,
	int weight,
	int minPlayers,
	int maxPlayers,
	int minTraitors,
	int minInnocents,
	bool requireDetective,
	bool requireDoctor,
	
	int maxHealthBonus,
	
	bool displayAboveText,
	int roleColor[3],
	int roleTextBrightness,
	const char[] playerModel,
	bool useClassPlayerModels,
	const char[] poleModel,
	
	bool discardRoleAbilities,
	bool discardRoleGadgets,
	bool keepClassAbility,
	treasonAbility abilities[3],
	treasonGadget gadgets[2],
	
	bool winIfLastAlive
)
{
	//check if this ID is already registered
	for (int i = 1; i < MAXCUSTOMROLES; i++)
	{
		if(StrEqual(g_CustomRoles[i].id, id, false))
		{
			PrintToServer("[TCR] Debug - Duplicate custom role ID \"%s\".", id);
			return -1;
		}
	}
	
	//iterate to find empty slot
	for (int i = 1; i < MAXCUSTOMROLES; i++)
	{
		if (!IsCustomRoleValid(i))
		{
			//check for invalid values
			if(id[0] == '\0')
			{
				PrintToServer("[TCR] A Custom Role tried to register with invalid text ID! This custom role will not be registered.");
				return -1;
			}
			if(displayName[0] == '\0')
			{
				PrintToServer("[TCR] A Custom Role tried to register with invalid displayName! This custom role will not be registered.");
				return -1;
			}
			if(underlyingRole != TR_Innocent && underlyingRole != TR_Traitor && underlyingRole != TR_Solo)
			{
				PrintToServer("[TCR] Custom Role ID \"%s\" tried to register with invalid underlyingRole! This custom role will not be registered.", id);
				return -1;
			}
			if(underlyingClass != TC_Light && underlyingClass != TC_Med && underlyingClass != TC_Heavy && underlyingClass != TC_None)
			{
				PrintToServer("[TCR] Custom Role ID \"%s\" tried to register with invalid underlyingClass! If you wish to not use an underlyingClass, use TC_None or TC_Invalid. This custom role will not be registered.", id);
				return -1;
			}
			
			//indentification
			strcopy(g_CustomRoles[i].id, sizeof(g_CustomRoles[].id), id);
			strcopy(g_CustomRoles[i].displayName, sizeof(g_CustomRoles[].displayName), displayName);
			
			//customrole handler data
			g_CustomRoles[i].underlyingRole = underlyingRole;
			g_CustomRoles[i].underlyingClass = underlyingClass;
			g_CustomRoles[i].prevalence = prevalence;
			g_CustomRoles[i].weight = weight;
			g_CustomRoles[i].minPlayers = minPlayers;
			g_CustomRoles[i].maxPlayers = maxPlayers;
			g_CustomRoles[i].minTraitors = minTraitors;
			g_CustomRoles[i].minInnocents = minInnocents;
			g_CustomRoles[i].requireDetective = requireDetective;
			g_CustomRoles[i].requireDoctor = requireDoctor;
			
			//stats
			g_CustomRoles[i].maxHealthBonus = maxHealthBonus;
			
			g_CustomRoles[i].displayAboveText = displayAboveText;
			//roleColor
			g_CustomRoles[i].roleColor[0] = roleColor[0];
			g_CustomRoles[i].roleColor[1] = roleColor[1];
			g_CustomRoles[i].roleColor[2] = roleColor[2];
			//roleTextBrightness
			g_CustomRoles[i].roleTextBrightness = roleTextBrightness;
			
			//models
			strcopy(g_CustomRoles[i].playerModel, sizeof(g_CustomRoles[].playerModel), playerModel);
			g_CustomRoles[i].useClassPlayerModels = useClassPlayerModels;
			strcopy(g_CustomRoles[i].poleModel, sizeof(g_CustomRoles[].poleModel), poleModel);
			
			//doohickeys
			g_CustomRoles[i].discardRoleAbilities = discardRoleAbilities;
			g_CustomRoles[i].discardRoleGadgets = discardRoleGadgets;
			g_CustomRoles[i].keepClassAbility = keepClassAbility;
			g_CustomRoles[i].abilities[0] = abilities[0];
			g_CustomRoles[i].abilities[1] = abilities[1];
			g_CustomRoles[i].abilities[2] = abilities[2];
			g_CustomRoles[i].gadgets[0] = gadgets[0];
			g_CustomRoles[i].gadgets[1] = gadgets[1];
			
			//extra win conditions
			g_CustomRoles[i].winIfLastAlive = winIfLastAlive;

			//precache playerModel
			if(!useClassPlayerModels && !StrEqual(playerModel, "default", true) && !IsModelPrecached(playerModel))
			{
				if(PrecacheModel(playerModel, true) == 0)
				{PrintToServer("[TCR] Invalid model path in custom role \"%s\"! Register this custom role with playerModel \"default\" if you do not want to use a custom playermodel!", id);}
			}
			//or precache class playerModels
			else if(useClassPlayerModels && !StrEqual(playerModel, "default", true))
			{
				PrecacheClassModels(playerModel);
			}
			if(!StrEqual(poleModel, "default", true) && !IsModelPrecached(poleModel))
			{
				if(PrecacheModel(poleModel, true) == 0)
				{PrintToServer("[TCR] Invalid model path in custom role \"%s\"! Register this custom role with poleModel \"default\" if you do not want to use a custom pole model!", id);}
			}
			
			PrintToServer("[TCR] Custom role \"%s\" assigned to CustomRoleID %d.", id, i);
			return i;
		}
	}
	return -1;
}

public void PrecacheClassModels(const char[] playerModel)
{
	char lightPath[PLATFORM_MAX_PATH];
	char mediumPath[PLATFORM_MAX_PATH];
	char heavyPath[PLATFORM_MAX_PATH];
	Format(lightPath, sizeof(lightPath), "%s%s", playerModel, "_light.mdl");
	Format(mediumPath, sizeof(mediumPath), "%s%s", playerModel, "_medium.mdl");
	Format(heavyPath, sizeof(heavyPath), "%s%s", playerModel, "_heavy.mdl");
	
	if
	(
		IsModelPrecached(lightPath)
	&&	IsModelPrecached(mediumPath)
	&&	IsModelPrecached(heavyPath)
	)
	{return;}
	else if
	(
		PrecacheModel(lightPath, true) == 0
	||	PrecacheModel(mediumPath, true) == 0
	||	PrecacheModel(heavyPath, true) == 0
	)
	{PrintToServer("[TCR] Invalid class model prefix path or missing .mdl files \"%s\"! Your prefix path should NOT end in .mdl and should be valid when \"_light.mdl\", \"_medium.mdl\", and \"_heavy.mdl\" are appended to the end.", playerModel);}
}

public int N_GetCustomRoleIndex(Handle plugin, int numParams)
{
	char id[32];
	if(GetNativeString(1, id, 32) == SP_ERROR_NONE)
	{
		for(int i = 0;i < MAXCUSTOMROLES; i++)
		{
			if(StrEqual(g_CustomRoles[i].id, id, false))
			{
				return i;
			}
		}
	}
	return -1;
}

public any N_GetCustomRoleID(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	int maxlen = GetNativeCell(3);

	if(IsCustomRoleValid(index))
	{
		SetNativeString(2, g_CustomRoles[index].id, maxlen, true);
		return true;
	}

	return false;
}

public any N_IsCustomRoleValid(Handle plugin, int numParams)
{
	int index = GetNativeCell(1);
	if(index > 0 && index < MAXCUSTOMROLES && g_CustomRoles[index].id[0] != '\0')
	{
		return true;
	}
	return false;
}

public any N_SetClientCustomRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	int customRoleIndex = GetNativeCell(2);
	if(IsCustomRoleValid(customRoleIndex) && client > 0 && IsClientInGame(client))
	{
		g_ClientRoles[client] = customRoleIndex;
		Call_StartForward(g_AssignedCustomRoleForward);
		Call_PushCell(client);
		Call_PushCell(customRoleIndex);
		Call_Finish();
		return true;
	}
	return false;
}

public void N_ResetClientCustomRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	g_ClientRoles[client] = 0;
}

public int N_GetClientCustomRoleIndex(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return g_ClientRoles[client];
}


public any N_ForceEndRound(Handle plugin, int numParams)
{
	if(numParams < 2) {return false;}
	any endCondition = GetNativeCell(1);
	int winner = GetNativeCell(2);
	if(endCondition > 0 && endCondition <= 4)
	{
		switch(endCondition)
		{
			case TE_TeamWin:
			{
				if(winner != 1 && winner != 2) {PrintToServer("[TCR] Debug - ForceEndRound provided winning team \"%d\" is invalid.", winner); return false;}
				ForceWin(winner);
			}
			case TE_Deathmatch:
			{
				if(g_cvEnableDeathmatchMusic != null && g_cvEnableDeathmatchMusic.IntValue == 0)
				{
					//validate winner client
					if(winner <= 0 || winner > MaxClients || !IsClientInGame(winner)) {PrintToServer("[TCR] Debug - ForceEndRound provided deathmatch winner client \"%d\" is invalid.", winner); return false;}
					//set endCondition to None/Invalid
					endConditionOverride = 0;
					//potr is winner client
					potrOverride = winner;
					//set winnerOverride to invalid team 4
					winnerOverride = 4;
					//mp_forcewin 0 (no team)
					ForceWin(0);
					//send annihilation message
					PrintToChatAll("\x07FF7700%N\x07FFFFFF has survived the carnage round!", winner);
				}
				else
				{
					//validate winner client
					if(winner <= 0 || winner > MaxClients || !IsClientInGame(winner)) {PrintToServer("[TCR] Debug - ForceEndRound provided deathmatch winner client \"%d\" is invalid.", winner); return false;}
					//set endCondition to Deathmatch
					endConditionOverride = 2;
					//set winnerOverride to provided winner
					winnerOverride = winner;
					//mp_forcewin 0 (no team)
					ForceWin(0);
				}
			}
			case TE_Time:
			{
				//validate winner team
				if(winner < 0 || winner > 2) {PrintToServer("[TCR] Debug - ForceEndRound provided winning-by-time team \"%d\" is invalid.", winner); return false;}
				//set endCondition to Time
				endConditionOverride = 3;
				//mp_forcewin (winner)
				ForceWin(winner);
			}
			case TE_Solo:
			{
				if(winner <= 0 || winner > MaxClients || !IsClientInGame(winner)) {PrintToServer("[TCR] Debug - ForceEndRound provided solo winner client \"%d\" is invalid.", winner); return false;}
				//set endCondition to None/Invalid
				endConditionOverride = 0;
				//potr is winner client
				potrOverride = winner;
				//mp_forcewin 0 (no team)
				ForceWin(0);
				//customrole plugins are responsible for creating their own win text and notifications
			}
		}
	}
	else
	{PrintToServer("[TCR] Debug - ForceEndRound provided endCondition \"%d\" is invalid.", endCondition); return false;}
	if(forceWinActive)
	{
		g_cvDataForceWinActive.SetInt(1);
		PrintToServer("[TCR] ForceEndRound called with endCondition \"%d\" and winner \"%d\".", endCondition, winner);
		return true;
	}
	PrintToServer("[TCR] Debug - ForceEndRound FAILED with endCondition \"%d\" and winner \"%d\".", endCondition, winner);
	return false;
}

public Action Timer_HudCustomRoles(Handle timer)
{
	//might as well check this here instead of creating another timer
	int soloLastAlive = IsSurvivorSoloLastAlive();
	if (soloLastAlive != 0)
	{
		SoloWin(soloLastAlive);
	}
	
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && (GetClientState(i) == 0 || GetClientState(i) == 5) && IsCustomRoleValid(GetClientCustomRoleIndex(i)))
		{
			int roleIndex = GetClientCustomRoleIndex(i);
			if(roleIndex>0 && !g_TempDisabledClients[i])
			{
				CustomRole role;
				role = g_CustomRoles[roleIndex];
				
				//display ui elements
				DisplayCustomRoleText(i, role);
			}
			
			//check to make sure this custom role is actually being enforced
			//this disables zombie traitors that have unintended custom roles still
			int iRoleId = GetClientRoleID(i);
			int underlyingRoleID;
			switch(g_CustomRoles[roleIndex].underlyingRole)
			{
				case TR_Innocent: underlyingRoleID = 1;
				case TR_Traitor: underlyingRoleID = 2;
				case TR_Solo: underlyingRoleID = 1;
			}
			//if roleid != intended && roleid != annihilation (solo dead)
			if(iRoleId != underlyingRoleID && iRoleId != 5)
			{g_ClientRoles[i] = 0;}
		}
	}
	return Plugin_Continue;
}

public void DisplayCustomRoleText(int client, CustomRole role)
{
	if(GetClientState(client) == 0 || GetClientState(client) == 5)
	{
		if(role.underlyingRole == TR_Solo)
		{
			int brightness = role.roleTextBrightness;
			SetHudTextParams(ROLE_BACKGROUND_X, ROLE_BACKGROUND_Y, 3.0, role.roleColor[0], role.roleColor[1], role.roleColor[2], 127, 0, 0.0, 0.0, 0.0);
			ShowHudText(client, -1, "▄▄▄▄▄");
			SetHudTextParams(ROLE_SOLOTEXT_X, ROLE_TEXT_Y, 3.0, brightness, brightness, brightness, 127, 0, 0.0, 0.0, 0.0);
			ShowHudText(client, -1, "Solo");
		}
		if(role.displayAboveText)
		{
			SetHudTextParams(ROLE_LEFTTEXT_X, ROLE_ABOVETEXT_Y, 3.0, 255, 255, 255, 127, 0, 0.0, 0.0, 0.0);
			ShowHudText(client, -1, role.displayName);
		}
	}
}

public void GiveClassAbility(int client)
{
	switch(GetClientClass(client))
	{
		case TC_Light: AddClientAbility(client, TA_Adrenaline);
		case TC_Med: AddClientAbility(client, TA_Medkit);
		case TC_Heavy: AddClientAbility(client, TA_Shield);
	}
}

public void InitClientCustomRoles()
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && (GetClientState(i) == 0 || GetClientState(i) == 5) && IsCustomRoleValid(GetClientCustomRoleIndex(i)))
		{
			InitClientCustomRole(i);
		}
	}
}

public void InitClientCustomRole(int client)
{
	int roleIndex = GetClientCustomRoleIndex(client);
	if(roleIndex>0 && !g_TempDisabledClients[client])
	{
		CustomRole role;
		role = g_CustomRoles[roleIndex];
		
		if(role.underlyingRole == TR_Solo && GetClientRoleID(client) == TR_Annihilator)
		{
			SetClientRoleID(client, 1);
		}
		
		//set class if desired
		if(role.underlyingClass != TC_None)
		{SetEntProp(client, Prop_Send, "m_iClass", role.underlyingClass);}
		
		//display ui elements
		DisplayCustomRoleText(client, role);
		//discard unwanted abilities and gadgets
		if(role.discardRoleAbilities)
		{ResetClientAbilities(client);}
		if(role.discardRoleGadgets)
		{ResetClientGadgets(client);}
		
		if(role.keepClassAbility)
		{GiveClassAbility(client);}
		
		//add desired abilities and gadgets
		AddClientAbility(client, role.abilities[0]);
		AddClientAbility(client, role.abilities[1]);
		AddClientAbility(client, role.abilities[2]);
		AddClientGadget(client, role.gadgets[0]);
		AddClientGadget(client, role.gadgets[1]);
		
		//set playerModel
		char currentModel[PLATFORM_MAX_PATH];
		GetClientModel(client, currentModel, sizeof(currentModel));
		if(!StrEqual(role.playerModel, "default", true) && !StrEqual(role.playerModel, currentModel, false))
		{
			if(!role.useClassPlayerModels && IsModelPrecached(role.playerModel))
			{
				SetEntityModel(client, role.playerModel);
			}
			else if(role.useClassPlayerModels)
			{
				SetClassModel(client, roleIndex);
			}
		}
	}
}

public void InitClientCustomRoleHealth(int client)
{
	CustomRole role;
	role = g_CustomRoles[GetClientCustomRoleIndex(client)];
		
	//set maxHealth and Health to +Bonus;
	int maxHealth = GetEntProp(client, Prop_Send, "m_iMaxHealth");
	int health = GetEntProp(client, Prop_Send, "m_iHealth");
	SetEntProp(client, Prop_Send, "m_iMaxHealth", maxHealth + role.maxHealthBonus);
	SetEntProp(client, Prop_Send, "m_iHealth", health + role.maxHealthBonus);
}

public void SetClassModel(int client, int roleIndex)
{
	CustomRole role;
	role = g_CustomRoles[roleIndex];
	
	switch(GetClientClass(client))
	{
		case TC_None:
		{
			SetEntityModel(client, role.playerModel);
		}
		case TC_Light:
		{
			char lightPath[PLATFORM_MAX_PATH];
			Format(lightPath, sizeof(lightPath), "%s%s", role.playerModel, "_light.mdl");
			SetEntityModel(client, lightPath);
		}
		case TC_Med:
		{
			char mediumPath[PLATFORM_MAX_PATH];
			Format(mediumPath, sizeof(mediumPath), "%s%s", role.playerModel, "_medium.mdl");
			SetEntityModel(client, mediumPath);
		}
		case TC_Heavy:
		{
			char heavyPath[PLATFORM_MAX_PATH];
			Format(heavyPath, sizeof(heavyPath), "%s%s", role.playerModel, "_heavy.mdl");
			SetEntityModel(client, heavyPath);
		}
	}
}

public void AssignCustomRoles()
{
	//get the convars for later
	int minCustomTraitors = g_cvMinCustomRolesTraitor.IntValue;
	int minCustomInnocents = g_cvMinCustomRolesInnocent.IntValue;
	int minCustomSolos = g_cvMinCustomRolesSolo.IntValue;
	int maxCustomTraitors = g_cvMaxCustomRolesTraitor.IntValue;
	int maxCustomInnocents = g_cvMaxCustomRolesInnocent.IntValue;
	int maxCustomSolos = g_cvMaxCustomRolesSolo.IntValue;
	
	//all this math is unnecessary if we aren't going to end up assigning ANY roles
	if(maxCustomTraitors == 0 && maxCustomInnocents == 0 && maxCustomSolos == 0)
	{return;}

	int validInnocents[MAXPLAYERS+1];
	int countInnocents = 0; //numerical count
	int validTraitors[MAXPLAYERS+1];
	int countTraitors = 0; //numerical count
	int countPlayers = 0; //numerical count
	bool detectiveExists = false;
	bool doctorExists = false;
	
	//iterate through all possible clients
	for(int i = 1;i <= MaxClients; i++)
	{
		//if client is valid for role assign
		if(IsClientInGame(i) && GetClientState(i) == 0)
		{
			//add this player to the playercount
			countPlayers++;
			
			//check client role
			int role = GetClientRole(i);
			switch(role)
			{
				//populate role counts and validClient arrays
				case TR_Innocent: {validInnocents[countInnocents] = i; countInnocents++;}
				case TR_Traitor: {validTraitors[countTraitors] = i; countTraitors++;}
				case TR_Detective: {detectiveExists = true;}
				case TR_Doctor: {doctorExists = true;}
			}
		}
	}
	
	//if theres no players, stop here
	if(countPlayers < 1) {return;}
	
	int roleCandidatesTraitor[MAXCUSTOMROLES];
	int roleCandidatesInnocent[MAXCUSTOMROLES];
	int roleCandidatesSolo[MAXCUSTOMROLES];
	int roleCountTraitor = 0; //numerical count
	int roleCountInnocent = 0; //numerical count
	int roleCountSolo = 0; //numerical count
	int roleCountTotal = 0; //numerical count
	int totalWeightTraitor = 0;
	int totalWeightInnocent = 0;
	int totalWeightSolo = 0;
	int totalWeightTotal = 0;
	//iterate through all possible customroles
	for(int i = 1; i < MAXCUSTOMROLES; i++)
	{
		//if customrole is valid
		if(IsCustomRoleValid(i))
		{
			//get the CustomRole enum struct data
			CustomRole role;
			role = g_CustomRoles[i];
			
			//continue with this candidate if it meets all the conditions and wins the individual diceroll
			if
			(
				//if the weight is valid
				role.weight > 0
				//and the prevalence is valid
			&&	role.prevalence > 0
				//and it wins the individual diceroll
			&&	GetRandomInt(1, role.prevalence) == 1
				//and all the appearance conditions are met
			&&	countPlayers >= role.minPlayers
			&& 	countPlayers <= role.maxPlayers
			&&	countTraitors >= role.minTraitors
			&&	countInnocents >= role.minInnocents
			&&	(!role.requireDetective || detectiveExists)
			&&	(!role.requireDoctor || doctorExists)
			)
			{
				switch(role.underlyingRole)
				{
					case TR_Traitor:
					{
						//make this role a candidate and count it
						roleCandidatesTraitor[roleCountTraitor] = i; roleCountTraitor++;
						//add the role's weight to the total
						totalWeightTraitor += role.weight;
					}
					case TR_Innocent:
					{
						//make this role a candidate and count it
						roleCandidatesInnocent[roleCountInnocent] = i; roleCountInnocent++;
						//add the role's weight to the total
						totalWeightInnocent += role.weight;
					}
					case TR_Solo:
					{
						//make this role a candidate and count it
						roleCandidatesSolo[roleCountSolo] = i; roleCountSolo++;
						//add the role's weight to the total
						totalWeightSolo += role.weight;
					}
					default:
					{
						PrintToServer("[TCR] Custom Role ID \"%s\" uses an invalid underlying role! This custom role will be ignored.", role.id);
					}
				}
				//count this role in the overall total count
				roleCountTotal++;
				//add the role's weight to the overall total weight
				totalWeightTotal += role.weight;
			}
		}
	}
	
	//if theres no role candidates, just forget it bro...
	if(roleCountTotal == 0 || totalWeightTotal <= 0) {return;}

	//clamp the minCustom and maxCustom to the possible values
	maxCustomTraitors = ClampInt(maxCustomTraitors, 0, roleCountTraitor);
	maxCustomInnocents = ClampInt(maxCustomInnocents, 0, roleCountInnocent);
	maxCustomSolos = ClampInt(maxCustomSolos, 0, roleCountSolo);
	minCustomTraitors = ClampInt(minCustomTraitors, 0, maxCustomTraitors);
	minCustomInnocents = ClampInt(minCustomInnocents, 0, maxCustomInnocents);
	minCustomSolos = ClampInt(minCustomSolos, 0, maxCustomSolos);
	
	//create desiredRoleCount ints with 0 as default
	int desiredRolesTraitor = 0;
	int desiredRolesInnocent = 0;
	int desiredRolesSolo = 0;

	if(maxCustomTraitors > 0)
	{
		//select the amount of custom traitor roles we want
		desiredRolesTraitor = GetRandomInt(minCustomTraitors, maxCustomTraitors);
	}
	if(maxCustomInnocents > 0)
	{
		//select the amount of custom innocent roles we want
		desiredRolesInnocent = GetRandomInt(minCustomInnocents, maxCustomInnocents);
	}
	if(maxCustomSolos > 0)
	{
		//select the amount of custom solo roles we want
		desiredRolesSolo = GetRandomInt(minCustomSolos, maxCustomSolos);
	}
	
	//do weighted selection for custom traitor roles, then randomly assign them
	//if desiredRolesTraitor is 0, this loop never runs (no traitor roles are assigned)
	for(int i = 0; i < desiredRolesTraitor; i++)
	{
		//check if there are actually any roles to be selected. if there are none, don't try to assign any
		if(roleCountTraitor < 1 || totalWeightTraitor <= 0) {break;}
		//select a role from the candidate array
		int selectedRole = SelectRandomWeightedRoleCandidate(totalWeightTraitor, roleCountTraitor, roleCandidatesTraitor);
		//panic and break if (selectedRole == -1)
		if(selectedRole == -1) {break;}
		//get the role's index
		int selectedRoleIndex = roleCandidatesTraitor[selectedRole];
		//assign the selected role to a random client from the client candidate array
		int assignedClient = AssignCustomRoleToRandomClientCandidate(selectedRoleIndex, countTraitors, validTraitors);
		//panic and break if (assignedClient == -1)
		if(assignedClient == -1) {break;}
		//init the custom hp bonus of the custom role to this client
		InitClientCustomRoleHealth(validTraitors[assignedClient]);
		//remove the client (that we assigned the custom role to) from the array of valid clients
		validTraitors[assignedClient] = 0;
		//remove the now-selected role from the total weight, in preparation for if (desiredRoles > 1)
		totalWeightTraitor -= g_CustomRoles[selectedRoleIndex].weight;
		//remove the now-selected role from the candidate pool, in preparation for if (desiredRoles > 1)
		roleCandidatesTraitor[selectedRole] = 0;
		//DON'T remove the now-selected role from the candidate count, in preparation for if (desiredRoles > 1)
		//this is because the SelectRandomWeightedRoleCandidate function assumes that the size of the candidates is the same,
		//-just with some array members set to 0 to indicate a removed/ignorable role
	}
	
	//do weighted selection for custom innocent roles, then randomly assign them
	//if desiredRolesInnocent is 0, this loop never runs (no innocent roles are assigned)
	for(int i = 0; i < desiredRolesInnocent; i++)
	{
		//check if there are actually any roles to be selected. if there are none, don't try to assign any
		if(roleCountInnocent < 1 || totalWeightInnocent <= 0) {break;}
		//select a role from the candidate array
		int selectedRole = SelectRandomWeightedRoleCandidate(totalWeightInnocent, roleCountInnocent, roleCandidatesInnocent);
		//panic and break if (selectedRole == -1)
		if(selectedRole == -1) {break;}
		//get the role's index
		int selectedRoleIndex = roleCandidatesInnocent[selectedRole];
		//assign the selected role to a random client from the client candidate array
		int assignedClient = AssignCustomRoleToRandomClientCandidate(selectedRoleIndex, countInnocents, validInnocents);
		//panic and break if (assignedClient == -1)
		if(assignedClient == -1) {break;}
		//init the custom hp bonus of the custom role to this client
		InitClientCustomRoleHealth(validInnocents[assignedClient]);
		//remove the client (that we assigned the custom role to) from the array of valid clients
		validInnocents[assignedClient] = 0;
		//remove the now-selected role from the total weight, in preparation for if (desiredRoles > 1)
		totalWeightInnocent -= g_CustomRoles[selectedRoleIndex].weight;
		//remove the now-selected role from the candidate pool, in preparation for if (desiredRoles > 1)
		roleCandidatesInnocent[selectedRole] = 0;
		//DON'T remove the now-selected role from the candidate count, in preparation for if (desiredRoles > 1)
		//this is because the SelectRandomWeightedRoleCandidate function assumes that the size of the candidates is the same,
		//-just with some array members set to 0 to indicate a removed/ignorable role
	}
	
	//do weighted selection for custom solo roles, then randomly assign them
	//if desiredRolesSolo is 0, this loop never runs (no solo roles are assigned)
	for(int i = 0; i < desiredRolesSolo; i++)
	{
		//check if there are actually any roles to be selected. if there are none, don't try to assign any
		if(roleCountSolo < 1 || totalWeightSolo <= 0) {break;}
		//select a role from the candidate array
		int selectedRole = SelectRandomWeightedRoleCandidate(totalWeightSolo, roleCountSolo, roleCandidatesSolo);
		//panic and break if (selectedRole == -1)
		if(selectedRole == -1) {break;}
		//get the role's index
		int selectedRoleIndex = roleCandidatesSolo[selectedRole];
		//assign the selected role to a random client from the client candidate array
		int assignedClient = AssignCustomRoleToRandomClientCandidate(selectedRoleIndex, countInnocents, validInnocents);
		//panic and break if (assignedClient == -1)
		if(assignedClient == -1) {break;}
		//init the custom hp bonus of the custom role to this client
		InitClientCustomRoleHealth(validInnocents[assignedClient]);
		//remove the client (that we assigned the custom role to) from the array of valid clients
		validInnocents[assignedClient] = 0;
		//remove the now-selected role from the total weight, in preparation for if (desiredRoles > 1)
		totalWeightSolo -= g_CustomRoles[selectedRoleIndex].weight;
		//remove the now-selected role from the candidate pool, in preparation for if (desiredRoles > 1)
		roleCandidatesSolo[selectedRole] = 0;
		//DON'T remove the now-selected role from the candidate count, in preparation for if (desiredRoles > 1)
		//this is because the SelectRandomWeightedRoleCandidate function assumes that the size of the candidates is the same,
		//-just with some array members set to 0 to indicate a removed/ignorable role
	}
	
	//now that we are done, init the roles
	InitClientCustomRoles();
	return;
}

public int SelectRandomWeightedRoleCandidate(int totalWeight, int candidateCount, int[] candidates)
{
	//weighted dice roll
	int roll = GetRandomInt(1, totalWeight);
	int running = 0;
	
	//iterate through all role candidates
	for (int c = 0; c < candidateCount; c++)
	{
		int roleIndex = candidates[c];
		if(roleIndex == 0)
		{continue;}
		
		running += g_CustomRoles[roleIndex].weight;
		
		if (roll <= running)
		{return c;}
	}
	return -1;
}

public int AssignCustomRoleToRandomClientCandidate(int customRoleIndex, int candidateCount, int[] candidates)
{
	if(customRoleIndex <= 0)
	{
		return -1;
	}
	if(candidateCount == 0)
	{
		//PrintToServer("[TCR] No valid candidates for Custom Role Index %d.", customRoleIndex);
		return -1;
	}
	
	//make an array that only includes the valid clients
	int validCandidates[MAXPLAYERS+1];
	int validCount = 0;
	for(int c = 0; c < candidateCount; c++)
	{
		int client = candidates[c];
		if(client > 0 && IsClientInGame(client))
		{
			validCandidates[validCount] = client;
			validCount++;
		}
	}
	
	//if no valid candidates, just give up
	if(validCount == 0)
	{return -1;}
	
	//pick a random index of validCandidates
	int randomClientValidCandidate = GetRandomInt(0, validCount-1);
	int randomClient = validCandidates[randomClientValidCandidate];
	
	//if randomClient is recentlyassigned and isnt the only one, roll again
	if(validCount > 1 && g_RecentlySelectedSoloClients[randomClient] && g_CustomRoles[customRoleIndex].underlyingRole == TR_Solo)
	{
		g_RecentlySelectedSoloClients[randomClient] = false;
		randomClientValidCandidate = GetRandomInt(0, validCount-1);
		randomClient = validCandidates[randomClientValidCandidate];
		
		//if randomClient is once again a recentlyassigned one, just reset the entire array
		if(g_RecentlySelectedSoloClients[randomClient])
		{
			for(int i = 1; i <= MaxClients; i++)
			{
				g_RecentlySelectedSoloClients[i] = false;
			}
		}
	}
	
	//find the candidate index that holds the client we are about to return
	int finalClientCandidateIndex = 0;
	for(int c = 0; c < candidateCount; c++)
	{
		int client = candidates[c];
		if(client > 0 && randomClient == client)
		{
			finalClientCandidateIndex = c;
		}
	}
	
	//assign the customrole to the randomly selected index
	SetClientCustomRole(randomClient, customRoleIndex);
	//set this client as recentlyassigned if they are solo
	if(g_CustomRoles[customRoleIndex].underlyingRole == TR_Solo)
	{g_RecentlySelectedSoloClients[randomClient] = true;}
	//fix the bug where innocents are glowing for traitors for whatever reason
	if(g_CustomRoles[customRoleIndex].underlyingRole != TR_Traitor)
	{SetEntProp(randomClient, Prop_Send, "m_bGlowEnabled", 0, 1, 2);}
	
	//return the candidate index of candidates[] that we are assigning a custom role to the client index of
	return finalClientCandidateIndex;
}

//team 0 = no team
//team 1 = innocent
//team 2 = traitor
public void ForceWin(int team)
{
	//if team is invalid, stop here and report to server console.
	if(team < 0 || team > 2) {PrintToServer("[TCR] Debug - ForceWin Invalid Team Input \"%d\"!", team); return;}
	
	//get original flags
	int originalFlags = GetCommandFlags("mp_forcewin");
	PrintToServer("[TCR] Debug - ForceWin originalFlags: %d", originalFlags);
	
	//create modified flags
	int newFlags = originalFlags & ~FCVAR_CHEAT;
	PrintToServer("[TCR] Debug - ForceWin newFlags: %d", newFlags);
	
	//apply modified flags and call mp_forcewin
	SetCommandFlags("mp_forcewin", newFlags);
	ServerCommand("mp_forcewin %d", team);
	
	//set this bool so we know to hook all overrides
	forceWinActive = true;
	g_cvDataForceWinActive.SetInt(1);
	
	//restore flags to original
	SetCommandFlags("mp_forcewin", originalFlags);
	return;
}

public void TempDisableRatingPunishments()
{
	ServerCommand("t_rating_kill_teammate_innocents 0");
	ServerCommand("t_rating_kill_teammate_traitors 0");
}

public void ResetAllKarma()
{
	//rewards
	ServerCommand("t_karma_bear_trap_release 10");
	ServerCommand("t_karma_bomb_defuse 10");
	ServerCommand("t_karma_kill_unconfirmed_teammate 10");
	ServerCommand("t_karma_damage_confirmed_enemy 10");
	ServerCommand("t_karma_detective_reveal 10");
	ServerCommand("t_karma_detective_scan 10");
	ServerCommand("t_karma_healing_doctor 10");
	ServerCommand("t_karma_healing_doctor_threshold 10");
	ServerCommand("t_karma_innocent_reveal 10");
	ServerCommand("t_karma_kill_confirmed_enemy 10");
	ServerCommand("t_karma_power_supply_turn_on 10");
	ServerCommand("t_karma_resuscitate_player 10");
	
	//punishments
	ServerCommand("t_karma_damage_confirmed_teammate 10");
	ServerCommand("t_karma_kill_confirmed_teammate  10");
	ServerCommand("t_karma_kill_unconfirmed_teammate  10");
	
	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;
		
		SetClientKarma(client, 100);
	}
}

int FindClosestRagdollToEntity(int ent)
{
	float maxDistance = 50.0;
	float entPos[3];
	GetEntPropVector(ent, Prop_Send, "m_vecOrigin", entPos);

	int closestRagdoll = INVALID_ENT_REFERENCE;
	float closestDistance = maxDistance;

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		if (IsPlayerAlive(client))
			continue;

		int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");

		if (ragdoll <= MaxClients || !IsValidEntity(ragdoll))
			continue;

		float ragPos[3];
		GetEntPropVector(ragdoll, Prop_Send, "m_vecOrigin", ragPos);

		float distance = GetVectorDistance(entPos, ragPos);

		if (distance < closestDistance)
		{
			closestDistance = distance;
			closestRagdoll = ragdoll;
		}
	}

	return closestRagdoll;
}

public Action Timer_HandleClientDeath(Handle timer, any client)
{
	g_TempDisabledClients[GetClientOfUserId(client)] = true;
	HandleClientRagdoll(GetClientOfUserId(client));
	CheckForLastInnocent();
	CheckForUnnaturalWin();
	return Plugin_Stop;
}

void HandleClientRagdoll(int client)
{
	//check valid client
	if (client <= 0 || client > MaxClients || !IsClientInGame(client)) {return;}
	//get client ragdoll
	int ragdoll = GetEntPropEnt(client, Prop_Send, "m_hRagdoll");
	if (ragdoll <= MaxClients || !IsValidEntity(ragdoll)) {return;}
	
	
	//if client has custom role
	int customRoleIndex = GetClientCustomRoleIndex(client);
	if(customRoleIndex < 1) {return;}
	
	//get customrole
	CustomRole role;
	role = g_CustomRoles[customRoleIndex];
	
	//if custom role is solo
	if(role.underlyingRole == TR_Solo)
	{
		//make ragdoll role redacted
		SetEntProp(ragdoll, Prop_Send, "m_nRole", 6);
		//make client orange
		SetClientRoleID(client, TR_Annihilator);
	}
}

void HandlePoleEntity(int pole)
{
	//find the closest ragdoll to the pole
	int ragdoll = FindClosestRagdollToEntity(pole);
	if (ragdoll <= MaxClients || !IsValidEntity(ragdoll)) {return;}
	//get the owner client of the ragdoll
	int client = GetEntPropEnt(ragdoll, Prop_Send, "m_hOwnerEntity");
	
	//if custom role is valid
	int customRoleIndex = GetClientCustomRoleIndex(client);
	if(customRoleIndex < 1) {return;}
	
	//get customrole
	CustomRole role;
	role = g_CustomRoles[customRoleIndex];
	
	//if custom role has a poleModel
	if(IsModelPrecached(role.poleModel))
	//set the poleModel
	{SetEntityModel(pole, role.poleModel);}
}

public void CheckForLastInnocent()
{
	int innocentCount = 0;
	// count the alive innocents, not including solos
	for(int i = 1;i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) {continue;}
		
		any role = GetClientRole(i);
		if(role == TR_Innocent || role == TR_Detective || role == TR_Doctor)
		{
			innocentCount++;
		}
	}
	
	if(innocentCount == 1)
	{
		Event event = CreateEvent("last_innocent", true);
		event.Fire();
		return;
	}
}

// returns true if any solo role with winIfLastAlive is alive
public int IsSurvivorSoloAlive()
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) {continue;}
		
		int cr = GetClientCustomRoleIndex(i);
		if(IsCustomRoleValid(cr) && GetClientRole(i) == TR_Solo)
		{
			if(g_CustomRoles[cr].winIfLastAlive)
			{
				return i;
			}
		}
	}
	return 0;
}

// returns a client index if a solo role with winIfLastAlive is the last alive
public int IsSurvivorSoloLastAlive()
{
	int playerCount = 0;
	int survivorAlive = 0;
	for(int i = 1;i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) {continue;}
		if(GetClientState(i) != 0 && GetClientState(i) != 5) {continue;}
		
		playerCount++;
		
		int cr = GetClientCustomRoleIndex(i);
		if(IsCustomRoleValid(cr) && GetClientRole(i) == TR_Solo)
		{
			if(g_CustomRoles[cr].winIfLastAlive)
			{
				survivorAlive = i;
			}
		}
	}
	if(playerCount == 1 && survivorAlive != 0)
	{return survivorAlive;}
	
	return 0;
}

public void SoloWin(int client)
{
	forceWinActive = false;
	int customRoleIndex = GetClientCustomRoleIndex(client);
	Call_StartForward(g_SoloWinForward);
	Call_PushCell(client);
	Call_PushCell(customRoleIndex);
	Call_Finish();
	ForceEndRound(TE_Solo, client);
}

public MRESReturn Detour_EndRound(Address pThis, DHookParam hParams)
{
	int winner = DHookGetParam(hParams, 1);
	int reason = DHookGetParam(hParams, 2);
	int arg3 = DHookGetParam(hParams, 3);
	int arg4 = DHookGetParam(hParams, 4);
	int arg5 = DHookGetParam(hParams, 5);
	int arg6 = DHookGetParam(hParams, 6);

	PrintToServer("[TCR] EndRound caught: this=%x winner=%d reason=%d, arg3=%d arg4=%d arg5=%d arg6=%d",
		pThis, winner, reason, arg3, arg4, arg5, arg6);
	
	//start endround logic checks
	int soloLastAlive = IsSurvivorSoloLastAlive();
	int soloAlive = IsSurvivorSoloAlive();
	
	if(forceWinActive)
	{
		//this gets reset in the event call later
		//forceWinActive = false;
		//g_cvDataForceWinActive.SetInt(0);
		
		if(endConditionOverride != -1)
		{
			DHookSetParam(hParams, 2, endConditionOverride);
			reason = endConditionOverride;
			endConditionOverride = -1;
		}
		if(winnerOverride != -1)
		{
			DHookSetParam(hParams, 1, winnerOverride);
			winner = winnerOverride;
			winnerOverride = -1;
		}
		return MRES_ChangedHandled;
	}
	else if (soloLastAlive != 0 && reason != 3) //if soloAlive and reason is NOT time
	{
		SoloWin(soloLastAlive);
		return MRES_Supercede;
	}
	else if(soloAlive != 0 && reason == 1) //if soloAlive and reason is teamwin and theres no forcewin
	{
		if(g_cvDataForceWinActive.IntValue == 0)
		{
			PrintToServer("[TCR] Calling Global Forward \"OnSoloStoppedRoundEnd()\"...");
			Call_StartForward(g_SoloStoppedRoundEndForward);
			Call_PushCell(soloAlive);
			Call_Finish();
		}
		
		int innocentsAlive = 0;
		for(int i = 1;i <= MaxClients; i++)
		{
			if(!IsClientInGame(i)) {continue;}
			
			any role = GetClientRole(i);
			// find if there is an alive innocent type and count them
			if(role == TR_Innocent || role == TR_Detective || role == TR_Doctor)
			{
				innocentsAlive++;
			}
		}
		
		if(innocentsAlive == 1)
		{
			Event newEvent = CreateEvent("last_innocent", true);
			newEvent.Fire();
		}
		
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

void AddFolderToDownloadsTable(const char[] path)
{
    DirectoryListing dir = OpenDirectory(path);

    if (dir == null)
    {
        PrintToServer("[TCR] Failed to open specified directory: %s", path);
        return;
    }

    char entry[PLATFORM_MAX_PATH];
    FileType type;

    while (dir.GetNext(entry, sizeof(entry), type))
    {
        // skip . and ..
        if (entry[0] == '.')
            continue;

        char fullPath[PLATFORM_MAX_PATH];
        FormatEx(fullPath, sizeof(fullPath), "%s/%s", path, entry);

        if (type == FileType_Directory)
        {
            AddFolderToDownloadsTable(fullPath); // recursion
        }
        else if (type == FileType_File)
        {
            AddFileToDownloadsTable(fullPath);
        }
    }

    delete dir;
}

void CheckForUnnaturalWin()
{
	int soloAlive = IsSurvivorSoloAlive();
	int ainnocentsAlive = 0;
	int atraitorsAlive = 0;
	bool annihilation = false;
	for(int i = 1;i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) {continue;}
		
		any role = GetClientRole(i);
		// find if there is an alive innocent type and count them
		if(role == TR_Innocent || role == TR_Detective || role == TR_Doctor)
		{
			ainnocentsAlive++;
		}
		if(role == TR_Traitor)
		{
			atraitorsAlive++;
		}
		if(role == TR_Annihilator)
		{
			annihilation = true;
		}
	}
	
	if(!annihilation && soloAlive == 0 && ainnocentsAlive == 0)
	{
		ForceEndRound(TE_TeamWin, 2);
	}
	else if(!annihilation && soloAlive == 0 && atraitorsAlive == 0)
	{
		ForceEndRound(TE_TeamWin, 1);
	}
}