#!/usr/bin/perl
######################################################################################
## collectd-zstat.pl
##
## Perl script to feed ZFS-relevant kstat statistics to collectd exec plugin
##
## Modified from zstatd, https://github.com/nerdmagic/zstat
##
## Version 0.1       2015/11/05      Trey Palmer 
##    -- Disk times don't work, commented out.
##
## Released under Simplified BSD License.
##
## Copyright (c) 2013 Georgia Institute of Technology
## Copyright (c) 2015 Trey Palmer
##
## All rights reserved.
##
######################################################################################

#my $debug = 1;

use warnings;

use Sun::Solaris::Kstat;
use Sys::Hostname;

$|++;

my $logfile = '/var/log/zstat_collectd.log';

if (defined $ENV{'COLLECTD_HOSTNAME'}) {
  $hostname = $ENV{'COLLECTD_HOSTNAME'};
} else {
  $hostname = hostname ;
}

if (defined $ENV{'COLLECTD_INTERVAL'}) {
  $interval = $ENV{'COLLECTD_INTERVAL'};
} else {
  $interval = 10 ;
}


#### the big kahuna -- the main stat hash!  
my %stats;

##################################################################################################
##
## metadata hash -- this maps the structure of the data we are retrieving from kstat
## 
## Three data types corresponding to three different kstat modules:
##      arc -- adaptive replacement cache
##      zpool -- overall zpool throughput
##      disk  -- physical disk throughput
##
## Each type section has these metadata types:
##    sum => 1 if we are summing multiple instances, zero if there can only be one instance
##        instances => 0, then reset when instances are discovered by Init()
##        disabled  => 1 if the service can be disabled, then reset to 0 if discovered by Init()
##    @kref =>  path within kstat as array:  class, instance [, module]
##    @metrics => array of individual kstat names to retrieve
##
#################################################################################################

my %meta = (
    'arc'   => {  'sum' => 0,
                  'kref' => [ 'zfs', 0, 'arcstats' ],
                  'metrics' =>  [ "size",
                                  "arc_meta_used",
                                  "hits",
                                  "misses",
                                  "demand_data_hits",
                                  "demand_data_misses",
                                  "demand_metadata_hits",
                                  "demand_metadata_misses",
                                  "prefetch_data_hits",
                                  "prefetch_data_misses",
                                  "prefetch_metadata_hits",
                                  "prefetch_metadata_misses"
## We have no l2arc devices, commenting for now
#                                  "l2_hits",
#                                  "l2_misses",
#                                  "l2_read_bytes",
#                                  "l2_write_bytes"
                                 ]
                },
    'zpool' => {  'sum' => 0,
                  'kref' => [ 'zone_zfs', 0, 'global' ],
                  'metrics' => [ 'reads', 'writes', 'nread', 'nwritten']
                },
    'disk'  => {  'sum' => 1,
                  'instances' => [ 0 ],
                  'kref' => [ 'sd', 'NUM' ],
                  'metrics' => [ 'reads',
                                 'writes',
                                 'nread',
                                 'nwritten',
#                                 'rtime',
#                                 'wtime',
                               ]

               }
           );


## Set up the kstat hash
my $kstat = Sun::Solaris::Kstat->new();

#####################################
## Functions start
#####################################

### Standard housekeeping functions
sub Log {
    $string = $_[0];
    my $timestamp = localtime();
    $log = open (LOG, ">>$logfile") || die "ERROR opening $logfile\n$!";
    if ($log) {
        print LOG "$timestamp - $$:  $string\n";
        return 1;
    }
    close (LOG);
    return 0;
}

