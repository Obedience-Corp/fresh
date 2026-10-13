Output docs/demos/cleanup.gif
Output docs/demos/cleanup.mp4
Set Shell "bash"
Set Width 1200
Set Height 800
Set FontSize 20
Set Padding 20
Set WindowBar "Rings"
Set TypingSpeed 50ms
Set Framerate 12
Set LoopOffset 80%
Set Theme "Catppuccin Mocha"
Hide
Type "demo-shell"
Enter
Wait+Line /site \$/
Type "clear"
Enter
Sleep 300ms
Show
Type "camp fresh --dry-run"
Sleep 500ms
Enter
Wait+Screen /preview only/
Sleep 3s
Hide
Type "clear"
Enter
Sleep 300ms
Show
Type "camp fresh"
Sleep 500ms
Enter
Wait+Screen /Fresh! Synced to main./
Sleep 4s
