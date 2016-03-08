# Project: Ferret

'ferret' out system information from linux host

As a Linux system administrator for Rackspace I have occasion to
login to many servers every day. Each one is different and each
one has its own configuration peculiarities.

With that in mind, and because I am a great advocate of Perl
regular expressions, I wrote the ferret(.pl) script as a way
of quickly extracting pertinent system information and presenting
it in a brief and easy to understand format on the console/terminal.

This script is based on ideas and techniques in Samir Jafferali's
script rsi.sh, which does something similar. My thanks to Samir.

After logging into a server as root, simply run this command to ferret
out a system summary:

perl <(curl -ks https://raw.githubusercontent.com/hputhuff/Ferret/master/ferret.pl)

February, 2016
/s/ Harley H. Puthuff
