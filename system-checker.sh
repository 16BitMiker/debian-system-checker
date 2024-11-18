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
	my $output = run( $choice ) if $$db[$choice];
	
	my $output_file = q|output/log_|.time().q|.txt|;
	
	open my $fh, q|>|, $output_file or 
	do { say q|>|, RED BOLD q|File write fail!|, RESET; bye() }; 
	print $fh $output_file;
	close $fh;
	msg( qq|Output saved: ${output_file}| );
	
	printf qq|> %s. |, q|Press enter to continue|;
	<STDIN>;
	goto MENU;
    
	# ~~~~~~~~~~~~~~~~~~~~~~ SUBS
	
	sub run
	{
	    my $key = shift;
	    my ($cmd) = values %{$$db[$key]};
	    msg( $cmd );
	    
	    open( my $pipe, q(-|), $cmd ) or die "Cannot open pipe: $!";
	    
	    my $output = q();
	    while (my $line = <$pipe>) 
	    {
	        print $line;  # Display output on the screen
	        $output .= $line;  # Append to the output variable
	    }
	    
	    close($pipe);
	    my $exit_status = $? >> 8;
	    
	    if ($exit_status != 0)
	    {
	        msg( qq|Command failed! Exit status: $exit_status|, q|RED| );
	        bye();
	    }
	    
	    return $output;  # Return the captured output
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
		
		$i = 0;
		map 
		{
			unless (m~^#~)
			{
				printf qq|%-2d - %s%s%s\n|
				, $i++
				, YELLOW BOLD q||
				, s`~~~.*$``r
				, RESET q||;
			}
			else
			{
				s~^\# ~~;
				say WHITE UNDERLINE $_, RESET;
			}
		} 
		grep 
		{ !m~^$~ } split m~\n~, $cmds;
		
		border();
	}

' -- -cmds="$(cat <<'END'

# System Overview and Performance
system load~~~uptime
disk usage~~~df -h
running services~~~sudo systemctl list-units --type=service --state=running
mounted filesystems~~~mount | column -t

# User and Group Information
show groups & users~~~perl -nl -E 'BEGIN { printf qq|%s%s%s\n|, q|Group|, q| |x6, q|Users| }' -E '($group, $user) = m~^(sudo|www-data).+:\K(.*)$~g; if ($group) { printf qq|%8s = %s\n|, $group, $user =~ s~,\K~ ~gr }' /etc/group
current users~~~who
recent logins~~~sudo journalctl -u systemd-logind --no-pager | grep "New session" | tail -n 20
empty passwords~~~sudo awk -F: '($2 == "") {print $1}' /etc/shadow

# Process Monitoring
high cpu processes~~~ps aux --sort=-%cpu | head -n 11
high memory processes~~~ps aux --sort=-%mem | head -n 11

# Network Connections and Ports
open network connections~~~sudo lsof -i
listening ports~~~sudo ss -tulpn
established connections~~~sudo ss -tan state established
active connections~~~sudo journalctl -u systemd-networkd --no-pager | grep "ESTABLISHED" | tail -n 25

# Log Analysis and System Events
logcheck~~~sudo -u logcheck logcheck -o -t | tail -n 25
logwatch~~~sudo logwatch --output stdout --format text --detail high --range Today --encode none --numeric --service All | grep -E 'error|warning|critical|failed|failure|alert|denied|refused|violation|attack' | sort | uniq -c | sort -rn | head -n 50
journal errors~~~sudo journalctl -p err..alert --since "1 hour ago" --no-pager | tail -n 25
system events~~~sudo journalctl -k --no-pager | tail -n 25
large log files~~~sudo journalctl --disk-usage && echo "Largest Journal Files:" && sudo du -ah /var/log/journal/ | sort -rh | head -n 10 && echo "Oldest Entry:" && sudo journalctl --reverse --output=short-precise | tail -n 1 && echo "Newest Entry:" && sudo journalctl --output=short-precise | tail -n 1 && echo "Journal Configuration:" && sudo journalctl -u systemd-journald | grep -E 'Runtime journal|System journal' | tail -n 2

# Security and Intrusion Detection
lynis audit~~~sudo lynis audit system --quick --report-file -
failed ssh logins~~~sudo journalctl -u ssh --no-pager | grep "Failed password" | tail -n 20
setuid files~~~timeout 30s sudo find /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin -type f -perm -4000 -ls 2>/dev/null | sort -k11 | tail -n 25
ssh login attempts~~~sudo journalctl -u ssh --no-pager | grep -E "Failed|Accepted" | tail -n 20
ssh connection summary~~~sudo journalctl -u ssh --no-pager | grep -E "Failed|Accepted" | awk '{print $1,$2,$3,$9,$11}' | sort | uniq -c | sort -nr | head -n 10
failed ssh ips~~~sudo journalctl -u ssh --no-pager | grep "Failed password" | awk '{print $11}' | sort | uniq -c | sort -nr | head -n 10
successful ssh logins~~~sudo journalctl -u ssh --no-pager | grep "Accepted" | tail -n 10
ssh config~~~sudo grep -v "^#" /etc/ssh/sshd_config | grep -v "^$"
ssh ports~~~sudo ss -tlnp | grep sshd
ssh sessions~~~w -h || who || echo "No active sessions"

# File System Monitoring
recent system changes~~~sudo journalctl --no-pager | grep "/etc" | grep "WRITE" | tail -n 25
modified etc files~~~sudo find /etc -type f -mtime -1 | tail -n 25



END
)"

