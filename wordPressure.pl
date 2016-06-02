#!/usr/bin/perl
##
#                        _ ____                                   
# __      _____  _ __ __| |  _ \ _ __ ___  ___ ___ _   _ _ __ ___ 
# \ \ /\ / / _ \| '__/ _` | |_) | '__/ _ \/ __/ __| | | | '__/ _ \
#  \ V  V / (_) | | | (_| |  __/| | |  __/\__ \__ \ |_| | | |  __/
#   \_/\_/ \___/|_|  \__,_|_|   |_|  \___||___/___/\__,_|_|  \___|
# ----------------------------------------
#	wordPressure.pl: squeeze the vulnerabilities out of WordPress sites
#	run with: wordPressure.pl [-hqtv] [DocumentRoot]
#	options:
#		[DocumentRoot] = only process this directory
#		-h or --help = show this information
#		-q or --quiet = no console output
#		-t or --test[ing] = run in test mode (read-only)
#		-v or --verbose = show process information
#	May 2016 by Harley H. Puthuff
#	Copyright 2016, Harley H. Puthuff
##

# testing only #
use Data::Dumper;$Data::Dumper::Indent=1;$Data::Dumper::Quotekeys=1;$Data::Dumper::Useqq=1;

# for -h or --help

our @helpInformation = (
	" ",
	"wordPressure.pl - Squeeze vulnerabilities out of WordPress sites",
	" ",
	"Command:",
	"    wordPressure.pl [-hqtv] [DocumentRoot]",
	"Options:",
	"    [DocumentRoot] = only process this directory",
	"    -h or --help = show this information",
	"    -q or --quiet = suppress console output",
	"    -t or --test[ing] = run in test mode (read-only)",
	"    -v or --verbose = show process information",
	"May 2016 by Harley H. Puthuff",
	"Copyright 2016, Your Showcase",
	" "
	);

# globals

our $options = {
	help => 0,				# show help information
	quiet => 0,				# suppress console output
	test => 0,				# testing mode
	verbose => 0,			# show process info
	documentRoot => undef,	# path to single DocumentRoot
	};

our $apacheCommand = q/apachectl -S 2>&1 | grep -i '\.conf'/; # the command to peruse vhosts
our $log = new Console;		# manage output
our $files = 0;				# count of .conf files processed
our $sites = 0;				# count of DocumentRoot paths processed
our $wpSites = 0;			# count of WordPress sites
our $wpSecured = 0;			# count of WordPress sites secured

our $apachectl = undef;		# string output of apachectl
our %confFiles = ();		# list of apache .conf files & server names
our @documentRoots = ();	# list of document root directories
our @wpDocumentRoots = ();	# list of WordPress Directories

# mainline process

parseOptions();
$log->header unless $options->{quiet};
$log->write("**** Running in TEST mode ****") if $options->{test};
if ($options->{help}) {
	showHelpInformation();
	}
elsif ($our->{documentRoot}) {
	processDocumentRoot($our->{documentRoot});
	}
else {
	processConfFiles();
	}
$log->write("Completed: $files files, $sites sites, $wpSites WP sites, $wpSecured secured")
	unless $options->{quiet};
$log->footer unless $options->{quiet};
exit;

# parse the command line and set options

sub parseOptions {
	foreach (@ARGV) {
		if (/^--[A-Za-z0-9]+/) {
			$options->{help} = 1	if /help/;
			$options->{quiet} = 1	if /quiet/;
			$options->{test} = 1	if /test/;
			$options->{verbose} = 1	if /verbose/;
			next;
			}
		elsif (/^-[A-Za-z0-9]+/) {
			$options->{help} = 1	if /h/;
			$options->{quiet} = 1	if /q/;
			$options->{test} = 1	if /t/;
			$options->{verbose} = 1	if /v/;
			}
		else {
			$options->{documentRoot} = $_;
			}
		}
	}

# show the help information

sub showHelpInformation {
	$log->write(@helpInformation);
	}

# read entire file into a string

sub readfile {
	my $file = shift;
	local $/=undef;
	open FILE,$file or return undef;
	$buffer = <FILE>;
	close FILE;
	return $buffer;
	}

# produce a sorted array of unique items

sub unique {
	my @source = @_;
	my %result = ();
	foreach my $entry (@source) {
		$result{$entry} ++;
		}
	return sort(keys %result);
	}

# obtain and process the apache .conf files

sub processConfFiles {
	my ($site,$file);
	$apachectl = `$apacheCommand`;
	return unless $apachectl;
	while ($apachectl =~ /.+\s+(\S+)\s+\((\S+)\:\d+\)/igm) {
		if (ref($confFiles{$2}) eq 'ARRAY') {
			push @{$confFiles{$2}},$1;
			}
		else {
			$confFiles{$2} = [$1];
			}
		}
	foreach (sort keys(%confFiles)) {
		$file = $_; $site = join(',',@{$confFiles{$file}});
		$log->write(" .conf: $file for $site") if $options->{verbose};
		++$files;
		}
	}

# process a single .conf file

sub processOneConfFile {
	my $file = shift;
	my ($contents,$serverName,$logFile,$lastLogFile);
	++$files;
	$log->write("File: $file") unless $options->{quiet};
	$contents = readfile("$options->{vhosts}/$file");
	foreach ($contents =~ /<VirtualHost.+?VirtualHost>/igs) {
		next unless /ServerName\s+(\S+).+?(Custom|Transfer)Log\s+(\S+)/is;
		$serverName = $1; $logFile = $3;
		processVhost($serverName,$logFile) unless ($logFile eq $lastLogFile);
		$lastLogFile = $logFile;
		}
	}
	
# process a single virtual host

sub processVhost {
	my ($serverName,$logFile) = @_;
	my ($path,$file,$command);
	return unless (-e $logFile);
	push(@logFiles,$logFile); # keep track of files
	$logFile =~ /^(.+)\/(.+)$/; $path = $1; $file = $2;
	$command = 
		"cd $path; " . WEBALIZER .
		" -c " . CONFIGURATION .
		" -n $serverName -r $serverName -s $serverName $file";
	$log->write("  Site: $serverName, Log: $logFile") unless $options->{quiet};
	$log->write("  Command: $command") if $options->{verbose};
	`$command` unless $options->{test};
	++$sites;
	}

# reset log files once per month

sub resetLogs {
	my ($logfile,$path,$file,$command);
	$log->write("Periodic Apache Log Files Archive:");
	`systemctl stop httpd.service`;
	sleep 10;
	foreach (@logFiles) {
		$logfile = $_;
		$logfile =~ /^(.+)\/(.+)$/; $path = $1; $file = $2;
		$command = "/usr/bin/gzip -c $logfile >> $path/access_log.archive.gz; rm $logfile";
		if ($options->{test}) {
			$log->write("  command: $command");
			}
		else {
			`$command`;
			}
		$log->write("  Archived: $file") unless ($options->{quiet});
		}
	`systemctl start httpd.service`;
	}

##
#	Console.pm - Console (STDOUT) handler
##
package Console;
use constant DEFAULT_PREFIX		=> '>';		# default line prefix
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
	$this->{script} = "logStats" if ($this->{script} =~ /[0-9]+/);
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
