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
   my $row;
   my %Notices;

   $dbh_mysql = DBI->connect('dbi:mysql:freshports','root','xyzzy');

   if (!$dbh_mysql) {
      die "could not connect to FreshPorts1\n";
   }

   $sql = "select *
            from watch_notice \
            limit 10";

   print "sql is $sql\n";

   $sth = $dbh_mysql->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $num_ports = 0;
   while ($row=$sth->fetchrow_hashref()) {
      print $row->{"id"} . " " . $row->{"frequency"} . " " .  $row->{"description"} . "\n";

      $Notices{$row->{"frequency"}} = $row->{"id"};
      print $Notices{$row->{"frequency"}} . "\n";
      $num_ports++;
   }

   $dbh_mysql->disconnect();
}

