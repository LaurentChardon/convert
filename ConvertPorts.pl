#!/usr/bin/perl

#
# connect to FreshPorts 2 and give me a list of stuff
#

use DBI;
use strict;

my $ports_id_seq = "ports_id_seq";

&main();

sub main {

   my $dbh_mysql;
   my $dbh_pg;

   my $sql;
   my $sth_mysql;
   my $sth_pg;

   my $num_ports;
   my $row;

   my $category;
   my $portname;
   my $Element_ID;
   my $Element_Name;


   $dbh_mysql = DBI->connect('dbi:mysql:freshports','root','xyzzy');

   if (!$dbh_mysql) {
      die "could not connect to FreshPorts1\n";
   }

   $dbh_pg = DBI->connect('DBI:Pg:dbname=FreshPorts2', 'dan', "");
   if (!$dbh_pg) {
      die "could not connect to FreshPorts2\n";
   }

   print "connected\n";

   $sql = "select ports.id, ports.name, categories.name as category, short_description \
                  long_description, version, maintainer, homepage, master_sites, \
                  extract_suffix, package_exists, depends_build, depends_run, last_change_log_id, \
                  needs_refresh , found_in_index, forbidden, broken
             from ports, categories
            where ports.primary_category_id = categories.id ";

   print "sql is $sql\n";

   $sth_mysql = $dbh_mysql->prepare($sql);
   $sth_mysql->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $num_ports = 0;
   while ($row=$sth_mysql->fetchrow_hashref()) {
      $category = $row->{"category"};
      $portname = $row->{"name"};

      print $row->{"id"} . " " . $row->{"name"} . " " .  $category . $row->{"category"} . "\n";

      $Element_Name = "ports/$category/$portname";
      $Element_ID = GetIDFromPath($Element_Name, $dbh_pg);

      if ($Element_ID) {
         print $Element_ID . "\n";
      } else {
         $Element_ID = AddNewElement($Element_Name, 'D', $dbh_pg);
         SetElementStatus($Element_ID, 'D', $dbh_pg);
#         die "no rows\n";
      }

      #
      # now insert into the ports table
      #

      UpdatePort($Element_ID, $row, $dbh_pg);

      $num_ports++;
   }

#   $sth_pg->finish();
   $dbh_pg->disconnect();

   $sth_mysql->finish();
   $dbh_mysql->disconnect();
}

sub GetCategoryFromElementID($;$;$) {
   my $category_name = shift;
   my $element_id    = shift;
   my $dbh           = shift;

   my $category_id;

   my $sth;
   my $sql;
   my @row;
   
   $sql = "select id from categories where element_id = $element_id";
           
   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
   
   @row = $sth->fetchrow_array();
   
   $sth->finish();
   
   $category_id = $row[0];

   if (!$category_id) {
      
   }
 
   return $category_id;
}

