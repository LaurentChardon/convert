#!/usr/bin/perl -w
use strict;

use lib '/usr/local/etc/freshports/updates';
use ports;
 
use DBI;

&main();


sub main {
   my $dbh_mysql;
   my $sql;
   my $sth;
   my $num_ports;
   my @row;

   $dbh_mysql = DBI->connect('dbi:mysql:freshports','root','xyzzy');

   if (!$dbh_mysql) {
      die "could not connect to FreshPorts1\n";
   }

   $sql = "select * 
             from ports \
            limit 10";

   print "sql is $sql\n";

   $sth = $dbh_mysql->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $num_ports = 0;
   while (@row=$sth->fetchrow_array) {
      print $row{"id"} . " " . $row["name"] . " " .  $row["description"] . "\n";
      $num_ports++;
   }

#   foreach $dirname (@USERS) {
#      $Bcc .= $dirname . ',';
#      print "found $dirname\n";
#   }


   $dbh_mysql->disconnect();
}

