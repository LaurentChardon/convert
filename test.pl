#!/usr/bin/perl

#
# connect to FreshPorts 2 and give me a list of stuff
#

use DBI;
use strict;

my $FILE_MAKEFILE    = "Makefile";
my $FILE_DESCRIPTION = "pkg-descr";
my $FILE_COMMENT     = "pkg-comment";

my %FilesWhichPromptRefresh = (
    $FILE_MAKEFILE    => "1",
    $FILE_DESCRIPTION => "2",
    $FILE_COMMENT     => "4",
);


print $FilesWhichPromptRefresh{Makefile} ."ee\n";
