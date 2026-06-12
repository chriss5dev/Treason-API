#pragma semicolon 1
#include <sourcemod>
#include <sdktools>
#include <treason>
#include <chriss5math>
#define MAXCUSTOMROLES 16
 
public Plugin myinfo =
{
	name = "Treason Custom Roles",
	author = "chriss5",
	description = "Creates the illusion of custom roles existing in Klaus Veen's Treason. Included in the Treason API.",
	version = "1.0",
	url = "https://github.com/chriss5dev/Treason-API"
};

GlobalForward g_RegisterCustomRolesForward;

ConVar g_cvMinCustomRolesTraitor;
ConVar g_cvMinCustomRolesInnocent;
ConVar g_cvMinCustomRolesSolo;
ConVar g_cvMaxCustomRolesTraitor;
ConVar g_cvMaxCustomRolesInnocent;
ConVar g_cvMaxCustomRolesSolo;
ConVar g_cvAction1Key;

public CustomRole g_CustomRoles[MAXCUSTOMROLES];
public int g_ClientRoles[MAXPLAYERS+1];
Handle g_HudTimer = INVALID_HANDLE;
public int whiteColor[3];
public treasonAbility emptyAbilities[3];
public treasonGadget emptyGadgets[2];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("Treason Custom Roles");
	CreateNatives();
	
	whiteColor[0] = 255;
	whiteColor[1] = 255;
	whiteColor[2] = 255;
	emptyAbilities[0] = TA_None;
	emptyAbilities[1] = TA_None;
	emptyAbilities[2] = TA_None;
	emptyGadgets[0] = TG_None;
	emptyGadgets[1] = TG_None;
	
	return APLRes_Success;
}

// initialize and setup
public void OnPluginStart()
{
	CreateForwards();
	CreateConVars();
	HookEvents();
	RegisterCommands();
	ClearCustomRoles();
	PrintToServer("[TAPI] Treason Custom Roles Loaded!");
}

public void OnClientPostAdminCheck(int client)
{
	char action1Key[16];
	g_cvAction1Key.GetString(action1Key, sizeof(action1Key));
	ClientCommand(client, "bind \"%s\" \"tapi_action1\"", action1Key);
	PrintToChat(client, "bind \"%s\" \"tapi_action1\"", action1Key);
}

public void OnRegisterCustomRoles()
{
	int reg = RegCustomRole
	(
		// char[] id,
		"lonewolf",
		// char[] displayName,
		"Lone Wolf",
		// int underlyingRole,
		TR_Solo,
		// int prevalence,
		1,
		// int weight,
		1,
		// int minPlayers,
		0,
		// int maxPlayers,
		16,
		// int minTraitors,
		0,
		// int minInnocents,
		0,
		// bool requireDetective,
		false,
		// bool requireDoctor,
		false,
		// bool displayAboveText,
		true,
		// int roleColor[3],
		whiteColor,
		// int roleTextBrightness,
		0,
		// char[] playerModel,
		"models/player/custom/lonewolf/lonewolf.mdl",
		// bool discardRoleAbilities,
		true,
		// bool discardRoleGadgets,
		true,
		// bool keepClassAbility,
		true,
		// int abilities[3],
		emptyAbilities,
		// int gadgets[2]
		emptyGadgets
	);
	PrintToChatAll("return: %d", reg);
}

// shortcut functions
public void CreateForwards()
{
	g_RegisterCustomRolesForward = new GlobalForward("OnRegisterCustomRoles", ET_Ignore);
}

public void CreateConVars()
{
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
	CreateNative("RegisterCustomRole", N_RegisterCustomRole);
}

