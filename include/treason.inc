#if defined treason_api_included
  #endinput
#endif
#define treason_api_included
#define TAPI_VERSION_INCLUDE "1.2.1"

#include <treason_textpositions>

// Assigns role integers to a readable format
enum treasonRole
{
	TRole_Unassigned = 0,	TR_None = 0,
	TRole_Innocent = 1,		TR_Innocent = 1,
	TRole_Traitor = 2,		TR_Traitor = 2,
	TRole_Detective = 3,	TR_Detective = 3,
	TRole_Doctor = 4,		TR_Doctor = 4,
	TRole_Annihilator = 5, 	TR_Annihilator = 5,
	TRole_Ghost = 6, 		TR_Ghost = 6,
	TRole_Independent = 7,	TR_Solo = 7
};

// Assigns class integers to a readable format
enum treasonClass
{
	TClass_Invalid = -1,		TC_None = -1,
	TClass_Light = 0,			TC_Light = 0,
	TClass_Medium = 1,			TC_Med = 1,
	TClass_Heavy = 2,			TC_Heavy = 2
};

// Assigns ability integers to a readable format
enum treasonAbility
{
	TAbility_None = 0,					TA_None = 0,
	TAbility_Medkit = 1,				TA_Medkit = 1,
	TAbility_Shield = 2,				TA_Shield = 2,
	TAbility_Adrenaline = 3,			TA_Adrenaline = 3,
	TAbility_ClueRadar = 4,				TA_ClueRadar = 4,
	TAbility_TeamRadar = 5,				TA_TeamRadar = 5,
	TAbility_TraitorRadar = 6,			TA_TRadar = 6,
	TAbility_ZombieRevive = 7,			TA_Zombie = 7,
	TAbility_DetectiveRadar = 8,		TA_DRadar = 8,
	TAbility_DetectiveResuscitate = 9,	TA_DetectiveRes = 9,
	TAbility_RangeHeal = 10,			TA_RangeHeal = 10,
	TAbility_RangeAdrenaline = 11,		TA_RangeAdrenaline = 11,
	TAbility_DoctorResuscitate = 12,	TA_DoctorRes = 12,
	TAbility_BodyRadar = 13,			TA_BodyRadar = 13,
	TAbility_GhostTransform = 14,		TA_Ghost = 14,
	TAbility_GhostRadar = 15,			TA_GhostRadar = 15
};

// Assigns gadget integers to a readable format
enum treasonGadget
{
	TGadget_None = 0,					TG_None = 0,
	TGadget_Bomb = 1,					TG_Bomb = 1,
	TGadget_LethalTaser = 2,			TG_CarnageTaser = 2,
	TGadget_SilencedRevolver = 3,		TG_Revolver = 3,
	TGadget_SpikedBat = 4,				TG_SpikedBat = 4,
	TGadget_Disguise = 5,				TG_Disguise = 5,
	TGadget_BearTrap = 6,				TG_BearTrap = 6,
	TGadget_Landmine = 7,				TG_Landmine = 7,
	TGadget_PoisonDart = 8,				TG_PoisonDart = 8,
	TGadget_SilencedPistol = 9,			TG_Pistol = 9,
	TGadget_Scanner = 10,				TG_Scanner = 10,
	TGadget_StunTaser = 11,				TG_Taser = 11,
	TGadget_HealingStation = 12,		TG_HealingStation = 12
};

// Assigns PlayerState integers to a readable format
enum treasonPlayerState
{
	TPlayerState_Default = 0,				TS_Default = 0,
	TPlayerState_Unknown1 = 1,				TS_Unknown1 = 1,
	TPlayerState_Spectator = 2,				TS_Spectator = 2,
	TPlayerState_FreezeCam = 3,				TS_FreezeCam = 3,
	TPlayerState_Unknown2 = 4,				TS_Unknown2 = 4,
	TPlayerState_Injured = 5,				TS_Injured = 5,
	TPlayerState_Ghost = 6,					TS_Ghost = 6,
	TPlayerState_Unknown3 = 7,				TS_Unknown3 = 7,
	TPlayerState_Unknown4 = 8,				TS_Unknown4 = 8,
	TPlayerState_UIFrozen = 9,				TS_UIFrozen = 9
};

// enum struct
enum struct CustomRole
{
	//indentification
	char id[32];
	char displayName[32];
	
	//customrole handler data
	treasonRole underlyingRole;
	int prevalence;
	int weight;
	int minPlayers;
	int maxPlayers;
	int minTraitors;
	int minInnocents;
	bool requireDetective;
	bool requireDoctor;
	
	//assets and customization
	bool displayAboveText;
	int roleColor[3];
	int roleTextBrightness;
	char playerModel[PLATFORM_MAX_PATH];
	//char poleModel[PLATFORM_MAX_PATH];
	
	//doohickeys
	bool discardRoleAbilities;
	bool discardRoleGadgets; //add to reg
	bool keepClassAbility;
	treasonAbility abilities[3];
	treasonGadget gadgets[2];
}

