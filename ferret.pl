#!/usr/bin/perl
##
#   __                    _   
#  / _| ___ _ __ _ __ ___| |_ 
# | |_ / _ \ '__| '__/ _ \ __|
# |  _|  __/ |  | | |  __/ |_ 
# |_|  \___|_|  |_|  \___|\__|
# ----------------------------------------
#	ferret.pl: dig out system information
#	run with: perl <(curl -ks https://raw.githubusercontent.com/hputhuff/Ferret/master/ferret.pl)
#	options:
#		-t or --notimes = don't print times
#	January 2016 by Harley H. Puthuff
#	Copyright 2016, Harley H. Puthuff
#

use strict;
use feature "switch";
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

# command line options:
our $options = {
	notimes => 0			# don't print times
	};
	
# evaluated configuration settings:
our $conf = {
	hostname => undef,		# hostname for server
	isRedhat => 1,			# Redhat or CentOs
	isUbuntu => 0,			# Ubuntu, Mint, Debian
	isPlesk => 0,			# Plesk is running
	isCpanel => 0,			# cPanel is running
	isWebmin => 0,			# Webmin is running
	};

# object for handling output
our $log = new Console;				# output object

# mainline process
parseOptions();
$log->header unless $options->{notimes};
System->show;		# display system specifics
Network->show;		# display network specifics
$log->footer unless $options->{notimes};
exit;

# parse the command line and set options
sub parseOptions {
	foreach (@ARGV) {
		$options->{notimes} = 1 if (/^\-t|\-\-notimes$/);
		}
	}

##
# Dig for system information (hostname, CPU, etc.)
#
package System;

# display information about the system/server
sub show {
	my $class = shift;
	$log->exhibit("System:");
	$class->hostname;		# name of this server
	$class->processor;		# CPU details
	$class->memory;			# RAM details
	$class->storage;		# Disk storage details
	$class->executive;		# operating system
	$class->dashboard;		# control panel
	}

# display the hostname in use by the system
sub hostname {
	my $class = shift;
	$conf->{hostname} = `hostname`;
	$log->exhibit("Server hostname",$conf->{hostname});
	}

# display the processor & features
sub processor {
	my $class = shift;
	my $data = `cat /proc/cpuinfo`;
	my ($processor,$cores);
	$data =~ /model name\s+:\s(.+)\n/i; $processor = $1;
	$data =~ /^.*processor\s+:\s(\d+)\s/is; $cores = $1+1;
	$log->exhibit("Processor","$processor, $cores cores");
	}

# display the RAM size
sub memory {
	my $class = shift;
	my ($total,$free);
	open MEMINFO,"/proc/meminfo" or return;
	$total = <MEMINFO>; $free = <MEMINFO>;
	close MEMINFO;
	$total =~ /(\d+)/; $total = sprintf("%.2f",($1/1000000.0));
	$free =~ /(\d+)/; $free = sprintf("%.2f",($1/1000000.0));
	$log->exhibit("RAM",$total."G, ".$free."G free");
	}

# display the disk storage
sub storage {
	my $class = shift;
	my ($size,$used,$free,$avail);
	my $line = `df -hl | grep /\$`;
	$line =~ /.+?(\d+[KMG]).+?(\d+[KMG]).+?(\d+[KMG])/i;
	$size = $1; $used = $2; $free = $3;
	$log->exhibit("Disk Storage","$size, $used used, $free free");
	}

# display the operating system
sub executive {
	my $class = shift;
	my $os;
	if (-f "/etc/redhat-release") {
		$conf->{isRedhat} = 1; $conf->{isUbuntu} = 0;
		}
	else {
		$conf->{isRedhat} = 0; $conf->{isUbuntu} = 1;
		}
	open FILE,($conf->{isRedhat} ? "/etc/redhat-release" : "/etc/issue") or return;
	$os = <FILE>; close FILE;
	$os =~ s/\\[A-Za-z0-9]//g;	# strip escape sequences
	$log->exhibit("Operating System",$os);
	}
	
# display info about dashboard/control panel ()if any)
sub dashboard {
	my $class = shift;
	my ($test,$cp,$password,$url);
	# check for plesk
	$test = $conf->{isRedhat} ?  `rpm -q psa 2>/dev/null` : `dpkg -l psa 2>/dev/null`;
	if ($test =~ /build/i) {
		$conf->{isPlesk} = 1;
		$cp = $test;
		}
	$test = `/usr/local/cpanel/cpanel -V 2>/dev/null`;
	if ($test =~ /[A-Za-z0-9]+/) {
		$conf->{isCpanel} = 1;
		$cp = $test;
		}
	if (-e "/usr/share/webmin") {
		$conf->{isWebmin} = 1;
		$cp = "Webmin";
		}
	$log->exhibit("Control Panel",$cp);
	if ($conf->{isPlesk}) {
		$cp =~ /psa[ -]+(\d+\.\d+)/i;
		$test = $1; $test =~ tr/[0-9]//cd;
		if ($test le '1019') {
			$password = `cat /etc/psa/.psa.shadow`;
			}
		else {
			$password = `/usr/local/psa/bin/admin --show-password`;
			}
		$log->exhibit(" Plesk login","admin => $password");
		$url = "http://".`curl -sk curlmyip.de`.":8880/login_up.php3?login_name=admin&passwd=$password";
		$log->exhibit(" Plesk url",$url);
		}
	}

