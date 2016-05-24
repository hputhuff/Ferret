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
#		-a or -all = show all sections
#		-c or --connections = show network connections
#		-h or --help = show this information
#		-l or --listeners = show listening daemons
#		-n or --network = show network information
#		-s or --system = show system specifics
#		-t or --times = show start/stop times
#		-w or --websites = show hosted website details
#	May 2016 by Harley H. Puthuff
#	with a lot of ideas from Samir Jafferali's shell script rsi.sh
##

# testing only #
# use Data::Dumper;$Data::Dumper::Indent=1;$Data::Dumper::Quotekeys=1;$Data::Dumper::Useqq=1;

# global variables

# help information

our @helpInformation = (
	" ",
	"Ferret - Show System Information",
	" ",
	"Command:",
	"    perl <(curl -ks https://raw.githubusercontent.com/hputhuff/Ferret/master/ferret.pl) [options]",
	"Options:",
	"    -a or -all = show all sections",
	"    -c or --connections = show network connections",
	"    -h or --help = show this information",
	"    -l or --listeners = show listening daemons",
	"    -n or --network = show network information",
	"    -s or --system = show system specifics",
	"    -t or --times = show start/stop times",
	"    -w or --websites = show hosted website details",
	"May 2016 by Harley H. Puthuff",
	" "
	);

# command line options:

our $options = {
	all => 0,				# show all sections
	server => 0,			# show system specifics
	network => 0,			# show network specifics
	listeners => 0,			# show listening daemons
	connections => 0,		# show network connections
	times => 0,				# show start/stop times
	websites => 0,			# show hosted websites
	help => 0,				# show help information
	};
	
# evaluated configuration settings:

our $conf = {
	hostname => undef,		# hostname for server
	redhat => 0,			# Redhat or CentOs
	ubuntu => 0,			# Ubuntu, Mint, Debian
	plesk => 0,				# Plesk is running
	cpanel => 0,			# cPanel is running
	webmin => 0,			# Webmin is running
	apache2 => 0,			# running apache 2
	httpd => 0,				# running httpd
	nginx => 0,				# running nginx
	postfix => 0,			# running postfix
	sendmail => 0,			# running sendmail
	mysqld => 0				# running mysql server
	};

# object for handling output

our $log = new Console;

# local services hash (as needed)

our $services = undef;

# mainline process

parseOptions();		# load options flags
$log->header if $options->{times};
if ($options->{help}) {
	showHelpInformation();
	}
else {
	getLocalServices();	# load local services table
	System->show		if ($options->{all} || $options->{server});
	Network->show		if ($options->{all} || $options->{network});
	Listeners->show		if ($options->{all} || $options->{listeners});
	Connections->show	if ($options->{all} || $options->{connections});
	Websites->show		if ($options->{all} || $options->{websites});
	}
$log->footer if $options->{times};
exit;

# parse the command line and set options

sub parseOptions {
	foreach (@ARGV) {
		if (/^--/) {
			$options->{all} = 1				if /all/;
			$options->{times} = 1			if /times/;
			$options->{connections} = 1		if /connections/;
			$options->{server} = 1			if /server/;
			$options->{network} = 1			if /network/;
			$options->{listeners} = 1		if /listeners/;
			$options->{websites} = 1		if /websites/;
			$options->{help} = 1			if /help/;
			next;
			}
		$options->{all} = 1					if /a/;
		$options->{times} = 1				if /t/;
		$options->{server} = 1				if /s/;
		$options->{network} = 1				if /n/;
		$options->{listeners} = 1			if /l/;
		$options->{connections} = 1			if /c/;
		$options->{websites} = 1			if /w/;
		$options->{help} = 1				if /h/;
		}
	$options->{server} = $options->{network} = 1
		unless (
			$options->{help} ||
			$options->{all} ||
			$options->{server} ||
			$options->{network} ||
			$options->{listeners} ||
			$options->{connections} ||
			$options->{websites}
			);
	}

# load the local services table from /etc/services

