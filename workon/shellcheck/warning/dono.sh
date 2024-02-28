
In /home/dari/Desktop/my_stuff/bin/not_add_2_path/utilities/dono.sh line 32:
	local file=$(echo "$title" | sed 's/ /_/g;s/\(.*\)/\L\1/g')
              ^--^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/utilities/dono.sh line 33:
	local template=$(cat <<- END
              ^------^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/utilities/dono.sh line 58:
    local action=$(echo -e "Yes\nNo" | ${rofi_command} -p "Are you sure you want to delete $note? ")
          ^----^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/utilities/dono.sh line 75:
    	local action=$(echo -e "Edit\nDelete" | ${rofi_command} -p "$note > ")
              ^----^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/utilities/dono.sh line 92:
		local title=$(echo -e "Cancel" | ${rofi_command} -p "Input title: ")
                      ^---^ SC2155 (warning): Declare and assign separately to avoid masking return values.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/utilities/dono.sh line 144:
Todo_Creater() {
^-- SC2120 (warning): Todo_Creater references arguments, but none are ever passed.


In /home/dari/Desktop/my_stuff/bin/not_add_2_path/utilities/dono.sh line 178:
Todo_list()
^-- SC2120 (warning): Todo_list references arguments, but none are ever passed.

For more information:
  https://www.shellcheck.net/wiki/SC2120 -- Todo_Creater references arguments...
  https://www.shellcheck.net/wiki/SC2155 -- Declare and assign separately to ...
