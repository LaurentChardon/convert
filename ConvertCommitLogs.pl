#!/usr/bin/perl

#
# connect to FreshPorts 2 and give me a list of stuff
#

use DBI;
use strict;

my $commit_log_id_seq          = "commit_log_id_seq";
my $commit_log_elements_id_seq = "commit_log_elements_id_seq";

&main();

sub main {

   my $dbh_mysql;
   my $dbh_pg;

   my $sql;
   my $sth_mysql;
   my $sth_pg;

   my $num_commits;
   my $row;

   $dbh_mysql = DBI->connect('dbi:mysql:freshports','root','xyzzy');

   if (!$dbh_mysql) {
      die "could not connect to FreshPorts1\n";
   }

   $dbh_pg = DBI->connect('DBI:Pg:dbname=FreshPorts2', 'dan', "");
   if (!$dbh_pg) {
      die "could not connect to FreshPorts2\n";
   }

   print "connected\n";

   $sql = "select id, date_format(date_added, \"%Y-%m-%d %H:%i:%S\") date_added, commit_date, committer, update_description \
             from change_log\
            order by id limit 10";

   print "sql is $sql\n";

   $sth_mysql = $dbh_mysql->prepare($sql);
   $sth_mysql->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $num_commits = 0;
   while ($row=$sth_mysql->fetchrow_hashref()) {
      my $id   = $row->{"id"};
      my $name = $row->{"username"};


      print $row->{"id"} . " " . $row->{"date_added"} . "\n";
      my $commit_id = AddCommit($row, $dbh_pg);

#      TransferWatchLists($id, $user_id, $dbh_mysql, $dbh_pg);

      $num_commits++;
   }

#   $sth_pg->finish();
   $dbh_pg->disconnect();

   $sth_mysql->finish();
   $dbh_mysql->disconnect();
}


sub AddCommit($;$) {
   my $row = shift;
   my $dbh = shift;
   my $sth;
   my $sql;

   my $date_added  = $dbh->quote(ConvertNullToString($row->{date_added}));
   my $commit_date = $dbh->quote(ConvertNullToString($row->{commit_date}));
   my $committer   = $dbh->quote(ConvertNullToString($row->{committer}));
   my $description = $dbh->quote(ConvertNullToString($row->{update_description}));
   
   
   my $id = GetNextValue($commit_log_id_seq, $dbh);
   $sql = "insert into commit_log (id, message_id, message_date, message_subject, date_added, 
                                   commit_date, committer, description)
               values ($id, 'N/A', $date_added, 'N/A', $date_added, $commit_date, $committer, $description)";
   print "AddCommit sql = $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $sth->finish();
}

sub TransferWatchLists($;$;$;$) {
   my $user_id_mysql = shift;
   my $user_id_pg    = shift;
   my $dbh_mysql     = shift;
   my $dbh_pg        = shift;

   my $sth;
   my $sql;
   my $row;    
   $sql = "select id, name from watch where owner_user_id = $user_id_mysql";
   print "TransferWatchLists sql = $sql\n";
   
   $sth = $dbh_mysql->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   my $num_watch_lists = 0;
   while ($row = $sth->fetchrow_hashref()) {
      my $watch_list_id_mysql = $row->{"id"};
      my $name                = $row->{"name"};

      print "watch list " . $row->{"id"} . " " . $row->{"name"} . "\n";

      my $watch_list_id_pg = GetWatchListId($user_id_pg, $name, $dbh_pg);
      if (!defined($watch_list_id_pg)) {
         $watch_list_id_pg = CreateWatchList($user_id_pg, $name, $dbh_pg);
      }

      TransferWatchListItems($watch_list_id_mysql, $watch_list_id_pg, $dbh_mysql, $dbh_pg);
      $num_watch_lists++;
   }

   $sth->finish();
}

sub GetWatchListId($;$;$) {
   my $user_id_pg = shift;
   my $name       = shift;
   my $dbh_pg     = shift;

   my $sth;
   my $sql;
   my @row;
    
   my $lowername = $dbh_pg->quote($name);
   $sql = "select id from watch_list where user_id = $user_id_pg and lower(name) = $lowername";
   print "GetWatchListId sql = $sql\n";
      
   $sth = $dbh_pg->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
   
   @row = $sth->fetchrow_array();
    
   $sth->finish();
   
   return $row[0];
}