sub getLocalServices {
	return if (ref $services eq ref {});
	$services = {};
	open SERVICES,"/etc/services";
	while (<SERVICES>) {
		$services->{"$2"} = $1 if (/^(\S+)\s+(\d+)\/tcp/i);
		}
	close SERVICES;
	}

# get a service name or return port

sub getServiceName {
	my $port = shift;
	my $name = $services->{$port};
	return $name ? $name : $port;
	}

# show the help information

sub showHelpInformation {
	$log->write(@helpInformation);
	}

##
#	Dig for system information (hostname, CPU, etc.)
##
package System;

use constant MEGABYTE => 1048576.0;	# one megabyte

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
	$conf->{hostname} = `uname -n`; chomp $conf->{hostname};
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
	$total =~ /(\d+)/; $total = sprintf("%.2f",($1/MEGABYTE)); # in GB
	$free =~ /(\d+)/; $free = sprintf("%.2f",($1/MEGABYTE));   # in GB
	$log->exhibit("RAM",$total."G, ".$free."G free");
	}

# display the disk storage

sub storage {
	my $class = shift;
	my ($size,$used,$free,$avail);
	my $line = `df -hl | grep /\$`;
	$line =~ /.+?([0-9.]+[KMG]).+?([0-9.]+[KMG]).+?([0-9.]+[KMG])/i;
	$size = $1; $used = $2; $free = $3;
	$log->exhibit("Disk Storage","$size, $used used, $free free");
	}

# display the operating system

sub executive {
	my $class = shift;
	my $os;
	if (-f "/etc/redhat-release") {
		$conf->{redhat} = 1; $conf->{ubuntu} = 0;
		}
	else {
		$conf->{redhat} = 0; $conf->{ubuntu} = 1;
		}
	open FILE,($conf->{redhat} ? "/etc/redhat-release" : "/etc/issue") or return;
	$os = <FILE>; close FILE;
	$os =~ s/\\[A-Za-z0-9]//g;	# strip escape sequences
	$log->exhibit("Operating System",$os);
	}
	
# display info about dashboard/control panel ()if any)

