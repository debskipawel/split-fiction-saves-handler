# Split Fiction Saves Handler

Hazelight Studios doesn't want to put multiple save slots in their games, in case you want to play with different people in parallel?

No worries, here's a very over-the-top solution which allows you to host INFINITELY many save slots in Split Fiction.

## Usage

Launch the `GenerateLauncher.bat` batch script. That will generate another batch script called `LaunchSplitFiction.bat`. You may copy that generated file in any convenient location (i.e. your desktop) and use it as a *Split Fiction* launcher. This batch file starts the PowerShell script which does some funky stuff. 

## Technical details

Saves are kept on a [Github repository](https://github.com/debskipawel/split-fiction-saves/tree/main). For each save slot, a new branch in that repository needs to be created. Then, in the script directory the user needs to create a JSON config which looks like this:

```json
{
    "name": "<DISPLAY-NAME>",
    "branch_name": "<BRANCH-NAME>"
}
```

Script will automatically detect any valid config (JSON object containing those 2 properties) and display it in a player select window. After selection, the script will checkout the latest commit at selected branch, pull it and copy it to the game's save directory. 

Then, the game will be launched as a new process and the script will wait until it terminates. When it does, it will copy new save files from the game directory back to the save repo directory, and commit & push new save files.

## Assumptions

The script makes certain assumptions, such as that: 

- Split Fiction is installed using Steam,
- Steam is located relatively shallowly in its drive (max depth of recursive search is set to 4, if that's invalid, modify the function `Find-GamePath` @ line 87),
- the user has permissions to commit and push to the saves repo.
