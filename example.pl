#!/apps/perl/std/bin/perl -w

use Fork::Queue size => 4, debug => 1;

foreach (1..10) {
  my $f=fork;
  if(defined ($f) and $f==0) {
    print "-- I'm a forked process $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n";
    exit(0)
  }
}

1 while wait != -1;

Fork::Queue::size(10); # changing limit to 10 concurrent processes
Fork::Queue::trace(1); # trace mode on
Fork::Queue::debug(0); # debug is off


package other; # just to test it works in any package

print "-- Going again!\n";

foreach (1..20) {
  my $f=fork;
  if(defined ($f) and $f==0) {
    print "-- I'm a forked process $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n";
    exit(0)
  }
}



1 while wait != -1;

