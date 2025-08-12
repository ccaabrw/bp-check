#!/usr/bin/perl

# bp_list.pl	Bri	Feb05
#
# This is a chopped around version of ~ccsposg/bp_check/bp_check.pl
#
# It just lists all bootptab/dhcpd entries and some information for each host
# There's no postprocessing so users will just have to grep that out
# themselves. Data is output in fixed width format, thus:
#
# <hostname>  <ip addr>  <mac addr>  <server>  <image type>  <T156 field>
# 

use POSIX qw(strftime);

$no_name = "<not in DNS>";
$rotor = 0;

if ($ARGV[0] eq "nice") {
    $nice_output = 1;
    $data_output = 0;
} else {
    $nice_output = 0;
    $data_output = 1;
}

get_data("/nfs/rcs/sysadmin/clusters", "/nfs/rcs/sysadmin/platforms");
#get_data("clusters", "platforms");

if ($nice_output) {
    print_nice();
}
if ($data_output) {
    print_data();
}

exit 0;




sub print_nice {

    if ($nice_all) {

        foreach $host (sort keys %host_name) {
	    printf("%-30s", $host);
	    $tab = "";
	    foreach $entry (sort @{$host_name{$host}}) {
	        print "$tab$entry\n";
	        $tab = "\t\t\t";
	    }
        }
        print "\n\f";
    }
}


sub print_data {

    foreach $host (sort keys %host_name) {
	foreach $entry (sort @{$host_name{$host}}) {
            printf("%-30s%s\n", $host, $entry);
	}
    }
}


sub get_data {
    my($clusters,$platform);

    $clusters = $_[0];
    $platform = $_[1];

#     print STDERR "Processing ";
    open(CLUSTERS,"$clusters") || die("Could not open clusters");
    while($icluster = <CLUSTERS>) {
        chomp($icluster);
        open(PLATFORM,"$platform") || die("Could not open platform");

        while($iplatform = <PLATFORM>) {
# 	    print STDERR "-";
          chomp($iplatform);

	    next if ($icluster =~ /^c[01234]/);

	    if (-d "/nfs/rcs/sysadmin/$icluster/$iplatform") {

	      $splatform = $iplatform;
	      if ($splatform eq "rs6.cs") {
		  $splatform = "s1";
	      } else {
		  $splatform =~ s/^r(s)6-svr-(.*)/$1$2/;
		  $splatform =~ s/^(agw)-(.*)/$1$2/;
	      }
	      $server = $splatform . "." . $icluster;

	      $server_ip = join(".",unpack("C4",(gethostbyname("$server"))[4]));
	      if ($server_ip eq "") {
	         $server_ip = $no_name;
	      }
	
              if ( -r "/nfs/rcs/sysadmin/$icluster/$iplatform/bootptab") {
                 proc_file("/nfs/rcs/sysadmin/$icluster/$iplatform/bootptab");
              }

              if ( -r "/nfs/rcs/sysadmin/$icluster/$iplatform/dhcpd.conf") {
                 proc_dhcp("/nfs/rcs/sysadmin/$icluster/$iplatform/dhcpd.conf");
              }
	    }
        }

        close(PLATFORM) || die("Problem with platform");
    }
    close(CLUSTERS);
#     print STDERR "\n";
}

sub rotator {
    $rotor++;
    if ($rotor == 1) {
	return("\b\\");
    } elsif ($rotor == 2) {
	return("\b\|");
    } elsif ($rotor == 3) {
	return("\b\/");
    } else {
	$rotor = 0;
	return("\b\-");
    }
}

