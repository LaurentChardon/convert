#!/usr/bin/perl

#
# connect to FreshPorts 2 and give me a list of stuff
#

use DBI;
use strict;

my $user_id_seq = "users_id_seq";

&main();

sub main {

   my $dbh_mysql;
   my $dbh_pg;

   my $sql;
   my $sth_mysql;
   my $sth_pg;

   my $num_users;
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

   $sql = "select id, username, password, cookie, firstlogin, lastlogin, email, watchnotifyfrequency, \
                  emailsitenotices_yn, emailbouncecount, type
             from users
            order by id";

   print "sql is $sql\n";

   $sth_mysql = $dbh_mysql->prepare($sql);
   $sth_mysql->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $num_users = 0;
   while ($row=$sth_mysql->fetchrow_hashref()) {
      my $id   = $row->{"id"};
      my $name = $row->{"username"};


      print $row->{"id"} . " " . $row->{"username"} . "\n";
      UpdateUser($row, $dbh_pg);
      $num_users++;
   }

#   $sth_pg->finish();
   $dbh_pg->disconnect();

   $sth_mysql->finish();
   $dbh_mysql->disconnect();
}

sub UpdateUser($;$) {
#
# Insert something into the ports table.
# the corresponding entry in the Element table
# is assumed to already exist.
#
   my $row          = shift;   # row containing data from freshports1
   my $dbh          = shift;   # database handle

   my $sth;      
   my $sql;
   my @row;

   my $name                 = $dbh->quote($row->{username});
   my $password             = $dbh->quote($row->{password});
   my $cookie               = $dbh->quote($row->{cookie});
   my $firstlogin           = $dbh->quote(ConvertNullToString($row->{firstlogin}));
   my $lastlogin            = $dbh->quote(ConvertNullToString($row->{lastlogin}));
   my $email                = $dbh->quote(ConvertNullToString($row->{email}));
   my $watchnotifyfrequency = $dbh->quote($row->{watchnotifyfrequency});
   my $emailsitenotices_yn  = $dbh->quote($row->{emailsitenotices_yn});
   my $emailbouncecount     = $dbh->quote(ConvertNullToString($row->{emailbouncecount}));
   my $type                 = $dbh->quote($row->{type});


   my $user_id = GetUser($row->{username}, $dbh);

   if (!defined($user_id)) {
      my $user_id = GetNextValue($user_id_seq, $dbh);
   
      $sql = "   INSERT INTO users (id, name, password, cookie, firstlogin, lastlogin, email, watchnotifyfrequency, \
                                    emailsitenotices_yn, emailbouncecount, type)
                            values ($user_id, $name, $password, $cookie, $firstlogin, $lastlogin, $email, \
                                    $watchnotifyfrequency, $emailsitenotices_yn, $emailbouncecount, $type)";
   } else {
      $sql = " UPDATE users set \
                      name                 = $name,                 password                = $password,  \
                      cookie               = $cookie,               firstlogin              = $firstlogin,   \
                      lastlogin            = $lastlogin,            email                   = $email,  \
                      watchnotifyfrequency = $watchnotifyfrequency, emailsitenotices_yn     = $emailsitenotices_yn, \
                      emailbouncecount     = $emailbouncecount,     type                    = $type
                WHERE ID = $user_id";
   }
   
   print "sql is $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $sth->finish();

   return $user_id;
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
