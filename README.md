## zstat

### License
Simplified BSD, see LICENSE.

### Disclaimers
- I probably don't like Perl much more than you do, but at least in 2013 it was by far the easiest way to extract these metrics. The three access methods for Illumos/Solaris `kstat()` being C, Perl, and the `kstat` shell executable.

- AFAIK the daemon version here hasn't been run or tested since converting to collectd in 2015. The collectd plugin is in service as of July 2018 using collectd 5.5.0.

### Description
`zstatd` is a Perl script for Illumos ZFS storage servers that collects storage-relevant system stats from `kstat()` for logging, monitoring and visualization.

The script is available as a standalone daemon or as a collectd plugin. The daemon version only feeds metrics to Graphite/Carbon. With the collectd version, metrics will go wherever you normally send them via collectd.

Stats are stored as total counters, but for rates it is trivial to take derivatives in Grafana or via the Graphite API.

`zstatd` has been valuable for tuning and debugging.  ARC metadata cache misses provide especially useful info as they are kryptonite for ZFS performance.

This code was written on OmniOS and it works on OpenIndiana.  It would probably work on Oracle Solaris and FreeBSD with little modification, but neither has been tested. The `Sun::Solaris::Kstat` Perl module *does* appear to work on FreeBSD.

It probably won't work on Linux. Fortunately, the ZFSonLinux SPL (Solaris Portability Layer) places the ZFS kstats in `/proc/spl/kstat/zfs`, where one can access them with normal modern Linux DevOps methods that don't involve esoteric Perl libraries.

### Collectd plugin

The `zstat` collectd plugin is at `collectd/collectd-zstat.pl`, and an example config file is in `collectd/plugins.d`. This is in service and working as of July 2018, using collectd version 5.5.0.

### Daemon

The SMF service name is `svc:/system/zstat:default` and the self-documenting config file is `zstat.conf`.

See `sbin/zstatd` for required Perl modules.

Files (with intended install prefixes):

```
[/usr/local/] sbin/zstatd                  -- Perl executable
[/usr/local/] etc/zstat.conf               -- config file
[/lib/]       svc/method/zstat             -- SMF start/stop script
[/var/]       svc/manifest/site/zstat.xml  -- SMF service manifest
```