public void HookEvents()
{
	HookEvent("preround_start", E_PreRoundStart);
	HookEvent("round_start", E_RoundStart, EventHookMode_Post);
	HookEvent("round_end", E_RoundEnd);
	HookEvent("role_revealed", E_AllRoleRevealEvents, EventHookMode_Pre);
	HookEvent("first_body_found", E_AllRoleRevealEvents, EventHookMode_Pre);
	HookEvent("first_role_revealed", E_AllRoleRevealEvents, EventHookMode_Pre);
	//HookEvent("player_death", E_PlayerDeath);
	//HookEvent("ability_resus_detective_used", E_ResuscitateDetective);
	//HookEvent("ability_resuscitate_used", E_Resuscitate);
}

public void RegisterCommands()
{
	RegConsoleCmd("tapi_action1", CmdAction1);

	//temp
	RegAdminCmd("sm_getcr", CmdGetCustomRole, ADMFLAG_ROOT);
	RegAdminCmd("sm_setcr", CmdSetCustomRole, ADMFLAG_ROOT);
	RegAdminCmd("sm_listcr", CmdListCustomRoles, ADMFLAG_ROOT);
	
	RegAdminCmd("tapi_cr_get", CmdGetCustomRole, ADMFLAG_ROOT);
	RegAdminCmd("tapi_cr_list", CmdListCustomRoles, ADMFLAG_ROOT);
}

//EVENTS
public void E_PreRoundStart(Event event, const char[] name, bool dontBroadcast)
{
	//tell all the customrole plugins to register their roles
	ClearCustomRoles();
	PrintToServer("[TAPI] Calling Global Forward \"OnRegisterCustomRoles()\"...");
	Call_StartForward(g_RegisterCustomRolesForward);
	Call_Finish();
}

public void E_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
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

public void E_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	ClearClientCustomRoles();
	ClearCustomRoles();
	
	if(g_HudTimer != INVALID_HANDLE)
	{
		KillTimer(g_HudTimer);
		g_HudTimer = INVALID_HANDLE;
	}
}

public void E_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	//why did i make this? maybe ill use it later
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

//COMMANDS
public Action CmdAction1(int client, int args)
{
	PrintToChat(client, "Used Action1 bind.");
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
			strcopy(id, sizeof(g_CustomRoles[i].id), g_CustomRoles[i].id);
			strcopy(displayName, sizeof(g_CustomRoles[i].displayName), g_CustomRoles[i].displayName);
			PrintToChat(client, "### %s ###", displayName);
			PrintToChat(client, "Index: %d", i);
			PrintToChat(client, "ID: %s", id);
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
}

public void ClearClientCustomRoles()
{
	for(int i = 1;i <= MaxClients; i++)
	{
		g_ClientRoles[i] = 0;
	}
}

