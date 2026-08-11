# Treason API for SourceMod

*Note that Klaus Veen's Treason does NOT have an official SourceMod extension or abstraction layer as of 8/9/2026.
This project is an abstraction layer that allows SourcePawn to interact with KVT using the built-in `native` system.*

The first goal of this project is to condense the amount of code required to interact with Treason-exclusive data, which improves readability.
An example of this is fetching a client's Treason role using a single function `GetClientRole(client)`.

The second goal of this project is to remove the need to patch every KVT plugin in the future, replacing it with a single plugin update.

The third (more recent) goal of this project is to expand the modding capabilities of Klaus Veen's Treason in a helpful direction.
Hopefully, this API and its companion plugins will make Treason modding more accessible and open up new possibilities to those who create SourceMod plugins for Treason.

This project was originally made for my own personal use, but I hope people find use in it!

# Custom Roles
### Examples
- [The Lone Wolf](https://github.com/chriss5dev/TCR-LoneWolf)
- [The Jester](https://github.com/chriss5dev/TCR-Jester)

# TAPI ConVars
`tapi_deathmatchmusic`
- "Enables the 'carend.wav' sound that plays at the end of carnage rounds if not set to 0. Disabling this has minor visual downsides, such as the winner name being '[REDACTED]'. To remedy this, the winner is placed in chat."

# TAPI Commands
### All Players
`tapi`
- Displays the current version of TAPI in the console.
  
`tapi_int`
- Displays the current integer version of TAPI in the console.

### Admin Only
#### These all only affect the calling player. Mostly intended for debugging.
#### `tapi_getability`
#### `tapi_getgadget`
#### `tapi_getroleid`
#### `tapi_getrole`
#### `tapi_getzombie`
#### `tapi_setzombie`
#### `tapi_getkarma`
#### `tapi_setkarma`

# TCR ConVars
`tapi_cr_debug`
- "Displays debugging messages in the server console when set to 1. Primarily intended for custom role development."

`tapi_keybind1`
- "The key used to forcebind console command 'tapi_action1' for all clients."

`tapi_cr_min_traitor`
- "The minimum amount of custom traitor-roles to consider assigning to traitors at round start, when possible."

`tapi_cr_min_innocent`
- "The minimum amount of custom innocent-roles to consider assigning to innocents at round start, when possible."

`tapi_cr_min_solo`
- "The minimum amount of custom solo-roles to consider assigning to innocents at round start, when possible."

`tapi_cr_max_traitor`
- "The maximum amount of custom traitor-roles to consider assigning to traitors at round start, when possible."

`tapi_cr_max_innocent`
- "The maximum amount of custom innocent-roles to consider assigning to innocents at round start, when possible."

`tapi_cr_max_solo`
- "The maximum amount of custom solo-roles to consider assigning to innocents at round start, when possible. In any normal game, you likely don't want this to be greater than 1."

# TCR Commands
### All Players
`tapi_action1`
- Intended to be registered by custom role plugins that wish to automatically bind an action to a player's keyboard.

### Admin Only
#### `tapi_listcr`
- List all the currently registered custom roles.

#### `tcr_list`
- Semantic clone of `tapi_listcr`

#### `sm_listcr`
- Semantic clone of `tapi_listcr`

#### The following only affect the calling player, mostly intended for debugging:
#### `tcr_get`
- Prints the current custom role index of the player.

#### `sm_getcr`
- Semantic clone of `tcr_get`

#### `tcr_set`
- Sets the current custom role index of the player.

#### `sm_setcr`
- Semantic clone of `tcr_set`

# Dependencies
### [SendProxy (TheByKotik)](https://github.com/TheByKotik/sendproxy)
#### Included in all dependent releases.
Required since release 1.5, [SendProxy (TheByKotik)](https://github.com/TheByKotik/sendproxy) is bundled with all releases in the package.zip. It requires a slightly modified `sourcemod/gamedata/sendproxy.txt`, so the easiest way to install it was to include it in all future releases that require it.