sub dashboard {
	my $class = shift;
	my ($test,$cp,$build,$password,$url);
	# check for plesk
	$test = $conf->{redhat} ?  `rpm -q psa 2>/dev/null` : `dpkg -l psa 2>/dev/null`;
	if ($test =~ /build/i) {
		$conf->{plesk} = 1;
		$cp = $test;
		}
	# check for cPanel
	$test = `/usr/local/cpanel/cpanel -V 2>/dev/null`;
	if ($test =~ /[A-Za-z0-9]+/) {
		$conf->{cpanel} = 1;
		$cp = "cPanel ".$test;
		}
	# check for Webmin
	if (-e "/usr/share/webmin") {
		$conf->{webmin} = 1;
		$cp = "Webmin";
		}
	$log->exhibit("Control Panel",$cp);
	if ($conf->{plesk}) {
		$cp =~ /^psa.+?(\d+\.\d+\.\d+)/i;
		$build = $1; $build =~ tr/[0-9]//cd;
		if ($build <= 1019) {
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
#	Dig for network information (IPs, listeners,etc.)
##
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
	$log->exhibit("External IP (IPv4)",`curl -s -4 curlmyip.de`);
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
#	Dig for listening daemons
##
package Listeners;

# display information about who's listening

sub show {
	my $class = shift;
	my ($netstat,$ps,$listeners,$port,$service,$process,$name,$daemon,$user);
	$log->exhibit("Who's listening (ports):");
	$netstat = `\\netstat -pntl`;
	$ps = `\\ps aux`;
	%{$listeners} = $netstat =~ /tcp.+?\:+(\d{2,}).+?listen.+?(\d+\/\w+)/gi;
	foreach (sort {$a<=>$b} keys %{$listeners}) {
		$port = $_;	$service = main::getServiceName($port);
		$service = "" if ($port eq $service);
		($process,$name) = split /\//,$listeners->{$_};
		$ps =~ /^(\w+)\s+$process(\s+\S+){8}\s+(\S+)/m;
		$daemon = $3; $user = $1;
		$log->exhibit("$port $service","$daemon as $user");
		# try to glean info about the system from listeners #
		if ($port =~ /(80|443|7080)/) {
			$conf->{apache2} = 1 if ($daemon =~ /apache2/i);
			$conf->{httpd} = 1 if ($daemon =~ /httpd/i);
			$conf->{nginx} = 1 if ($daemon =~ /nginx/i);
			}
		if ($port =~ /(25|465|587)/) {
			$conf->{postfix} = 1 if ($daemon =~ /postfix/i);
			$conf->{sendmail} = 1 if ($daemon =~ /sendmail/i);
			}
		if ($port =~ /3306/) {
			$conf->{mysqld} = 1 if ($daemon =~ /mysql/i);
			}
		}
	}

##
#	Dig for network connections
##
package Connections;

# Show connections

sub show {
	my $class = shift;
	my ($localIp,$localPort,$remoteIp,$remotePort,$incoming,$outgoing);
	my ($connections,$ip,$counts,$port,$service);
	$incoming = {}; $outgoing={};
	while ((`\\netstat -n | grep tcp`) =~
		/^tcp.+?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+).+?(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}:\d+)/igm) {
		($localIp,$localPort) = split /:/,$1;
		($remoteIp,$remotePort) = split /:/,$2;
		next if ($localIp eq $remoteIp);
		if ($localPort >= 10240) {
			# connection is outgoing
			if ($outgoing->{$remoteIp}) {
				# remote IP already in table
				if ($outgoing->{$remoteIp}->{$remotePort}) {
					$outgoing->{$remoteIp}->{$remotePort}++;
					}
				else {
					$outgoing->{$remoteIp}->{$remotePort} = 1;
					}
				}
			else {
				# add remote IP to table
				$outgoing->{$remoteIp} = {};
				$outgoing->{$remoteIp}->{$remotePort} = 1;
				}
			}
		else {
			# connection is incoming
			if ($incoming->{$remoteIp}) {
				# remote IP already in table
				if ($incoming->{$remoteIp}->{$localPort}) {
					$incoming->{$remoteIp}->{$localPort}++;
					}
				else {
					$incoming->{$remoteIp}->{$localPort} = 1;
					}
				}
			else {
				# add remote IP to table
				$incoming->{$remoteIp} = {};
				$incoming->{$remoteIp}->{$localPort} = 1;
				}
			}
		}
	@{$connections} = sort keys(%{$incoming});
	if (scalar @{$connections}) {
		$log->exhibit("Inbound connections:");
		foreach (@{$connections}) {
			$ip = $_; $counts = "";
			foreach (sort keys(%{$incoming->{$ip}})) {
				$port = $_; $service = main::getServiceName($port);
				if ($incoming->{$ip}->{$port} > 1) {
					$counts .= "$service($incoming->{$ip}->{$port}) ";
					}
				else {
					$counts .= "$service ";
					}
				}
			$log->exhibit($ip,$counts);
			}
		}
	@{$connections} = sort keys(%{$outgoing});
	if (scalar @{$connections}) {
		$log->exhibit("Outbound connections:");
		foreach (@{$connections}) {
			$ip = $_;
			$counts = "";
			foreach (sort keys(%{$outgoing->{$ip}})) {
				$port = $_; $service = main::getServiceName($port);
				if ($outgoing->{$ip}->{$port} > 1) {
					$counts .= "$service($outgoing->{$ip}->{$port}) ";
					}
				else {
					$counts .= "$service ";
					}
				}
			$log->exhibit($ip,$counts);
			}
		}
	}

##
#	Dig for hosted websites
##
package Websites;

# Show hosted websites

sub show {
	}

##
#	Console.pm - Console (STDOUT) handler
##
package Console;
use constant DEFAULT_PREFIX		=> ':';		# default line prefix
use constant LABEL_SIZE			=> 20;		# max length of value label

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
	$this->{script} = $2;	#  our name
	$this->{script} = "ferret" if ($this->{script} =~ /[0-9]+/);
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
#	Note to self: any $label value ending in ':' is always a subheading
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