sub UpdatePort($;$;$) {
#
# Insert something into the ports table.
# the corresponding entry in the Element table
# is assumed to already exist.
#
   my $element_id   = shift;   # element which this port represents
   my $row          = shift;   # row containing data from freshports1
   my $dbh          = shift;   # database handle

   my $sth;      
   my $sql;
   my @row;

   my $short_description = $dbh->quote($row->{short_description});
   my $long_description  = $dbh->quote($row->{long_description});
   my $version           = $dbh->quote($row->{version});
   my $maintainer        = $dbh->quote($row->{maintainer});
   my $homepage          = $dbh->quote($row->{homepage});
   my $master_sites      = $dbh->quote($row->{master_sites});
   my $extract_suffix    = $dbh->quote($row->{extract_suffix});
   my $package_exists    = $dbh->quote($row->{package_exists});
   my $depends_build     = $dbh->quote($row->{depends_build});
   my $depends_run       = $dbh->quote($row->{depends_run});
   my $last_commit_id    = ConvertNullToString($row->{last_commit_id});
   my $needs_refresh     = ConvertNullToString($row->{needs_refresh});
   my $found_in_index    = $dbh->quote(ConvertNullToBoolean($row->{found_in_index}));
   my $forbidden         = $dbh->quote(ConvertNullToBoolean($row->{forbidden}));
   my $broken            = $dbh->quote(ConvertNullToBoolean($row->{broken}));


   my $category_id;
   my $port_id;

   print "getting category $row->{category}\n";
   $category_id = GetCategory($row->{category}, $dbh);
   if (!defined($category_id)) {
      $category_id = CreateCategory($row->{"category"}, "***", "Y", $dbh);
   }

   my $port_id = GetPort("$row->{category}/$row->{name}", $dbh);

   if (!defined($port_id)) {
      my $port_id = GetNextValue($ports_id_seq, $dbh);
   
      $sql = "   INSERT INTO ports (id, element_id, category_id, short_description, long_description, \
                                    version, maintainer, homepage, master_sites, extract_suffix, \
                                    package_exists, depends_build, depends_run, last_commit_id, needs_refresh, \
                                    found_in_index, forbidden, broken) \
                            values ($port_id, $element_id, $category_id,   $short_description, \
                                    $long_description, $version, \
                                    $maintainer,       $homepage, \
                                    $master_sites,     $extract_suffix, \
                                    $package_exists,   $depends_build, \
                                    $depends_run,      $last_commit_id,\
                                    $needs_refresh, \
                                    $found_in_index,   $forbidden, \
                                    $broken)";
   } else {
      $sql = " UPDATE ports set \
               element_id        = $element_id,        category_id      = $category_id, \
               short_description = $short_description, long_description = $long_description, version       = $version, \
               maintainer        = $maintainer,        homepage         = $homepage,         master_sites  = $master_sites, \
               extract_suffix    = $extract_suffix,    package_exists   = $package_exists,   depends_build = $depends_build, \
               depends_run       = $depends_run,       last_commit_id   = $last_commit_id,   needs_refresh = $needs_refresh, \
               found_in_index    = $found_in_index,    forbidden        = $forbidden,        broken        = $broken \
               WHERE ID = $port_id";
   }
   
   print "sql is $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   $sth->finish();

   return $port_id;
}

sub GetPort($;$) {
   my $port = shift;
   my $dbh  = shift;
   my $sth;
   my $sql;
   my @row;
   
   $sql = "select GetPort('$port')";
   print "GetPort sql = $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   @row = $sth->fetchrow_array();

   $sth->finish();

   print "Port_ID = $row[0]\n";

   return $row[0];
}

sub GetCategory($;$) {
   my $category = shift;
   my $dbh      = shift;
   my $sth;
   my $sql;
   my @row;

   $sql = "select GetCategory('$category')";
   print "GetCategory sql = $sql\n";

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

sub CreateCategory($;$;$;$) {
   my $category    = shift;
   my $description = shift;       
   my $primary     = shift;
   my $dbh         = shift;
   my $sth;
   my $sql;
   my @row;
   
   $sql = "select CreateCategory('$category'::text, '$description'::text, '$primary')";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";

   @row = $sth->fetchrow_array();
           
   $sth->finish();
   
   return $row[0];
}

sub AddNewElement($;$;$) {
   my $element_name = shift;
   my $FileDirFlag  = shift;
   my $dbh          = shift;

   my $element_id;
   my $sth;      
   my $sql;
   my @row;
   
   $sql = "select Element_Add('$element_name', '$FileDirFlag')";
   
   print "sql is $sql\n";

   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
      
   @row = $sth->fetchrow_array();

   $sth->finish();

   $element_id = $row[0];

   return $element_id;
}

sub SetElementStatus($;$;$) {
   my $element_id = shift;
   my $new_status = shift;
   my $dbh        = shift;
   my $sth;
   my $sql;
   my @row;
            
   $sql = "select Element_SetStatus($element_id, '$new_status')";
   
   print "sql is $sql\n";
   
   $sth = $dbh->prepare($sql);
   $sth->execute ||
           die "Could not execute SQL $sql ... maybe invalid?";
   
   $sth->finish();
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