### SnapStats() -- called by main loop at standard time interval to refresh $stats hash from kstat
sub SnapStats {
   ## First refresh kstat values
   if ($kstat->update()) {
      Log "<State changed!>";
   }
   ## now parse through the metadata keys and fill the $stats hash
   my $ktemp = $kstat;
   foreach my $type (keys %meta) {
      print "$type\n" if $debug;
      ## skip if the service is disabled
      next if ($meta{$type}{"disabled"});
      ## sum=0 means only one instance, very simple
      unless ($meta{$type}{"sum"}) {
          my @kref = @{$meta{$type}{"kref"}};
          print join (',', @kref) . "\n" if $debug;
          next unless (exists $ktemp->{$kref[0]});
          next unless (exists $ktemp->{$kref[0]}{$kref[1]});
          next unless (exists $ktemp->{$kref[0]}{$kref[1]}{$kref[2]});
          $stats{$type} = $ktemp->{$kref[0]}{$kref[1]}{$kref[2]};
      }
      else {
         ## sum=1 means multiple possible instances so we have to sum their values
         ## zero metric values in $stats
         foreach my $metric (@{$meta{$type}{"metrics"}}) {
            if (defined $stats{$type}{$metric}) {
                $stats{$type}{$metric} = 0;
                print "zeroing $type $metric\n" if $debug;
            }
         }
         foreach my $inst (@{$meta{$type}{"instances"}}) {
            my @kref;
            if ( $type =~ /disk/ ) {
               @kref = ( "sd", $inst, "sd" . $inst );
            } else {
               @kref = @{$meta{$type}{"kref"}};
               push (@kref, $inst);
            }
            next unless (exists $ktemp->{$kref[0]});
            next unless (exists $ktemp->{$kref[0]}{$kref[1]});
            next unless (exists $ktemp->{$kref[0]}{$kref[1]}{$kref[2]});
            my $hashref = $ktemp->{$kref[0]}{$kref[1]}{$kref[2]};
            if ($hashref) {
               foreach my $metric (@{$meta{$type}{"metrics"}}) {
                  if (defined $hashref->{$metric}) {
                     $stats{$type}{$metric} += $hashref->{$metric};
                  }
               }
            } else {
               print "$type " . join(':', @kref) . " undefined\n" if $debug;
            }
         }
      } #else
   } #foreach
}  ## end SnapStats()

### Init()
### Initialize individual kstats -- discover number of instances and whether services are running
### Not needed for arc or zpool -- always on, always only one instance
sub Init {
## Initialize sd kstat (physical disk)
  my $sderr_hash = $kstat->{"sderr"};
  my @sd_disks;
  ## check each disk against the list of invalid disk types
  foreach my $key (keys %$sderr_hash) {
     push (@sd_disks, $key );
  }
  @{$meta{"disk"}{"instances"}} = @sd_disks;

  if ($debug) {
     my $disklist = join (", ", @sd_disks);
     print "\n\ndisks $disklist\n";
  }

}

#####################
### Functions End
#####################

Init();

#####################
### Main loop
#####################
while (1)
{
   $epoch = time();

   SnapStats();

   foreach my $type (keys %meta) {
      next if ($meta{$type}{"disabled"});
      foreach my $metric(@{$meta{$type}{"metrics"}}) {
         if (defined $stats{$type}{$metric}) {

            ## ctype is collectd metric type
            ## set default to counter, should not actually be used
            $ctype = 'counter';

            if ($metric =~ /hits$/ )        { $ctype = 'cache_operation'; }
            if ($metric =~ /misses$/ )      { $ctype = 'cache_operation'; }
            if ($metric =~ /size$/ )        { $ctype = 'cache_size'; }
            if ($metric =~ /arc_meta_used/) { $ctype = 'cache_size'; }
            if ($metric =~ /nread/ )        { $ctype = 'total_bytes'; }
            if ($metric =~ /nwritten/)      { $ctype = 'total_bytes'; }
            if ($metric =~ /reads/)         { $ctype = 'total_operations';}
            if ($metric =~ /writes/)        { $ctype = 'total_operations'; }
            if ($metric =~ /read_bytes/)    { $ctype = 'total_bytes'; }
            if ($metric =~ /write_bytes/)   { $ctype = 'total_bytes'; }
#            if ($metric =~ /time/)          { $ctype = 'disk_time'; }

            my $value = $stats{$type}{$metric};
            my $message = "PUTVAL \"${hostname}/zfs/${ctype}-${type}_${metric}\" interval=${interval} ${epoch}:${value}\n";
            print $message;
         }
      }
   }
   sleep $interval ;
}
