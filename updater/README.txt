Tidy Nest updater (Windows)

WHAT IT DOES
  Checks GitHub for the newest version of Tidy Nest. If yours is older, or missing, it downloads
  the new jar, checks it, and puts it in your mods folder. Your old jar is moved to a
  "tidynest-backup" folder next to "mods", not deleted. If anything goes wrong (no internet, a bad
  download), nothing in your mods folder is changed.

  Every official jar is signed by afkbird. The updater installs a jar only if its signature is
  correct, so a file that didn't come from afkbird is refused.

HOW TO USE IT
  1. Close Minecraft.
  2. Double-click update-tidynest.bat.
  3. Read the message, press Enter, start Minecraft.
  The mod tells you in game when an update is out. Run the updater then, or just before you
  play. If you're already up to date it says so and changes nothing.

WHERE IT LOOKS
  * Normal Minecraft launcher: %APPDATA%\.minecraft\mods (automatic).
  * A server, or another launcher: put both files in the folder that CONTAINS the "mods"
    folder (for a server, the server folder). Stop the server before running it.

FIRST RUN
  Windows may warn that the file came from the internet. Choose "More info" > "Run anyway"
  (or right-click the files > Properties > Unblock). The updater only talks to GitHub.

LAUNCHERS WITH A PRE-LAUNCH COMMAND (e.g. Prism Launcher)
  Set it to update automatically every time you press Play:
    powershell -NoProfile -ExecutionPolicy Bypass -File "C:\path\to\update-tidynest.ps1" -NoPause -ModsDir "$INST_MC_DIR\mods"
  (-CheckOnly only reports whether an update is available.)