// TAPI natives

/* 
Returns the current version of the TAPI plugin as a 6-digit integer.
*/
native int TAPI_Version();

/* 
Returns the scoreboard karma value of a client index as an integer.
Returns -1 if PlayerResourceEntity is invalid.

@param client				The target client index.
@return					The Karma value of the provided client, taken from the netprop supplying the scoreboard.
*/
native int GetClientScoreboardKarma(int client);

/* 
Returns the realtime karma value of a client index as an integer.
Returns -1 if client index is invalid.

@param client				The target client index.
@return					The Karma value of the provided client, taken from the server memory.
*/
native int GetClientKarma(int client);

/* 
Sets a client index's realtime karma value.
Returns false if client index is invalid.
Returns true on success.

@param client				The target client index.
@param karma				The desired karma to set, as an integer.
@return					Returns false boolean if client index is invalid.
*/
native any SetClientKarma(int client, int karma);

/* 
Returns int 1 if client index is a zombie.
Returns int 0 if client index is normal.
Returns int -1 if PlayerResourceEntity is invalid.

@param client				The target client index.
@return					The Zombie state of the provided client, formatted as described above.
*/
native int IsClientZombie(int client);

/* 
Sets whether a client is a zombie.
Only valid state values are 0 and 1. (false and true)
Role value 0 will assign the role based on the current role.
Role value 1 will assign the client as a zombie innocent.
Role value 2 will assign the client as a zombie innocent.
Returns false on failure.
Returns true on success.

@param client				The target client index.
@param isZombie			The Zombie state of the provided client, formatted as described above.
@param role				The desired role to assign, formatted as described above.
*/
native any SetClientZombie(int client, int isZombie, int role);

/* 
Returns the PseudoName of a client index as an integer.

@param client				The target client index.
@return					The PseudoName of the provided client as an integer.
*/
native int GetClientPseudoName(int client);

/* 
Overrides the return value of GetClientPseudoName() that the server recieves.
This does not change the "truth" value, but instead replaces the return value of the function responsible for handling the "truthful" PseudoName.
Note that the PseudoName integer corresponds to multiple variants, selected by the player's class.

@param client				The target client index.
@param pseudoName		The desired PseudoName integer.
*/
native void OverrideClientPseudoName(int client, int pseudoName);

/* 
Allows the server to set the PseudoName of this client normally.
Disables the replacements made in OverrideClientPseudoName().
Restores the source of "truth" to the original default logic.

@param client				The target client index.
*/
native void RestoreClientPseudoName(int client);

/* 
Returns the PlayerState of a client index.
Returns -1 if client index is invalid.

@param client				The target client index.
@return						The PlayerState of the provided client, formatted as described above.
*/
native any GetClientState(int client);

/* 
Returns client index's Treason role as "treasonRole" or "int".
Returns 0 (TRole_Unassigned / TR_None) if unassigned.
Values above 5 (TR_Annihilator) are not valid.
This value does not fully dictate the current state or visible role of the player at all times.
If you do not know what this does, use GetClientRole() instead.

@param client				The target client index.
@return					The Treason role of the provided client, formatted as described above.
*/
native any GetClientRoleID(int client);

/* 
Sets a client index's role id on the server.
This does not update the player's role, this only sets the value.
Returns false when a simple failure is detected.
Returns true on success.

@param client				The target client index.
@param client				The desired role to set, as an integer.
@return					Returns false boolean on detected failure.
*/
native any SetClientRoleID(int client, int role);

/* 
Returns client index's Treason role as "treasonRole" or "int".
Returns 0 (TRole_Unassigned / TR_None) if unassigned or spectator.
Detecting a Ghost (6) depends on the Ghost Radar ability existing on the target client index.

@param client				The target client index.
@return					The Treason role of the provided client, formatted as described above.
*/
native any GetClientRole(int client);

/* 
Sets a client index's role.
Returns false when a simple failure is detected.
Returns true on success.
May return true even if the SDKCall fails. (uncommon)

@param client				The target client index.
@param client				The desired role to set, as an integer.
@return					Returns false boolean on detected failure.
*/
native any SetClientRole(int client, int role);

/* 
Returns the client index of the Detective client.
Returns 0 if no detective can be found.
"Client 0" errors will occur if ignoring the "no detective" case above.
Depends on GetClientRole().

@return					The index of the round's Detective if one can be found. 0 if none can be found.
*/
native int GetDetectiveIndex();

/* 
Returns the client index of the Detective client.
Returns 0 if no doctor can be found.
"Client 0" errors will occur if ignoring the "no doctor" case above.
Depends on GetClientRole().

@return					The index of the round's Doctor if one can be found. 0 if none can be found.
*/
native int GetDoctorIndex();

/* 
Returns client index's Treason class as "treasonClass" or "int"
Returns -1 if unassigned/inconclusive.

@param client				The target client index.
@return					The Treason class of the provided client, formatted as described above.
*/
native any GetClientClass(int client);