sub proc_file {

    @filedata = `/nfs/rcs/sysadmin/tools/expandbootp $_[0]`;

# print STDERR "\n$_[0]\t";
    foreach (@filedata) {
# 	print STDERR &rotator;
	chomp ($_);

        next if (/^#/);             #
        next if (/^$/);             # Skip uninteresting lines
#       next if (! /T1(44|51|55)/); #
	next if (/^hp2300a.ether/); #

        ($host) = split(/:/,$_);

	$info{$host}{server} = $server;

	$ipaddr = join(".",unpack("C4",(gethostbyname("$host"))[4]));
	if ($ipaddr eq "") {
	    $ipaddr = $no_name;
	}
	$info{$host}{ipaddr} = $ipaddr;

	
	@parms = split(/:/,$_);

	foreach $parm ( @parms ) {
	    ($key, $val) = split(/=/, $parm);

	    if ($key eq "ha") {
		$val = uc $val;
		push @{$hw_addr{$val}}, sprintf("%-24s%-16s%s", $host, $ipaddr, $server);
#printf("%-16s%-24s%-16s%s\n", $val, $host, $ipaddr, $server);
	    }

	    $info{$host}{$key} = $val;

	    if ($key =~ /T155/) {
		$val =~ s/\"//g;
		@list = reverse(split("/", $val));
		$val = $list[0] . "/" . $list[1];
		$info{$host}{image} = $val;
	    }	

	    if ($key =~ /hd/) {
		@list = reverse(split("/", $val));
		if ($list[0] && $list[0] !~ /tftpboot/) {
		    $val = "newdos/" . $list[0];
		    $info{$host}{image} = $val;
		}
	    }

#	   # if ($key =~ /T151/) {
#		$val =~ s/\"//g;
#		$patchfile{$val}++;
#	    }

	    if ($key =~ /T156/) {
		$val =~ s/\"//g;
		$info{$host}{T156} = $val;
	    }

	    if ($key eq "gw") {
		$helpers{$val}{$server_ip} = $server;
	    }

	}
	push @{$host_name{$host}}, sprintf("%-16s%-14s%-30s%-20s%s", $ipaddr, uc $info{$host}{ha}, $server, $info{$host}{image}, $info{$host}{T156});
    }

}


sub proc_dhcp() {
    my ($dhcp_hn);

    open (FILE, $_[0]);

# print STDERR "\n$_[0]\t";
    while ($line = <FILE>) {
# 	print STDERR &rotator;
	chomp ($line);
	while ($line) {
		if ($line =~ /^\s*(\S+)(.*)/) {
			$tok = $1;
			$line = $2;
			while ($tok) {
				if ($tok =~ /^#/) {
					$tok = "";
					$line = "";
				} elsif ($tok =~ /(\S*)([\;\{\}])(.*)/) {
					push @list, $1 if $1;
					push @list, $2;
					$tok = $3;
				} else {
					push @list, $tok;
					$tok = "";
				}
			}
		} else {
			$line = "";
		}
	}
    }

    close (FILE);

    $flag = 1;
    while (@list) {
	$line = shift @list;
	if ($flag == 1) {
		if ($line eq "subnet") {
			$flag = 2;
			$sn_ip = shift @list;
			$sn_nm = undef;
			$sn_gw = undef;
		} elsif ($line eq "host") {
			$flag = 3;
			$hn_nm = shift @list;
			$hn_ha = undef;
			$hn_ad = undef;
		} else {
			$flag = 0;
		}
		$brace = 0;
	} elsif ($flag == 2) {
		if ($line eq "netmask") {
			$sn_nm = shift @list;
		} elsif ($line eq "routers") {
			$sn_gw = shift @list;
		}
	} elsif ($flag == 3) {
		if ($line eq "hardware" && $list[0] eq "ethernet") {
			shift (@list);
			$hn_ha = shift @list;
		} elsif ($line eq "fixed-address") {
			$hn_ad = shift @list;
		} elsif ($line eq "option" && $list[0] eq "option-135") {
			shift (@list);
			$hn_im = shift @list;
		}
	}
	
	next if ($flag == 0 && $line !~ /[\{\;\}]/);

	if ($line eq "{" && $flag >= 2) {
		$brace++;
	}
	if ($line eq "}") {
		$brace--;
	}
	if ($line =~ /[\;\}]/ && $brace <= 0) {
		if ($flag == 2) {
			$dhcp_sn{$sn_gw}{ip} = $sn_ip;
			$dhcp_sn{$sn_gw}{nm} = $sn_nm;
		} elsif ($flag == 3) {
			$dhcp_hn{$hn_ad}{nm} = $hn_nm;
			$dhcp_hn{$hn_ad}{ha} = $hn_ha;
			$dhcp_hn{$hn_ad}{im} = $hn_im;
		}
		$flag = 1;
	}
    }



    foreach $host (keys %dhcp_hn) {

	#($h_sname, $h_ha, $h_im) = $dhcp_hn{$host};

	$info{$host}{server} = $server;

	$ipaddr = join(".",unpack("C4",(gethostbyname("$host"))[4]));
	if ($ipaddr eq "") {
	    $ipaddr = $no_name;
	}
	$info{$host}{ipaddr} = $ipaddr;

	$val = uc mangle_hw ($dhcp_hn{$host}{ha});
	$info{$host}{ha} = $val;
	push @{$hw_addr{$val}}, sprintf("%-24s%-16s%s", $host, $ipaddr, $server);

	$val = $dhcp_hn{$host}{im};
	$val =~ s/\"//g;
	@list = reverse(split("/", $val));
	$val = $list[0] . "/" . $list[1];
	$subimage{$val}++;

	$val = check_sn($ipaddr);
	$helpers{$val}{$server_ip} = $server;

	push @{$host_name{$host}}, sprintf("%-16s%-14s%s", $ipaddr, uc $info{$host}{ha}, $server);

        delete $dhcp_hn{$host};
    }
}

sub mangle_hw {
    my (@hw);

    @hw = ("00","00","00","00","00","00");
    @hw = reverse(split(/:/, $_[0]));
    foreach (@hw) {
	if (length($_) < 2) {
	    $_ = "0" . $_;
	}
    }
    return join("", reverse(@hw));
}
    
sub check_sn {

	@calc_ip = split(/\./, $_[0]);
	$num_ip = ((($calc_ip[0] << 8) + $calc_ip[1] << 8) + $calc_ip[2] << 8) + $calc_ip[3];
	foreach $dhcp_gw (keys %dhcp_sn) {

		@calc_ip = split(/\./, $dhcp_sn{$dhcp_gw}{ip});
		$nchk_ip = ((($calc_ip[0] << 8) + $calc_ip[1] << 8) + $calc_ip[2] << 8) + $calc_ip[3];
		@calc_ip = split(/\./, $dhcp_sn{$dhcp_gw}{nm});
		$nchk_sn = ((($calc_ip[0] << 8) + $calc_ip[1] << 8) + $calc_ip[2] << 8) + $calc_ip[3];
		if ((($nchk_ip ^ $num_ip) & $nchk_sn) == 0) {
			return $dhcp_gw;
		}
	}
	return "<no gateway>";
}

