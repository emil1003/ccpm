# ccpm
Extensible package manager for ComputerCraft

Features include:
- Using multiple package sources
- Managing package updates
- Listing and searching package sources

## Getting started
Download `ccpm.lua` to your ComputerCraft computer, ex.:

`wget https://raw.githubusercontent.com/emil1003/ccpm/master/ccpm.lua ccpm.lua`

Run it by typing `ccpm` at the root directory.
Before ccpm can be used, at least one package source must be configured.

`ccpm source add <url>`

Then update the package cache.

`ccpm update`

Now packages can be installed

`ccpm install <package>`
