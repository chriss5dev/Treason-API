[size=+2]_**### TREASON API ###**_[/size]
[size=-1]_**(1.0)**_[/size]
_**### by chriss5 ###**_
[GitHub Repository]("https://github.com/chriss5dev/Treason-API")

*Note that Klaus Veen's Treason is NOT officially supported by SourceMod as of 6/1/2026, and so has no official extension or wrapper.
This is my way of centralizing all of my KVT plugins' most important functions (fetching data from KVT) to make my life easier.*

The first goal of this project is to condense the amount of code required to interact with Treason-exclusive data, which improves readability.
An example of this is fetching a client's TTT role using a single function "GetClientRole()".

The second goal of this project is to remove the need to patch every KVT plugin in the future, replacing it with a single plugin update.

This project is in a very early stage and was originally made for my own personal use, but I hope people find use in it!
------------------------------


---------------
[size=+2]**### NATIVES ###**[/size]
---------------
/* 
Returns the current version of the TAPI plugin as a 6-digit integer.
*/
[highlight]native int TAPI_Version();[/highlight]
---------------
/* 
Returns the scoreboard karma value of a client index as an integer.
Returns -1 if PlayerResourceEntity is invalid.

@param client				The target client index.
@return					The Karma value of the provided client, taken from the netprop supplying the scoreboard.
 */
[highlight]native int GetClientKarma(int client);[/highlight]
---------------
/* 
Returns int 1 if client index is a zombie.
Returns int 0 if client index is normal.
Returns int -1 if PlayerResourceEntity is invalid.

@param client				The target client index.
@return					The Zombie state of the provided client, formatted as described above.
 */
[highlight]native int IsClientZombie(int client);[/highlight]
---------------
/* 
Returns client index's Treason role  as "treasonRole" or "int"
Returns 0 if unassigned/inconclusive.
Depends on client abilities.

@param client				The target client index.
@return					The Treason role of the provided client, formatted as described above.
 */
[highlight]native any GetClientRole(int client);[/highlight]
---------------
/* 
Returns the client index of the Detective client.
Returns 0 if no detective can be found.
"Client 0" errors will occur if ignoring the "no detective" case above.
Depends on GetClientRole().

@return					The index of the round's Detective if one can be found. 0 if none can be found.
 */
[highlight]native int GetDetectiveIndex();[/highlight]
---------------
/* 
Returns the client index of the Detective client.
Returns 0 if no doctor can be found.
"Client 0" errors will occur if ignoring the "no doctor" case above.
Depends on GetClientRole().

@return					The index of the round's Doctor if one can be found. 0 if none can be found.
 */
[highlight]native int GetDoctorIndex();[/highlight]
---------------
/* 
Returns client index's Treason class as "treasonClass" or "int"
Returns 0 if unassigned/inconclusive.
Return is meaningless if annihilation.
Depends on client abilities.

@param client				The target client index.
@return					The Treason class of the provided client, formatted as described above.
 */
[highlight]native any GetClientClass(int client);[/highlight]
---------------
/* 
Returns client index's Treason ability from a specific slot (starting from 0)  as "treasonAbility" or "int"
Returns integer 0 if client index is invalid.

@param client				The target client index.
@param slot				The ability slot to return the value of, starting from 0, max 2. (3 available slots)
 */
[highlight]native any GetClientAbility(int client, int slot);[/highlight]
---------------
/* 
Gets client index's Treason abilities as an int[3] and copies the result to a pre-existing int[3] array.
USE AN INT ARRAY WITH SIZE 3 FOR ALL THE DATA!
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
@param abilities			An int[] to copy the output of this function to. (Total 3 slots)
@param maxlength			The maximum length of the output array. (Your array should ideally always be size 3)
 */
[highlight]native any GetClientAbilities(int client, int[] abilities, int maxlength);[/highlight]
---------------
/* 
Returns client index's Treason gadget from a specific slot (starting from 0)  as "treasonGadget" or "int"
Returns integer 0 if client index is invalid.

@param client				The target client index.
@param slot				The gadget slot to return the value of, starting from 0, max 2. (2 available slots)
 */
[highlight]native any GetClientGadget(int client, int slot);[/highlight]
---------------
/* 
Gets client index's Treason gadgets as an int[2] and copies the result to a pre-existing int[2] array.
USE AN INT ARRAY WITH SIZE 2 FOR ALL THE DATA!
Returns true if successful.
Returns false if client index is invalid.

@param client				The target client index.
@param gadgets			An int[] to copy the output of this function to. (Total 2 slots)
@param maxlength			The maximum length of the output array. (Your array should ideally always be size 2)
 */
