# --- ROCK-COPYRIGHT-NOTE-BEGIN ---
# 
# This copyright note is auto-generated by ./scripts/Create-CopyPatch.
# Please add additional copyright information _after_ the line containing
# the ROCK-COPYRIGHT-NOTE-END tag. Otherwise it might get removed by
# the ./scripts/Create-CopyPatch script. Do not edit this copyright text!
# 
# ROCK Linux: rock-src/package/blindcoder/ezipupdate/mod_ezipupdate.sh
# ROCK Linux is Copyright (C) 1998 - 2005 Clifford Wolf
# 
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version. A copy of the GNU General Public
# License can be found at Documentation/COPYING.
# 
# Many people helped and are helping developing ROCK Linux. Please
# have a look at http://www.rocklinux.org/ and the Documentation/TEAM
# file for details.
# 
# --- ROCK-COPYRIGHT-NOTE-END ---
#
# [MAIN] 20 user User and Group management

user_edit_user_change_shell() { # {{{
	IFS=: read username haspwd uid gid desc home shell < <( grep ^${1}: /etc/passwd )
	cmd="'Do not change' 'shell=${shell}'"
	while read validshell ; do
		cmd="${cmd} '${validshell}' 'shell=${validshell}'"
	done < /etc/shells
	eval "gui_menu user_edit_user_change_shell 'Change login shell for ${username}' ${cmd}"
} # }}}
user_edit_user() { # {{{
	IFS=: read username haspwd uid gid desc home shell < <( grep ^${1}: /etc/passwd )
	read oldline < <( grep ^${1}: /etc/passwd )
	run=0
	while [ ${run} -eq 0 ] ; do
		cmd="'Login: ${username}' 'gui_input \"Enter new login for ${username}\" \"${username}\" username'"
		cmd="${cmd} 'Has a password: $( [ -n "${haspwd}" ] && echo "yes" || echo "no" )' 'gui_yesno \"Must ${username} supply a password to login?\" && haspwd=x || unset haspwd'"
		cmd="${cmd} 'User ID: ${uid}' 'gui_input \"Enter new user ID for ${username}\" \"${uid}\" uid'"
		cmd="${cmd} 'Group ID: ${gid}' 'gui_input \"Enter new primary group ID for ${username}\" \"${gid}\" gid'"
		cmd="${cmd} 'Long description: ${desc}' 'gui_input \"Enter new descryption for ${username}\" \"${desc}\" desc'"
		cmd="${cmd} 'Home directory: ${home}' 'gui_input \"Enter new home directory for ${username}\" \"${home}\" home'"
		cmd="${cmd} 'Shell: ${shell}' 'user_edit_user_change_shell ${username}'"
		cmd="${cmd} 'Set new password' 'passwd \"${username}\" ; read -p \"Press -<Return>- to continue\"'"
		eval "gui_menu user_edit_user 'Manage account ${username}' ${cmd}"
		run=${?}
	done
	sed -i /etc/passwd -e "s,^${oldline}$,${username}:${haspwd}:${uid}:${gid}:${desc}:${home}:${shell},"
} # }}}
user_add_user() { # {{{
	unset username haspwd uid gid desc home shell
	while [ -z "${username}" ] ; do 
		gui_input "Enter new username" "" username || return
		if grep -q ^${username}: /etc/passwd ; then
			gui_message "Username ${username} already exists!"
			unset username
		fi
	done
	gui_yesno "Does ${username} need a password to log in?" && haspwd=x
	uid=0
	while IFS=: read a a id a ; do
		[ ${uid} -lt ${id} ] && uid=${id}
	done < <( grep -v ^nobody: /etc/passwd )
	uid=$(( ${uid} + 1 ))
	gui_input "Enter new User ID" "${uid}" uid || return
	IFS=: read a a gid a < <( grep ^users: /etc/group )
	gui_input "Enter new Group ID" "${gid:-100}" gid || return
	gui_input "Enter new User Description" "" desc || return
	gui_input "Enter home directory" "/home/${username}" home || return
	gui_input "Enter new shell" "/bin/bash" shell || return
	tmp="`mktemp`"
	useradd -u "${uid}" -g "${gid}" -p "${haspwd}" -d "${home}" -m -s "${shell}" \
		-c "${desc}" "${username}" >${tmp} 2>&1 || \
		gui_message "Error creating user: `cat ${tmp}`"
	rm "${tmp}"
} # }}}
user_edit_group_members() { # {{{
	IFS=: read groupname haspwd gid members < <( grep ^${1}: /etc/group )
	read oldline < <( grep ^${1}: /etc/group )
	run=0
	members=" ${members//,/ } "
	while [ ${run} -eq 0 ] ; do
		cmd=""
		while read x ; do
			if [[ "${members}" == *\ ${x}\ * ]] ; then
				cmd="${cmd} '[X] ${x}' 'members=\${members// ${x} / }'"
			else
				cmd="${cmd} '[ ] ${x}' 'members=\"\${members} ${x} \"'"
			fi
		done < <( cut -f 1 -d: /etc/passwd )
		eval "gui_menu user_edit_group_members 'Manage Members of group ${groupname}' ${cmd}"
		run=${?}
	done
	members=${members# }
	members=${members% }
	members=${members// /,}
	sed -i /etc/group -e "s/^${oldline}$/${groupname}:${haspwd}:${gid}:${members}/"
	echo ${members} >&2
} # }}}
user_edit_group() { # {{{
	IFS=:, read groupname haspwd gid members < <( grep ^${1}: /etc/group )
	read oldline < <( grep ^${1}: /etc/group )
	run=0
	while [ ${run} -eq 0 ] ; do
		cmd="'Group name: ${groupname}' 'gui_input \"Enter new group name\" \"${groupname}\" groupname'"
		cmd="${cmd} 'Group ID: ${gid}' 'gui_input \"Enter new group ID\" \"${gid}\" gid'"
		memb="${members:0:25}"
		[ -n "${members:25}" ] && memb="${memb}..."
		cmd="${cmd} 'Members: ${memb}' 'exec 3>&2 ; members=\`user_edit_group_members ${groupname} 2>&1 1>&3\`'"
# fake says this line is unmaintainable. I say it's not. Anyway:
# I modify the variable members from within the function user_edit_group_members
# that's all :)
		eval "gui_menu user_edit_group 'Manage group ${groupname}' ${cmd}"
		run=${?}
	done
	sed -i /etc/group -e "s/^${oldline}$/${groupname}:${haspwd}:${gid}:${members// /,}/"
} # }}}
user_add_group() { # {{{
	unset groupname gid
	while [ -z "${groupname}" ] ; do
		gui_input "Enter new Group Name" "" groupname || return
		if grep -q "^${groupname}:" /etc/group ; then
			gui_message "Group ${groupname} already exists!"
			unset groupname
		fi
	done
	gid=0
	while IFS=: read a a id a ; do
		[ ${gid} -lt ${id} ] && gid=${id}
	done < <( grep -v ^nobody: /etc/passwd | grep -v ^nogroup: )
	gid=$(( ${gid} + 1 ))
	gui_input "Enter new Group ID" "${gid}" gid || return
	tmp="`mktemp`"
	groupadd -g "${gid}" "${groupname}" > ${tmp} 2>&1 || \
		gui_message "Error creating group: `cat ${tmp}`"
	rm "${tmp}"
} # }}}
main() { # {{{
	run=0
	while [ ${run} -eq 0 ] ; do
		cmd="'User Managemeint' ''"
		while IFS=: read username haspwd uid gid desc home shell ; do
			cmd="${cmd} '${desc:-No description} (${username})' 'user_edit_user ${username}'"
		done < /etc/passwd
		cmd="${cmd} 'Add new user' 'user_add_user' '' ''"
		cmd="${cmd} 'Group Management' ''"
		while IFS=: read groupname haspwd gid members ; do
			cmd="${cmd} '${groupname}' 'user_edit_group ${groupname}'"
		done < /etc/group
		cmd="${cmd} 'Add new group' 'user_add_group'"
		eval "gui_menu user 'User and Group management' ${cmd}"
		run=${?}
	done
} # }}}