/* 
Returns client index's Treason ability from a specific slot (starting from 0)  as "treasonAbility" or "int"
Returns integer 0 if client index is invalid.

@param client				The target client index.
@param slot				The ability slot to return the value of, starting from 0, max 2. (3 available slots)
*/
native any GetClientAbility(int client, int slot);

/* 
Gets client index's Treason abilities as an int[3] and copies the result to a pre-existing int[3] array.
USE AN INT ARRAY WITH SIZE 3 FOR ALL THE DATA!
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
@param abilities			An int[] to copy the output of this function to. (Total 3 slots)
@param maxlength			The maximum length of the output array. (Your array should ideally always be size 3)
*/
native any GetClientAbilities(int client, int[] abilities, int maxlength);

/* 
Resets client index's Treason abilities.
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
*/
native any ResetClientAbilities(int client);

/* 
Adds a Treason ability to the given client index.
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
@param ability				The desired ability id as an int.
*/
native any AddClientAbility(int client, int ability);

/* 
Returns client index's Treason gadget from a specific slot (starting from 0)  as "treasonGadget" or "int"
Returns integer 0 if client index is invalid.

@param client				The target client index.
@param slot				The gadget slot to return the value of, starting from 0, max 2. (2 available slots)
*/
native any GetClientGadget(int client, int slot);

/* 
Gets client index's Treason gadgets as an int[2] and copies the result to a pre-existing int[2] array.
USE AN INT ARRAY WITH SIZE 2 FOR ALL THE DATA!
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
@param gadgets			An int[] to copy the output of this function to. (Total 2 slots)
@param maxlength			The maximum length of the output array. (Your array should ideally always be size 2)
*/
native any GetClientGadgets(int client, int[] gadgets, int maxlength);

/* 
Resets client index's Treason gadgets.
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
*/
native any ResetClientGadgets(int client);

/* 
Adds a Treason gadget to the given client index.
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
@param ability				The desired gadget id as an int.
*/
native any AddClientGadget(int client, int gadget);

/* 
Gets the "iscarnage" boolean of "round_start", without having to hook the event and store it manually.
Returns true if it is currently Annihilation.
Returns false if it is not.

@param includePreRound		If true, this function will also return true during the pre-round state, before the Annihilator role is displayed. ("Preparing...")
@return					Returns the current state of Annihilation, as described above.
*/
native any GetIsCarnage(bool includePreRound);

// TAPI Custom Role natives

/* 
Returns true if the provided client index has a solo-based custom role.
Returns false otherwise.
Also returns false if the provided client index is invalid.

@param client				The target client index.
@return					Returns true or false as formatted above.
*/
native any IsClientSoloCustomRole(int client);

/* 
Clears the id of a CustomRole using its custom role index.
This effectively "deletes" a custom role from the internal custom roles array by marking it as invalid.

@param customRoleIndex		The target custom role index.
*/
native void ClearCustomRole(int customRoleIndex);

/* 
Finds the CustomRole index of a CustomRole by searching for a string id.
Returns -1 if no CustomRole can be found.

@param id				The string id to search for.
@return					The resulting CustomRole index.
*/
native int GetCustomRoleIndex(char[] id);

/* 
Gets the CustomRole.id (string) of the given custom role index.
Returns false if the custom role index is invalid.
Returns true on success.

@param customRoleIndex		The target custom role index.
@param result				The a buffer to store the string ID of the target custom role index. MaxSize is 32.
@return					Returns false if the custom role index is invalid.
*/
native bool GetCustomRoleID(int customRoleIndex, char[] result);

/* 
Returns false if the custom role index is invalid.
Returns true otherwise.

@param customRoleIndex		The target custom role index.
@return					Returns false if the custom role index is invalid.
*/
native bool IsCustomRoleValid(int customRoleIndex);

/* 
Sets the CustomRole of a client in memory without fully updating the cosmetics until the next round.
Returns false if the custom role index or client index is invalid.
Returns true on success.

@param client				The target client index.
@param customRoleIndex		The target custom role index.
@return					Returns true on success, or false as formatted above.
*/
native bool SetClientCustomRole(int client, int customRoleIndex);

/* 
Resets the CustomRole of a client in memory to be default (no custom role).

@param client				The target client index.
*/
native void ResetClientCustomRole(int client);

/* 
Gets the CustomRole index of the given client index.
Returns -1 if client index is invalid.
Returns 0 if the client is not assigned a custom role.

@param client				The target client index.
@return					The CustomRole index of the target client.
*/
native int GetClientCustomRoleIndex(int client);

/* 
Registers a CustomRole and returns the CustomRole index.
This is way too bloated to reasonably make documentation for.
I reccomend users just read the parameters, as it should be reasonably self-explanatory.
I also reccomend users to just look at the template role plugin.
*/
native int RegisterCustomRole
(
	char[] id,
	char[] displayName,
	
	int underlyingRole,
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
	char[] playerModel,
	
	bool discardRoleAbilities,
	bool discardRoleGadgets,
	bool keepClassAbility,
	int abilities[3],
	int gadgets[2]
);