public any N_IsClientSoloCustomRole(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if(client > 0 && client <= MaxClients && IsClientInGame(client) && (GetClientState(client) == TS_Default || GetClientState(client) == TS_Injured))
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
	if(numParams<20)
	{return -1;}
	char id[32];
	if(GetNativeString(1, id, 32) != SP_ERROR_NONE) {PrintToServer("[TAPI] Debug - N_RegisterCustomRole failed at parameter 1!"); return -1;}
	char displayName[32];
	if(GetNativeString(2, displayName, 32) != SP_ERROR_NONE) {PrintToServer("[TAPI] Debug - N_RegisterCustomRole failed at parameter 2!"); return -1;}
	
	any underlyingRole = GetNativeCell(3);
	int prevalence = GetNativeCell(4);
	int weight = GetNativeCell(5);
	int minPlayers = GetNativeCell(6);
	int maxPlayers = GetNativeCell(7);
	int minTraitors = GetNativeCell(8);
	int minInnocents = GetNativeCell(9);
	bool requireDetective = GetNativeCell(10);
	bool requireDoctor = GetNativeCell(11);
	
	bool displayAboveText = GetNativeCell(12);
	int roleColor[3];
	if(GetNativeArray(13, roleColor, 3) != SP_ERROR_NONE) {PrintToServer("[TAPI] Debug - N_RegisterCustomRole failed at parameter 13!"); return -1;}
	int roleTextBrightness = GetNativeCell(14);
	char playerModel[PLATFORM_MAX_PATH];
	if(GetNativeString(15, playerModel, PLATFORM_MAX_PATH) != SP_ERROR_NONE) {PrintToServer("[TAPI] Debug - N_RegisterCustomRole failed at parameter 15!"); return -1;}
	
	bool discardRoleAbilities = GetNativeCell(16);
	bool discardRoleGadgets = GetNativeCell(17);
	bool keepClassAbility = GetNativeCell(18);
	any abilities[3];
	if(GetNativeArray(19, abilities, 3) != SP_ERROR_NONE) {PrintToServer("[TAPI] Debug - N_RegisterCustomRole failed at parameter 19!"); return -1;}
	any gadgets[2];
	if(GetNativeArray(20, gadgets, 2) != SP_ERROR_NONE) {PrintToServer("[TAPI] Debug - N_RegisterCustomRole failed at parameter 20!"); return -1;}
	
	return RegCustomRole
	(
		id,
		displayName,
		
		underlyingRole,
		prevalence,
		weight,
		minPlayers,
		maxPlayers,
		minTraitors,
		minInnocents,
		requireDetective,
		requireDoctor,
		
		displayAboveText,
		roleColor,
		roleTextBrightness,
		playerModel,
		
		discardRoleAbilities,
		discardRoleGadgets,
		keepClassAbility,
		abilities,
		gadgets
	);
}

