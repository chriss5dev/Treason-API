# Treason API for SourceMod

*Note that Klaus Veen's Treason is NOT fully supported by SourceMod as of 7/21/2026, and so has no official extension or wrapper.
This is my way of centralizing all of my KVT plugins' most important functions (fetching data from KVT) to make my life easier.*

The first goal of this project is to condense the amount of code required to interact with Treason-exclusive data, which improves readability.
An example of this is fetching a client's Treason role using a single function "GetClientRole()".

The second goal of this project is to remove the need to patch every KVT plugin in the future, replacing it with a single plugin update.

The third (more recent) goal of this project is to expand the modding capabilities of Klaus Veen's Treason in a helpful direction.
Hopefully, this API and its companion plugins will make Treason modding more accessible and open up new possibilities to those who create SourceMod plugins for Treason.

This project was originally made for my own personal use, but I hope people find use in it!

# Custom Roles
## Examples
- [The Lone Wolf](https://github.com/chriss5dev/TCR-LoneWolf)
- [The Jester](https://github.com/chriss5dev/TCR-Jester)
