
## zstat

### License
Simplified BSD, see LICENSE.

### Disclaimer
I probably don't like Perl much more than you do, but at least in 2013 it was by far the easiest way to extract these metrics. The three access methods for Illumos/Solaris kstat() being C, Perl, and the 'kstat' shell executable.

### Description
zstatd is a Perl daemon for Illumos ZFS storage servers that collects storage-relevant system stats from kstat() and feeds them to graphite/carbon for logging, monitoring and visualization.

Stats are stored at 10 second intervals as total counters, but it is trivial to take derivatives from graphite for rates.

zstatd has been valuable for tuning and debugging.  ARC metadata cache misses provide especially useful info as they are kryptonite for ZFS performance.

This code was written on OmniOS and it works on OpenIndiana.  It would probably work on Oracle Solaris and FreeBSD with little modification, but neither has been tested. The Sun::Solaris::Kstat module *does* appear to work on FreeBSD.

The SMF service name is svc:/system/zstat:default and the self-documenting config file is zstat.conf, per the Illumos/Solaris standard.

See sbin/zstatd for required Perl modules.

Files (with intended install prefixes):

```
[/usr/local/] sbin/zstatd                  -- Perl executable
[/usr/local/] etc/zstat.conf               -- config file
[/lib/]       svc/method/zstat             -- SMF start/stop script
[/var/]       svc/manifest/site/zstat.xml  -- SMF service manifest
samples/      -- sample graphite images using zstatd metrics
```
