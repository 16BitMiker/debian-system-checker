#!/bin/bash
#
#          _nnnn_
#         dGGGGMMb
#        @p~qp~~qMb
#        M|@||@) M|
#        @,----.JM|
#       JS^\__/  qKL
#      dZP        qKRb
#     dZP          qKKb
#    fZP            SMMb
#    HZM            MMMM
#    FqM            MMMM
#  __| ".        |\dS"qML
#  |    `.       | `' \Zq
# _)      \.___.,|     .'
# \____   )MMMMMP|   .'
#      `-'       `--' 
#
# Debian System Checker
# By: 16BitMiker (v2024-11-08)
#
# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Setup

sudo DEBIAN_FRONTEND=noninteractive apt update -y
sudo DEBIAN_FRONTEND=noninteractive apt install -y logcheck
sudo DEBIAN_FRONTEND=noninteractive apt install -y logwatch
sudo DEBIAN_FRONTEND=noninteractive apt install -y lynis

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ Go!

perl -MTerm::ANSIColor=:constants -MData::Dumper -sE'
    
	$|++;
	
	@{$db} = map {{ s`~~~.*$`$1`r => s`^[^~]+~~~``r  }} 
			 grep { !m~^$|^\#~ } split m~\n~, $cmds;
	
	MENU: menu();
	print qq|> |;
	$choice = q||;
	chomp( $choice = <STDIN> );

	goto MENU if $choice =~ m~^$~;
	$choice =~ m~[BQE]~i ? bye() : ();
	goto MENU unless $choice =~ m~^[0-9]+$~;
	run( $choice ) if $$db[$choice];
	goto MENU;
    
	# ~~~~~~~~~~~~~~~~~~~~~~ SUBS
	
	sub run
	{
		my $key = shift;
		my ($cmd) = values %{$$db[$key]};
		msg( $cmd );
		system $cmd;
		if ($?)
		{
			msg( qq|Command failed! ${!}|, q|RED| );
			bye();
		}
	}
	
	sub bye
	{
		msg( q|Bye bye!|, q|RED| );
		exit 69
	}
	
	sub clear
	{
		# Clear the screen
		print "\033[2J";    # This clears the entire screen
		print "\033[H";     # This moves the cursor to the top-left corner	
	}
	
	sub border
	{
		$n = shift // 40;
		say q|-|x$n;
	}
	
	sub msg
	{
		chomp( my $msg = shift );
		chomp( my $color = shift // q|GREEN| );
		print q|> |;
		eval qq`print ${color} BOLD q||`;
		t( $msg );
		say RESET q||;
	}
	
	sub t
	{
	    my $cmd = shift;
	    $cmd =~ s~.~select(undef, undef, undef, rand(0.03)); print $&~sger
	}
	
	sub menu
	{
		border();
		say q|Main Menu: q(uit)|;
		border();
		for my $key (keys @{$db})
		{
			printf qq|%-2d - %s%s%s\n|
			, $key
			, YELLOW BOLD q||
			, keys %{$$db[$key]}
			, RESET q||;
		}
		border();
	}

' -- -cmds="$(cat <<'END'

# System Overview and Performance
system load~~~uptime
disk usage~~~df -h
running services~~~systemctl list-units --type=service --state=running
mounted filesystems~~~mount | column -t

# User and Group Information
show groups & users~~~perl -nl -E 'BEGIN { printf qq|%s%s%s\n|, q|Group|, q| |x6, q|Users| }' -E '($group, $user) = m~^(sudo|www-data).+:\K(.*)$~g; if ($group) { printf qq|%8s = %s\n|, $group, $user =~ s~,\K~ ~gr }' /etc/group
current users~~~who
recent logins~~~last -n 20
empty passwords~~~sudo awk -F: '($2 == "") {print $1}' /etc/shadow

# Process Monitoring
high cpu processes~~~ps aux --sort=-%cpu | head -n 11
high memory processes~~~ps aux --sort=-%mem | head -n 11

# Network Connections and Ports
open network connections~~~sudo lsof -i
listening ports~~~sudo ss -tulpn
established connections~~~sudo ss -tan state established
active connections~~~netstat -tunapl | grep ESTABLISHED | tail -n 25

# Log Analysis and System Events
logcheck~~~sudo -u logcheck logcheck -o -t | tail -n 25
logwatch~~~sudo logwatch --output stdout --format text --detail high --range All --service All | grep -E 'error|warning|critical|failed|failure|alert'
journal errors~~~journalctl -p err..alert --since "1 hour ago" | tail -n 25
system events~~~sudo dmesg -w | tail -n 25
large log files~~~sudo find /var/log -type f -size +50M -exec ls -lh {} \; | sort -rh | head -n 10

# Security and Intrusion Detection
lynis audit~~~sudo lynis audit system
failed ssh logins~~~sudo grep "Failed password" /var/log/auth.log | tail -n 20
setuid files~~~sudo find / -type f -perm -4000 2>/dev/null | tail -n 25

# File System Monitoring
recent system changes~~~sudo find /etc -type f -mtime -1 -ls
modified etc files~~~sudo find /etc -type f -mtime -1 | tail -n 25

END
)"

