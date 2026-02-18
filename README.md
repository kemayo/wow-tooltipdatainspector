# TooltipDataInspector

There has always been some information in World of Warcraft that is only accessible inside tooltips, and addons have a long history of creating hidden tooltips and scanning their contents to get at this data.

Since [patch 10.0.2](https://warcraft.wiki.gg/wiki/Patch_10.0.2/API_changes#Tooltip_Changes) WoW has had an API for accessing data that's contained in tooltips ([TooltipInfo](https://warcraft.wiki.gg/wiki/Category:API_systems/TooltipInfo)), which provides access to this data without requiring you to display a tooltip and then try to parse the text it contains.

There's a lot of information hidden away in the data structure returned from the TooltipInfo functions, some that's not even available in the tooltip's text, but it's difficult to browse through it. There's a lot of type IDs that map to `Enum` values that you need to look up for yourself, there's `Color` objects mixed in that make any usage of `/dump` a mess, and there's just generally a lot of nested data that you have to scroll through.

This displays all that data for you in a nicely formatted manner.

It does this by using the (new since 10.0.2) `TooltipDataProcessor.AddTooltipPostCall` system, so any time a tooltip that uses `GameTooltipTemplate` is shown it will be notified of the data being displayed.

## Usage

1. Type `/tdi` or click the button in the addon compartment.
1. An inspector window will appear.
1. While it's open it will display the data from any tooltip that's shown.
