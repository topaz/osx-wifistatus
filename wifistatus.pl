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

=ignore
$ /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I
     agrCtlRSSI: -53
     agrExtRSSI: 0
    agrCtlNoise: -85
    agrExtNoise: 0
          state: running
        op mode: station 
     lastTxRate: 54
        maxRate: 54
lastAssocStatus: 0
    802.11 auth: open
      link auth: wpa2-psk
          BSSID: 0:1c:57:e3:b:73
           SSID: Syn2Data
            MCS: -1
        channel: 11

[12:00:27][Polaris][~/perl]ewastl$ /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I
AirPort: Off
[12:00:34][Polaris][~/perl]ewastl$ /System/Library/PrivateFrameworks/Apple80211.framework/Versions/Current/Resources/airport -I
     agrCtlRSSI: 0
     agrExtRSSI: 0
    agrCtlNoise: 0
    agrExtNoise: 0
          state: init
        op mode: 
     lastTxRate: 0
        maxRate: 0
lastAssocStatus: 65535
    802.11 auth: open
      link auth: wpa2-psk
          BSSID: 0:0:0:0:0:0
           SSID: 
            MCS: -1
        channel: 1

bad..good
agrCtlRSSI: -80..-30
agrCtlNoise: -100..-50

noise:-91/-87.30/-57  ping:1/8.68/558  signal:-79/-57.22/-25

00:15:c7:fe:70:73  noise:-88/-83.43/-60  ping:1/12.13/124  reply:1/1.00/1  signal:-70/-58.23/-54
00:1a:e3:d0:41:03  noise:-88/-82.41/-57  ping:1/28.73/301  reply:1/1.00/1  signal:-80/-60.86/-50
00:1a:e3:d0:50:bc  noise:-91/-87.64/-57  ping:1/8.48/513  reply:0/0.99/1  signal:-81/-62.42/-53
00:1c:57:e3:2d:c3  noise:-60/-60.00/-60  ping:5/67.67/174  reply:0/0.75/1  signal:-73/-69.67/-68
00:1c:57:e3:2d:cc  noise:-88/-85.75/-60  ping:1/16.28/222  reply:1/1.00/1  signal:-78/-57.67/-39
00:1c:57:e3:2e:73  noise:-84/-73.74/-57  ping:2/297.93/980  reply:0/0.57/1  signal:-83/-72.70/-48
00:1c:57:e3:30:43  noise:-60/-60.00/-60  ping:12/123.25/241  reply:1/1.00/1  signal:-70/-64.25/-58
58:35:d9:d4:ce:14  noise:-79/-71.89/-60  ping:2/78.11/387  reply:1/1.00/1  signal:-80/-76.56/-65
58:35:d9:d4:ce:1b  noise:-89/-85.48/-69  ping:1/16.06/79  reply:0/0.89/1  signal:-81/-65.64/-54

noise:  -91..-57
signal: -83..-25



use Net::Ping; $p=Net::Ping->new("icmp"); $p->hires(); ($ret,$duration,$ip) = $p->ping("lt3.us", 1); print "$ret\n$duration\n$ip\n"

$ netstat -rn -finet
Routing tables

Internet:
Destination        Gateway            Flags        Refs      Use   Netif Expire
default            172.17.43.253      UGSc           76        0     en1
127                127.0.0.1          UCS             0        0     lo0
127.0.0.1          127.0.0.1          UH              1      347     lo0
169.254            link#5             UCS             0        0     en1
172.17.40/22       link#5             UC              1        0     en1
172.17.40.154      127.0.0.1          UHS             0        0     lo0
172.17.43.253      0:16:c7:83:9e:7f   UHLWIi         76     1510     en1   1032
=cut
