# vhs demo.tape — records assets/demo.gif
#
# Everything in this recording is real: a real claude session, a real SIGKILL,
# a real resume answering from restored memory. vhs scripts the typing, not
# the outcome — re-record any time with:
#
#   env -u CLAUDECODE -u CLAUDE_CODE_CHILD_SESSION vhs demo.tape
#
# The Hide blocks stash the machine's live session markers so the recording
# shows only the demo session (and restore them after). Stashed, not faked.

Output assets/demo.gif

Set FontSize 17
Set Width 1020
Set Height 600
Set Padding 18
Set TypingSpeed 35ms
Set Theme "Catppuccin Mocha"

Hide
Type `export PATH="$HOME/projects-b/claude-blackbox/bin:$PATH"; mkdir -p /tmp/bb-stash /tmp/blackbox-demo; mv "$HOME"/.blackbox/live/*.json /tmp/bb-stash/ 2>/dev/null; cd /tmp/blackbox-demo; clear`
Enter
Show

Type "# your agent is deep in a task…"
Sleep 600ms
Enter
Type `claude -p 'Count to 100 by running a separate bash echo command for each number, one at a time' --allowedTools Bash &`
Enter
Sleep 3s
Type "# working… a tool call every few seconds"
Enter
Sleep 18s

Type "kill -9 $!    # 💥 crash — app quit, laptop died, terminal closed"
Sleep 600ms
Enter
Sleep 2s

Type "blackbox list"
Sleep 400ms
Enter
Sleep 5s

Hide
Type `SID=$(ls "$HOME"/.blackbox/live | cut -d. -f1)`
Enter
Show

Type `claude --resume $SID -p 'One sentence: what were you doing when you were interrupted, and how far did you get?'`
Sleep 400ms
Enter
Sleep 35s
Sleep 4s

Hide
Type `rm -f "$HOME"/.blackbox/live/*.json; mv /tmp/bb-stash/*.json "$HOME"/.blackbox/live/ 2>/dev/null; rm -rf /tmp/bb-stash`
Enter
Show
