# record.sh provides the disposable container and the demo-shell command.
Output docs/demos/configure.gif
Output docs/demos/configure.mp4
Set Shell "bash"
Set Width 1200
Set Height 800
Set FontSize 20
Set Padding 20
Set WindowBar "Rings"
Set TypingSpeed 45ms
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
Type "camp fresh configure"
Sleep 500ms
Enter
Wait+Screen /Follow-ups/
Sleep 2s
Type "a"
Wait+Screen /Add follow-up/
Type "install"
Tab
Type "npm ci"
Tab 2
Sleep 1s
Enter
Sleep 2s
Type "a"
Wait+Screen /Add follow-up/
Type "build"
Tab
Type "npm run build"
Tab 2
Sleep 1s
Enter
Sleep 3s
