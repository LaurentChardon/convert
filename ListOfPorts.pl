#!/usr/bin/perl

#
# connect to FreshPorts 2 and give me a list of stuff
#

use DBI;
use strict;

   my $dbh_pg;
   my $sql;
   my $sth_pg;
   my $num_ports;
   my $row;


$dbh_pg = DBI->connect('DBI:Pg:dbname=FreshPorts2', 'dan', '');
if ($dbh_pg) {
   print "connected\n";

   $sql = "select id, element_id, description, category_id    
             from ports \                          
            limit 10";                             
                                                   
   print "sql is $sql\n";                          
                                                   
   $sth_pg = $dbh_pg->prepare($sql);               
   $sth_pg->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $num_ports = 0;
   while ($row=$sth_pg->fetchrow_hashref()) {
      print $row->{"id"} . " " . $row->{"name"} . " " .  $row->{"primary_category_id"} . "\n";
      $num_ports++;
   }
   $sth_pg->finish();
   $dbh_pg->disconnect();
} else {
   print "Cannot connect to Postgres server: $DBI::errstr\n";
   print " db connection failed\n";
}
