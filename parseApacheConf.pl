#!/usr/bin/perl
##
#	parse Apache httpd.conf & extract VirtualHost(s)
#	April 2016 by Harley H. Puthuff
#

print "Start !\n";

my $configuration = readfile("/etc/httpd/conf/httpd.conf");
foreach ($configuration =~ /<VirtualHost.+?\/VirtualHost>/igs) {
        $contents = $_ . "\n";
        next unless /.+?ServerName\s+(\S+).+/is;
        $filename = "./".$1.".conf";
        open CONF,">",$filename or die "can't open output file: $filename !";
        print CONF $contents;
        close CONF;
        }

print "Done !\n";
exit;

# read the conf file into a big buffer

sub readfile {
        my $file = shift;
        local $/=undef;
        open FILE,$file or return undef;
        $buffer = <FILE>;
        close FILE;
        return $buffer;
        }