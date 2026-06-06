# Treason API for SourceMod
## by chriss5
https://forums.alliedmods.net/showthread.php?p=2844403

*Note that Klaus Veen's Treason is NOT officially supported by SourceMod as of 6/1/2026, and so has no official extension or wrapper.
This is my way of centralizing all of my KVT plugins' most important functions (fetching data from KVT) to make my life easier.*

The first goal of this project is to condense the amount of code required to interact with Treason-exclusive data, which improves readability.
An example of this is fetching a client's Treason role using a single function "GetClientRole()".

The second goal of this project is to remove the need to patch every KVT plugin in the future, replacing it with a single plugin update.

This project is in a very early stage and was originally made for my own personal use, but I hope people find use in it!