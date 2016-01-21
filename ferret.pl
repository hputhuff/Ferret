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
#	January 2016 by Harley H. Puthuff
#	Copyright 2016, Harley H. Puthuff
#

use strict;
use feature "switch";
no if $] >= 5.017011, warnings => 'experimental::smartmatch';

our $log = new Console;

# Begin:

$log->header;

# Exhibit general system information:

SysInfo->showHostname;
SysInfo->showExternalIPv4;
SysInfo->showExternalIPv6;
SysInfo->showPublicIP;
SysInfo->showPrivateIP;

# Exhibit network information:

# Finish:

$log->footer;
exit;

##
# Dig for system information (hostname, IPs, etc.)
#

package SysInfo;

# display the hostname in use by the system

sub showHostname {
	my $class = shift;
	$log->exhibit("Server hostname",`hostname`);
	}

# display the external IP address (IPv4)

sub showExternalIPv4 {
	my $class = shift;
	$log->exhibit("External IP (IPv4)",`curl -s -4 icanhazip.com`);
	}

# display the external IP address (IPv6)

sub showExternalIPv6 {
	my $class = shift;
	$log->exhibit("External IP (IPv6)",`curl -s -6 icanhazip.com`);
	}

# display the public (eth0) IP address

sub showPublicIP {
	my $class = shift;
	`ip addr` =~ /eth0.+?inet\s+(\d+\.\d+\.\d+\.\d+)/is;
	$log->exhibit("Public IP",$1);
	}

# display the private (eth1) IP address

sub showPrivateIP {
	my $class = shift;
	`ip addr` =~ /eth1.+?inet\s+(\d+\.\d+\.\d+\.\d+)/is;
	$log->exhibit("Private IP",$1);
	}

##
# Console.pm - Console (STDOUT) handler
#

package Console;

use constant DEFAULT_PREFIX		=> '=';		# default line prefix
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
# exhibit a value with a label
#
#	@param string $label			: label of the value
#
sub exhibit {
	my ($this,$label,$value) = @_;
	my $trailer = (length($label) >= LABEL_SIZE) ? "" :	(' ' x (LABEL_SIZE - length($label)));
	$value =~ s/\s*//g;
	$this->write($label.$trailer.": ".$this->{bold}.$value.$this->{normal});
	}

-1;
