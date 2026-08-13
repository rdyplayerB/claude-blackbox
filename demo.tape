# vhs demo.tape — records assets/demo.gif
#
# Everything in this recording is real: a real claude session, a real SIGKILL,
# a real picker listing real boxes, a real resume answering from restored
# memory. vhs scripts the typing, not the outcome. Re-record any time with:
#
#   env -u CLAUDECODE -u CLAUDE_CODE_CHILD_SESSION vhs demo.tape
#
# Privacy: the picker opens scoped to the current project, so this recording
# can only ever show the throwaway demo project. Never press Tab on camera —
# Tab widens the scope to every project on the machine.
#
# Prerequisite: /private/tmp/blackbox-demo must already be a trusted folder in
# whichever CLAUDE_CONFIG_DIR records this. The rescue execs an interactive
# claude, and an untrusted directory answers with the trust dialog, which eats
# the scripted keystrokes. Accept it once by hand (`cd` there, run `claude`,
# choose "Yes, I trust this folder", /exit) and every later take is clean.

Output assets/demo.gif

Set FontSize 16
Set Width 1100
Set Height 560
Set Padding 18
Set TypingSpeed 35ms
Set Theme "Catppuccin Mocha"

Hide
Type `export PATH="$HOME/projects-b/claude-blackbox/bin:$PATH"; mkdir -p /private/tmp/blackbox-demo; cd /private/tmp/blackbox-demo; clear`
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
Sleep 14s

Type "kill -9 $!    # 💥 crash — app quit, laptop died, terminal closed"
Sleep 600ms
Enter
Sleep 3s

# One word. The Black Box Picker opens scoped to this project.
Type "blackbox"
Sleep 400ms
Enter
Sleep 5s

# Enter on the highlighted box: cd, config root, launch flags, exec.
Enter
Sleep 14s

Type "One sentence: what were you doing when you were interrupted, and how far did you get?"
Sleep 400ms
Enter
Sleep 35s
