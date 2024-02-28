
In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 8:
SCRIPT_PATH=$(cd `dirname "${BASH_SOURCE[0]}"` && pwd)
                 ^---------------------------^ SC2046 (warning): Quote this to prevent word splitting.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 9:
cd $SCRIPT_PATH
^-------------^ SC2164 (warning): Use 'cd ... || exit' or 'cd ... || return' in case cd fails.

Did you mean: 
cd $SCRIPT_PATH || exit


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 13:
ME=`basename "$0"`
^-- SC2034 (warning): ME appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 24:
CYAN='\033[0;96m'
^--^ SC2034 (warning): CYAN appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 25:
YELLOW='\033[0;93m'
^----^ SC2034 (warning): YELLOW appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 27:
BLUE='\033[0;94m'
^--^ SC2034 (warning): BLUE appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 28:
BOLD='\033[1m'
^--^ SC2034 (warning): BOLD appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 32:
ON_SUCCESS="DONE"
^--------^ SC2034 (warning): ON_SUCCESS appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 33:
ON_FAIL="FAIL"
^-----^ SC2034 (warning): ON_FAIL appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 34:
ON_ERROR="Oops"
^------^ SC2034 (warning): ON_ERROR appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 35:
ON_CHECK="✓"
^------^ SC2034 (warning): ON_CHECK appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 66:
	__log_this_="$@"
                    ^--^ SC2124 (warning): Assigning an array to a string! Assign as array, or use * instead of @ to concatenate.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 72:
    if [ $(id -u) -ne 0 ]; then
         ^------^ SC2046 (warning): Quote this to prevent word splitting.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 98:
        RPM=0
        ^-^ SC2034 (warning): RPM appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 99:
        DEB=1
        ^-^ SC2034 (warning): DEB appears unused. Verify use (or export if used externally).


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 131:
gen_pass() {
^-- SC2120 (warning): gen_pass references arguments, but none are ever passed.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 147:
        local pass=$(gen_pass)
              ^--^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 190:
                local pass=$(gen_pass)
                      ^--^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 247:
                local locked=$(cat /etc/shadow | grep $user | grep !)
                      ^----^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 349:
                        yes | rm -r /etc/sudoers.d/$user
                              ^------------------------^ SC2216 (warning): Piping to 'rm', a command that doesn't read stdin. Wrong command or missing xargs?


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/usr-mgr.sh line 414:
                    yes | rm -r /etc/sudoers.d/$user
                          ^------------------------^ SC2216 (warning): Piping to 'rm', a command that doesn't read stdin. Wrong command or missing xargs?

For more information:
  https://www.shellcheck.net/wiki/SC2034 -- BLUE appears unused. Verify use (...
  https://www.shellcheck.net/wiki/SC2046 -- Quote this to prevent word splitt...
  https://www.shellcheck.net/wiki/SC2120 -- gen_pass references arguments, bu...
