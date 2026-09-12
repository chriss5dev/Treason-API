# Treason API for SourceMod

*Note that Klaus Veen's Treason does NOT have an official SourceMod extension or abstraction layer as of 9/11/2026.
This project is an abstraction layer that allows SourcePawn to interact with KVT using the built-in `native` system.*

The first goal of this project is to condense the amount of code required to interact with Treason-exclusive data, which improves readability.
An example of this is fetching a client's Treason role using a single function `GetClientRole(client)`.

The second goal of this project is to remove the need to patch every KVT plugin in the future, replacing it with a single plugin update.

The third (more recent) goal of this project is to expand the modding capabilities of Klaus Veen's Treason in a helpful direction.
Hopefully, this API and its companion plugins will make Treason modding more accessible and open up new possibilities to those who create SourceMod plugins for Treason.

This project was originally made for my own personal use, but I hope people find use in it!

# Documentation
https://chriss5dev.github.io/TAPI-docs/  
[TAPI-Docs repository](https://github.com/chriss5dev/TAPI-docs)

# Dependencies
### [SendProxy (TheByKotik)](https://github.com/TheByKotik/sendproxy)
#### Included in all dependent releases.
Required since release 1.5, [SendProxy (TheByKotik)](https://github.com/TheByKotik/sendproxy) is bundled with all applicable releases in the package.zip. It requires a slightly modified `sourcemod/gamedata/sendproxy.txt`, so the easiest way to install it was to include it in all future releases that require it.