sub TransferWatchListItems($;$;$) {
   my $watch_list_id_mysql = shift;
   my $watch_list_id_pg    = shift;
   my $dbh_mysql           = shift;
   my $dbh_pg              = shift;
   my $sth;      
   my $sql;
   my $row;

   $sql = "select port_id from watch_port where watch_id = $watch_list_id_mysql";
   print "TransferWatchListItems sql = $sql\n";

   $sth = $dbh_mysql->prepare($sql);

   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   my $num_watch_list_items = 0;
   while ($row=$sth->fetchrow_hashref()) {   
      my $port_id_mysql = $row->{"port_id"};

      print "watch list item $port_id_mysql\n";

      my $port_element_id = GetPortElementId($port_id_mysql, $dbh_mysql, $dbh_pg);

      AddToWatchList($watch_list_id_pg, $port_element_id, $dbh_pg);

      $num_watch_list_items++;
   }

   $sth->finish();
}

sub AddToWatchList($;$) {
   my $watch_list_id_pg = shift;  
   my $port_element_id  = shift;
   my $dbh              = shift;
   my $sth;
   my $sql;
   
   $sql = "insert into watch_list_element (watch_list_id, element_id) values ($watch_list_id_pg, $port_element_id)";
   print "AddToWatchList sql = $sql\n";
    
   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
           
   $sth->finish();
}


sub GetPortElementId($;$;$) {
   my $port_id_mysql = shift;
   my $dbh_mysql     = shift;
   my $dbh_pg        = shift;

   my $category_id = GetPortCategory($port_id_mysql, $dbh_mysql);

   if (!defined($category_id)) {
      die "GetPortElementId failed to find a category for port $port_id_mysql\n";
   }

   my $portname = GetPortName($port_id_mysql, $dbh_mysql);
           
   if (!defined($portname)) {
      die "GetPortElementId failed to find a name for port $port_id_mysql\n";
   }

   my $category_name = GetCategoryName($category_id, $dbh_mysql);
   if (!defined($category_name)) {
      die "GetPortElementId failed to find a name for category $category_id\n";
   }

   my $port_element_id = GetIDFromPath("ports/$category_name/$portname", $dbh_pg);

   if (!defined($port_element_id)) {
      die "GetPortElementId failed to find an element id for ports/$category_name/$portname\n";
   }

   return $port_element_id;

}

sub GetPortCategory($;$) {
   my $port_id = shift;
   my $dbh     = shift;
   my @row;

   my $sql;
   my $sth;

   $sql = "select primary_category_id from ports where id = $port_id";

   print "GetPortCategory sql = $sql\n";
      
   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   @row = $sth->fetchrow_array();

   $sth->finish();

   return $row[0];
}

sub GetCategoryName($;$) {
   my $category_id = shift;
   my $dbh     = shift;
   my @row;

   my $sql;
   my $sth;

   $sql = "select name from categories where id = $category_id";

   print "GetCategoryName sql = $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
    
   @row = $sth->fetchrow_array();
   
   $sth->finish();
   
   return $row[0];
}   

sub GetPortName($;$) {
   my $port_id = shift;
   my $dbh     = shift;
   my @row;
      
   my $sql;
   my $sth;

   $sql = "select name from ports where id = $port_id";

   print "GetPortName sql = $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   @row = $sth->fetchrow_array();

   $sth->finish();

   return $row[0];
}


sub GetUser($;$) {
   my $username = shift;
   my $dbh      = shift;
   my $sth;
   my $sql;
   my @row;

   my $lowerusername = $dbh->quote($username);

   $sql = "select id from users where lower(name) = lower($lowerusername)";
   print "GetUser sql = $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   @row = $sth->fetchrow_array();

   $sth->finish();

   return $row[0];
}

sub ConvertNullToString($) {
   my $Value = shift;

   if (defined($Value)) {
      return $Value;
   } else {
      return "NULL";
   }
}

sub ConvertNullToBoolean($) {
   my $Value = shift;
   
   if (defined($Value) && $Value != '') {
      return $Value;
   } else {
      return "N";
   }
}   

sub GetNextValue($;$) {
   my $sequence = shift;
   my $dbh      = shift;
   my $sth;
   my $sql;
   my @row;
                            
   $sql = "select nextval('$sequence')";
                                    
   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
                                    
   @row = $sth->fetchrow_array();
                                    
   $sth->finish();
      
   return $row[0];
}

sub GetIDFromPath($;$) {
   my $pathname = shift;
   my $dbh      = shift;
   my $sth;
   my $sql;
   my @row;

   $sql = "select Pathname_ID('$pathname')";
      
   print "sql is $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
    
   @row = $sth->fetchrow_array();
   
   $sth->finish();
   
   return $row[0];
}
