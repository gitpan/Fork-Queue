#!/apps/perl/std/bin/perl -w

use Fork::Queue size => 4, debug => 1, trace => 1, ':all';

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

print "\n-- Going again!\n";

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


package another;

print "\n-- Another try!\n";

Fork::Queue::size(2);
Fork::Queue::debug(1);

use Fork::Queue ':all';

my $all_ok=all_exit_ok
  Fork::Queue::run_back {
    print "Hello, I'm running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n";
  },
  run_back {
    print "Hello, I'm also running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n"
  },
  run_back {
    print "Hello, I'm running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n";
  },
  run_back {
    print "Hello, I'm also running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n"
  };



print "-- all_exit_ok return $all_ok\n";


print "\n-- And the last one!\n";

my $all_ok2=all_exit_ok
  run_back {
    print "Hello, I'm running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n";
  },
  run_back {
    print "Hello, I'm also running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n";
    $?=1; # I'm going to fail
  },
  run_back {
    print "Hello, I'm running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n";
    exit(1); # I'm going to fail too
  },
  run_back {
    print "Hello, I'm also running back $$\n";
    sleep rand 5;
    print "-- I'm tired, going away $$\n"
  };

print "-- all_exit_ok return $all_ok2\n";
