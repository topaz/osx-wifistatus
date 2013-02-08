#!/usr/bin/perl -w
use strict;

use Time::HiRes qw(time sleep);
use Net::Ping;

die "must be root!\n" if $>;

sub airport { map {/^\s*(\w+)\:\s*(.+?)\s*$/ ? ($1=>$2) : ()} `/System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I` }
sub routes { map {/^(\S+)\s+([\d\.]+) / ? ($1=>$2) : ()} `netstat -rn -finet` }

my $ping = Net::Ping->new("icmp");
$ping->hires();

my $cur_bssid = "";
my $cur_router = "";

my %stat;

$SIG{QUIT} = sub {
  foreach my $bssid (sort keys %stat) {
    print +($bssid eq $cur_bssid ? "\e[32m" : "")."\e[1G$bssid\e[0m  ".join("  ", map{stat_hr($bssid, $_)} sort keys %{$stat{$cur_bssid}{n}})."\n";
  }
};
sub stat_sample {
  my ($n, $v) = @_;
  $stat{$cur_bssid}{sum}{$n} += $v;
  $stat{$cur_bssid}{n}{$n}++;
  $stat{$cur_bssid}{max}{$n} = $v if !exists $stat{$cur_bssid}{max}{$n} || $v > $stat{$cur_bssid}{max}{$n};
  $stat{$cur_bssid}{min}{$n} = $v if !exists $stat{$cur_bssid}{min}{$n} || $v < $stat{$cur_bssid}{min}{$n};
}
sub stat_hr {
  my ($bssid, $n) = @_;
  sprintf "\e[1m$n\e[30m:\e[0m".sprintf("%d\e[30;1m/\e[0m%.02f\e[30;1m/\e[0m%d", $stat{$bssid}{min}{$n}, $stat{$bssid}{sum}{$n}/$stat{$bssid}{n}{$n}, $stat{$bssid}{max}{$n});
}

my $lastrun;
while (1) {
  $lastrun = time;
  my %airport = airport();
  if (!exists $airport{BSSID}) {
    print "wifi not associated\n";
    next;
  }
  if ($airport{BSSID} eq '0:0:0:0:0:0') {
    print "wifi connecting...\n";
    next;
  }
  if ($airport{BSSID} ne $cur_bssid) {
    $cur_bssid = join(":", map{sprintf("%02s",$_)} split(/\:/, $airport{BSSID}));
    my %routes = routes();
    if (!$routes{default}) {
      print "no route 'default'\n";
      next;
    }
    $cur_router = $routes{default};
  }
  my ($ping_status, $ping_dur) = $ping->ping($cur_router, 1);
  if (!$ping_status) {
    print "could not reach router $cur_router\n";
    stat_sample(reply => 0);
    next;
  }
  my $ping_ms = int($ping_dur*1000);  $ping_ms = 1000 if $ping_ms > 1000;
  printf "%-35s\e[32m%5s\e[33m%5s\e[36m%5s\e[0m\n", "$cur_bssid($cur_router)", $airport{agrCtlRSSI}, $airport{agrCtlNoise}, $ping_ms;

  stat_sample(signal => $airport{agrCtlRSSI});
  stat_sample(noise => $airport{agrCtlNoise});
  stat_sample(ping => $ping_ms);
  stat_sample(reply => 1);
} continue {
  my $now = time;
  my $nextrun = $lastrun + 1;
  sleep $nextrun - $now while time < $nextrun; #in case sleep() is interrupted by SIGQUIT
}