##
# Dig for network information (IPs, listeners,etc.)
#
package Network;

# display information about the network
sub show {
	my $class = shift;
	$log->exhibit("Network:");
	$class->externalIPv4;
	$class->externalIPv6;
	$class->networkIP;
	$class->privateIP;
	}

# display the external IP address (IPv4)
sub externalIPv4 {
	my $class = shift;
	$log->exhibit("External IP (IPv4)",`curl -s -4 icanhazip.com`);
	}

# display the external IP address (IPv6)
sub externalIPv6 {
	my $class = shift;
	$log->exhibit("External IP (IPv6)",`curl -s -6 icanhazip.com`);
	}

# display the network (eth0) IP address
sub networkIP {
	my $class = shift;
	`ip addr` =~ /eth0.+?inet\s+(\d+\.\d+\.\d+\.\d+)/is;
	$log->exhibit("Network IP (eth0)",$1);
	}

# display the private (eth1) IP address
sub privateIP {
	my $class = shift;
	`ip addr` =~ /eth1.+?inet\s+(\d+\.\d+\.\d+\.\d+)/is;
	$log->exhibit("Private IP (eth1)",$1);
	}

##
# Console.pm - Console (STDOUT) handler
#
package Console;
use constant DEFAULT_PREFIX		=> ':';		# default line prefix
use constant LABEL_SIZE			=> 24;		# max length of value label

##
# Constructor:
#
#	@param string $prefix		: (optional) prefix to output
#	@return object
#
sub new {
	my $class = shift;
	my $this = {};
	bless $this,$class;
	$this->{prefix} = shift;	# get any prefix
	$this->{prefix} ||= DEFAULT_PREFIX;	# use default if none
	$this->{prefix} .= " ";		# append a space
	$0 =~ /(.*\/)*([^.]+)(\..*)*/;	# extract
	$this->{script} = ucfirst $2;	#  our name
	$this->{script} = "Ferret" if ($this->{script} =~ /[0-9]+/);
	$this->{bold} = `tput bold`; chomp($this->{bold});
	$this->{normal} = `tput sgr0`; chomp($this->{normal});
	return $this;
	}

##
# write to STDOUT
#
#	@param mixed $param			# one or more output strings
#
sub write {
	my $this = shift;
	my $msg;
	print(STDOUT $this->{prefix},$msg,"\n") while ($msg = shift);
	}

##
# read from STDIN
#
#	@param string				: (optional) prompt text
#	@param string				: (optional) default value
#	@return string				: input string or undef
#
sub read {
	my ($this,$prompt,$default) = @_;
	print STDOUT $this->{prefix};
	print STDOUT $prompt if $prompt;
	print STDOUT " [$default]" if $default;
	print STDOUT ": " if $prompt;
	my $buffer = readline(STDIN);
	chomp $buffer;
	$buffer = $default if ($default and !$buffer);
	return $buffer;
	}

##
# confirm a decision or action
#
#	@param string				: prompt text
#	@return boolean				: 0=false, 1=true
#
sub confirm {
	my ($this,$prompt) = @_;
	print STDOUT $this->{prefix},$prompt," [N,y]? ";
	my $buffer = readline(STDIN);
	chomp $buffer;
	return (!$buffer or $buffer=~/n/i) ? 0 : 1;
	}

##
# display a header line followed by underscores
#
#	@param string $header		: (optional) text for header line
#
sub header {
	my ($this,$title) = @_;
	unless ($title) {
		my $ltime = localtime;
		$title = sprintf("%s start: %s",$this->{script},$ltime);
		}
	print STDOUT "\n";
	$this->write($title,('-' x length($title)));
	}

##
# display a footer line preceeded by underscores
#
#	@param string $footer		: (optional) text for footer line
#
sub footer {
	my ($this,$title) = @_;
	unless ($title) {
		my $ltime = localtime;
		$title = sprintf("%s ended: %s",$this->{script},$ltime);
		}
	$this->write(('-' x length($title)),$title);
	print STDOUT "\n";
	}

##
# exhibit a label (& value)
#
#	@param string $label			: label of the value
#	@param mixed $value			: (optional) value to show
#
sub exhibit {
	my ($this,$label,$value) = @_;
	my $trailer = (length($label) >= LABEL_SIZE) ? "" :	(' 'x(LABEL_SIZE-length($label)));
	if (substr($label,-1) eq ':') { #subheading
		$this->write($this->{bold}.$label.$this->{normal});
		}
	else { #label & value
		$value =~ tr/\x20-\x7f//cd;	# only printable
		$value =~ s/\s{2,}/ /g;		# strip multiple spaces
		$value =~ s/\s+$//;			# strip trailing white space
		$this->write(" ".$label.$trailer." ".$this->{bold}.$value.$this->{normal});
		}
	}

-1;