public int RegCustomRole
(
	const char[] id,
	const char[] displayName,
	
	treasonRole underlyingRole,
	int prevalence,
	int weight,
	int minPlayers,
	int maxPlayers,
	int minTraitors,
	int minInnocents,
	bool requireDetective,
	bool requireDoctor,
	
	bool displayAboveText,
	int roleColor[3],
	int roleTextBrightness,
	const char[] playerModel,
	
	bool discardRoleAbilities,
	bool discardRoleGadgets,
	bool keepClassAbility,
	treasonAbility abilities[3],
	treasonGadget gadgets[2]
)
{
	for (int i = 1; i < MAXCUSTOMROLES; i++)
	{
		if (!IsCustomRoleValid(i))
		{
			//check for invalid values
			if(id[0] == '\0')
			{
				PrintToServer("[TAPI] A Custom Role tried to register with invalid text ID! This custom role will not be registered.");
				return -1;
			}
			if(displayName[0] == '\0')
			{
				PrintToServer("[TAPI] A Custom Role tried to register with invalid displayName! This custom role will not be registered.");
				return -1;
			}
			if(underlyingRole != TR_Innocent && underlyingRole != TR_Traitor && underlyingRole != TR_Solo)
			{
				PrintToServer("[TAPI] Custom Role ID \"%s\" tried to register with invalid underlyingRole! This custom role will not be registered.", id);
				return -1;
			}
			
			//indentification
			strcopy(g_CustomRoles[i].id, sizeof(g_CustomRoles[].id), id);
			strcopy(g_CustomRoles[i].displayName, sizeof(g_CustomRoles[].displayName), displayName);
			
			//customrole handler data
			g_CustomRoles[i].underlyingRole = underlyingRole;
			g_CustomRoles[i].prevalence = prevalence;
			g_CustomRoles[i].weight = weight;
			g_CustomRoles[i].minPlayers = minPlayers;
			g_CustomRoles[i].maxPlayers = maxPlayers;
			g_CustomRoles[i].minTraitors = minTraitors;
			g_CustomRoles[i].minInnocents = minInnocents;
			g_CustomRoles[i].requireDetective = requireDetective;
			g_CustomRoles[i].requireDoctor = requireDoctor;
			
			g_CustomRoles[i].displayAboveText = displayAboveText;
			
			//roleColor
			g_CustomRoles[i].roleColor[0] = roleColor[0];
			g_CustomRoles[i].roleColor[1] = roleColor[1];
			g_CustomRoles[i].roleColor[2] = roleColor[2];
			//roleTextBrightness
			g_CustomRoles[i].roleTextBrightness = roleTextBrightness;
			
			//models
			strcopy(g_CustomRoles[i].playerModel, sizeof(g_CustomRoles[].playerModel), playerModel);
			
			//doohickeys
			g_CustomRoles[i].discardRoleAbilities = discardRoleAbilities;
			g_CustomRoles[i].discardRoleGadgets = discardRoleGadgets;
			g_CustomRoles[i].keepClassAbility = keepClassAbility;
			g_CustomRoles[i].abilities[0] = abilities[0];
			g_CustomRoles[i].abilities[1] = abilities[1];
			g_CustomRoles[i].abilities[2] = abilities[2];
			g_CustomRoles[i].gadgets[0] = gadgets[0];
			g_CustomRoles[i].gadgets[1] = gadgets[1];

			//precache
			if(!StrEqual(playerModel, "default", true) && !IsModelPrecached(playerModel))
			{
				if(PrecacheModel(playerModel, true) == 0)
				{PrintToServer("[TAPI] Invalid model or modelpath in custom role \"%s\"! Register this custom role with playerModel \"default\" if you do not want to use a custom playermodel!", id);}
			}
			
			PrintToServer("[TAPI] Custom role \"%s\" assigned to CustomRoleID %d.", id, i);
			return i;
		}
	}
	return -1;
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

public Action Timer_HudCustomRoles(Handle timer)
{
	for(int i = 1;i <= MaxClients; i++)
	{
		if(IsClientInGame(i) && (GetClientState(i) == 0 || GetClientState(i) == 5) && IsCustomRoleValid(GetClientCustomRoleIndex(i)))
		{
			int roleIndex = GetClientCustomRoleIndex(i);
			if(roleIndex>0)
			{
				CustomRole role;
				role = g_CustomRoles[roleIndex];
				
				//display ui elements
				DisplayCustomRoleText(i, role);
			}
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
			int roleIndex = GetClientCustomRoleIndex(i);
			if(roleIndex>0)
			{
				CustomRole role;
				role = g_CustomRoles[roleIndex];
				
				//display ui elements
				DisplayCustomRoleText(i, role);
				//discard unwanted abilities and gadgets
				if(role.discardRoleAbilities)
				{ResetClientAbilities(i); PrintToChatAll("ResetClientAbilities(%d)", i);}
				if(role.discardRoleGadgets)
				{ResetClientGadgets(i); PrintToChatAll("ResetClientGadgets(%d)", i);}
				
				if(role.keepClassAbility)
				{GiveClassAbility(i);}
				
				//add desired abilities and gadgets
				AddClientAbility(i, role.abilities[0]);
				AddClientAbility(i, role.abilities[1]);
				AddClientAbility(i, role.abilities[2]);
				AddClientGadget(i, role.gadgets[0]);
				AddClientGadget(i, role.gadgets[1]);
				
				//set playerModel
				char currentModel[PLATFORM_MAX_PATH];
				GetClientModel(i, currentModel, sizeof(currentModel));
				if(!StrEqual(role.playerModel, "default", true) && !StrEqual(role.playerModel, currentModel, false) && IsModelPrecached(role.playerModel))
				{
					SetEntityModel(i, role.playerModel);
				}
			}
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
						PrintToServer("[TAPI] Custom Role ID \"%s\" uses an invalid underlying role! This custom role will be ignored.", role.id);
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
	if(customRoleIndex <= 0 || candidateCount == 0)
	{
		PrintToServer("[TAPI] Debug - AssignCustomRoleToRandomClientCandidate, either (customRoleIndex %d) or (candidateCount %d) is invalid.", customRoleIndex, candidateCount);
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
	
	//return the candidate index of candidates[] that we are assigning a custom role to the client index of
	return finalClientCandidateIndex;
}
