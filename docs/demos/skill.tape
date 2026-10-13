# record-skill.sh supplies an isolated, authenticated Codex session.
Output docs/demos/skill.gif
Output docs/demos/skill.mp4
Set Shell "bash"
Set Width 1200
Set Height 800
Set FontSize 20
Set Padding 20
Set WindowBar "Rings"
Set TypingSpeed 55ms
Set Framerate 12
Set LoopOffset 80%
Set Theme "Catppuccin Mocha"
Set WaitTimeout 5m
Hide
Type "agent-demo"
Enter
Wait+Screen /Ask Codex to do anything/
Sleep 2s
Show
Type "Use $fresh. My PR merged."
Sleep 1s
Enter
Wait+Screen /Fresh! Synced to main/
Wait+Screen /Worked for/
Sleep 1s
PageDown 5
Sleep 4s