[highlight]native any GetClientGadgets(int client, int[] gadgets, int maxlength);[/highlight]
---------------
/* 
Gets the "iscarnage" boolean of "round_start", without having to hook the event and store it manually.
Returns true if it is currently Annihilation.
Returns false if it is not.

@param includePreRound		If true, this function will also return true during the pre-round state, before the Annihilator role is displayed. ("Preparing...")
@return					Returns the current state of Annihilation, as described above.
 */
[highlight]native any GetIsCarnage(bool includePreRound);[/highlight]
---------------

[size=+2]**### ENUMS ###**[/size]

// Assigns role integers to a readable format
[highlight]enum treasonRole[/highlight]
{[color=blue]
	TRole_Unassigned = 0,	TR_None = 0,
	TRole_Innocent = 1,		TR_Innocent = 1,
	TRole_Traitor = 2,		TR_Traitor = 2,
	TRole_Detective = 3,	TR_Detective = 3,
	TRole_Doctor = 4,		TR_Doctor = 4
	TRole_Annihilator = 5, 	TR_Annihilator = 5,
	TRole_Ghost = 6, 		TR_Ghost = 6
[/color]};

// Assigns class integers to a readable format
[highlight]enum treasonClass[/highlight]
{[color=blue]
	TClass_Inconclusive = 0,	TC_None = 0,
	TClass_Light = 1,			TC_Light = 1,
	TClass_Medium = 2,			TC_Med = 2,
	TClass_Heavy = 3,			TC_Heavy = 3
[/color]};

// Assigns ability integers to a readable format
[highlight]enum treasonAbility[/highlight]
{[color=blue]
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
	TAbility_BodyRadar = 13,			TA_BodyRadar = 13
	TAbility_GhostTransform = 14,		TA_Ghost = 14,
	TAbility_GhostRadar = 15,			TA_GhostRadar = 15
[/color]};

// Assigns gadget integers to a readable format
[highlight]enum treasonGadget[/highlight]
{[color=blue]
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
[/color]};
---------------

[size=+2]**### COMMANDS ###**[/size]

// Prints TAPI version to console
[highlight]tapi[/highlight]

// Prints TAPI version to console as an integer
[highlight]tapi_int[/highlight]

// Prints the ability ID of the specified slot to console
// (slots start from 0, theoretical max is 2)
(ADMIN)
[highlight]tapi_getability <slot>[/highlight]

// Prints the gadget ID of a specified slot to console
// (slots start from 0, theoretical max is 1)
(ADMIN)
[highlight]tapi_getgadget <slot>[/highlight]

// Prints the user's role ID to console
(ADMIN)
[highlight]tapi_getrole[/highlight]
---------------

[size=+2]**### CHANGELOG ###**[/size]
[font=courier]
5/20/2026
- initial forum post

5/21/2026
- added enums
- changed name of GetKarma() to GetClientKarma()
- added TAPI_Version() native integer
- treason_api.sp now includes treason.inc for using enums

5/29/2026
- add treason_textpositions.inc
- remove getkarma because nobody has used it probably
- find ghost transform ability id
- find ghost radar ability id
- add ghost treasonRole
- add annihilator treasonRole
- change enums to camelCase for int cast
- add treasonGadget enum
- add GetDetectiveIndex
- add GetDoctorIndex
- add GetIsCarnage
- add GetClientGadget
- add GetClientGadgets
- add GetClientAbilities
- add command tapi_getability
- add command tapi_getgadget
- add command tapi_getrole
- add npp xml
- find treasonGadget values (todo)
- more stuff i forget

5/29/2026 (2)
- got rid of debug bloat i forgot to remove
- fixed typo in treason.inc
- modified sourcemod_treason_dark.xml to not surpass character limit

6/1/2026
- Made a GitHub repo for this project
- Changed version naming convention
- Removed random line breaks from npp XML
- Added GitHub URL to sp file
- Found all treasonGadget values
[/font]
---------------

[size=+2]**### USAGE ###**[/size]

Place "**treason.inc**" inside of your includes folder.

Place "**treason_textpositions.inc**" inside of your includes folder.

Place "**treason_api.smx**" inside of your plugins folder alongside whatever plugin you compile using the include provided.

(Optional) I reccomend you import the "**sourcemod_treason_dark.xml**" as a user-defined language into Notepad++.
- You can find this in the zip file attached.
- This XML adds the natives, enums, and types to the user-defined languages alongside the default SourceMod stuff.
- This XML also adds simple convenience prefixes and functions that weren't styled in the original SourceMod XML I found.
- It is intended for use in **dark mode**.
- - (Settings>Preferences>**Dark Mode**)
- - (Settings>Style Configurator>**Background colour** [SET THIS TO BLACK])
- - **Recommended** for best appearance: (Settings>Style Configurator>**Font name** [SET THIS TO "Cascadia Code"])
---------------
