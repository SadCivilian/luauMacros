# luauMacros

Simple macro system as a Roblox Studio plugin for the Luau language.

![Showcase](assets/cut.gif)

## Installation

You can install the plugin by building it from source here and registering the script as a local plugin, adding the .rbxm from any release to your local plugins, or by downloading it straight from the Roblox Creator Store under the name luauMacros.

## Functionalities

# Basics
After installing the plugin, you can add certain keywords for your macros, which work globally. While editing any script, typing the macro keyword will automatically make it expand to the text of your choosing once you press space.

# Variable Macros

Variable macros work a bit differently to adding a regular macro. When creating a variable macro, you need to enter parameters to your macro definition while entering the macro name. For example, this could be something like so:

**`fn <a>`**, **`fn <param>`**, etc. 

These are both valid parameter names and the text contained inside the less than and greater than symbols denote the **variable name**.

The variable name is then used while typing the macro expansion, as so:

**`local function <a>()`**, **`local function <param>()`**, etc.

To use these variable macros while typing, you must first type your macro name without the parameters (in this case, fn), then you must type your parameters IN PLAIN TEXT, seperated by commas, between the less than and greater than symbols as so:

```lua
fn<hello>
```

Then, you can press your desired key to expand your macro.

## Things to be implemented
- More optimized buffer processing/string parsing with the buffer library. As of this README, this is being worked on for the next release.
- A smarter buffer system which supports smart buffer rebuilding. This should currently not be an issue unless you are trying to find issues with the buffer system. <br>
- Macros not expanding in block comments. <br>
- A better UI/UX, with bulk deleting and prettier outputs. <br>
- A settings menu. You would be able to toggle things such as, but not limited to:
- Whether to flush or smart rebuild the buffer on Ctrl + Z / Ctrl + Backspace deletions <br>
- Whether macros are enabled or not (would retire the current button) <br>
- Tab or space to expand macros <br>
