package Fork::Queue;

require 5.005_62;
use strict;
use warnings;
use Carp;

our $VERSION = '0.01';

# parameters
my $queue_size=4;
my $debug=0;
my $trace=0;

# module status
my $queue_now=0;
my %process;
my @captured;

# set STDERR as unbuffered so all the carp calls work as expected
{ my $oldfh=select STDERR; $|=1; select $oldfh }

sub import {
  my ($pkg,%opts)=@_;
  foreach my $k (keys %opts) {
    if($k eq 'size') {
      size($opts{size});
    }
    elsif($k eq 'debug') {
      debug($opts{debug});
    }
    elsif($k eq 'trace') {
      trace($opts{trace});
    }
    else {
      carp "Unknow option '$k' for $pkg::import call";
    }
  }
}

sub size {
  my $size=shift;
  my $old_size=$queue_size;
  if(defined $size) {
    croak "invalid value for Fork::Queue size ($size), min value is 1"
      unless $size >= 1;
    $queue_size=$size;
    carp "Fork queue size set to $queue_size, it was $old_size" if $debug;
  }
  return $old_size;
}

sub debug {
  my $d=shift;
  my $old_debug=$debug;
  if(defined $d) {
    if ($d) {
      $debug=1;
      carp "Debug mode is now on for Fork::Queue module";
    }
    else {
      $debug=0;
      carp "Debug mode is now off for Fork::Queue module" if $old_debug;
    }
  }
  return $old_debug;
}

sub trace {
  my $t=shift;
  my $old_trace=$trace;
  if(defined $t) {
    if ($t) {
      $trace=1;
      carp "Trace mode is now on for Fork::Queue module" if $debug;
    }
    else {
      $trace=0;
      carp "Trace mode is now off for Fork::Queue module" if $debug;
    }
  }
  return $old_trace;
}

sub _wait () {
  carp "Fork::Queue::_wait private function called" if $debug && $trace;
  carp "Waiting for child processes to exit" if $debug;
  my $w=CORE::wait;
  if ($w != -1) {
    if(exists $process{$w}) {
      delete $process{$w};
      $queue_now--;
      carp "Process $w has exited, $queue_now processes running now" if $debug;
    }
    else {
      carp "Unknow process $w has exited, ignoring it" if $debug;
    }
  }
  else {
    carp "No child processes left, continuing" if $debug;
  }
  return $w;
}

sub new_wait () {
  carp "Fork::Queue::wait called" if $trace;
  if(@captured) {
    my $w=shift @captured;
    $?=shift @captured;
    carp "Wait returning old child $w captured in fork" if $debug;
    return $w;
  }
  return _wait;
}

sub new_waitpid ($$) {
  my ($pid,$flags)=@_;
  carp "Fork::Queue::waitpid called" if $trace;
  foreach my $i (0..$#captured) {
    next if $i&1;
    if ($captured[$i] == $pid) {
      $?=$captured[$pid+1];
      splice @captured,$i,2;
      return $pid;
    }
  }
  carp "Waiting for child process $pid to exit" if $debug;
  my $w=CORE::waitpid($pid,$flags);
  if ($w != -1) {
    if(exists $process{$w}) {
      delete $process{$w};
      $queue_now--;
      carp "Process $w has exited, $queue_now processes running now" if $debug;
    }
    else {
      carp "Unknow process $w has exited, ignoring it" if $debug;
    }
  }
  else {
    carp "No child processes left, continuing" if $debug;
  }
  return $w;
}

sub new_exit (;$) {
  my $e=shift;
  carp "Fork::Queue::exit($e) called" if $trace;
  carp "Process $$ exiting with value $e" if $debug;
  return CORE::exit($e);
}

sub new_fork () {
  carp "Fork::Queue::fork called" if $trace;
  while($queue_now>=$queue_size) {
    carp "Waiting that some process finishes before continuing" if $debug;
    my $nw;
    if (($nw=_wait) != -1) {
      push @captured,$nw,$?;
    }
    else {
      carp "Fork queue seems to be corrupted, $queue_now childs lost";
      last;
    }
  }
  my $f=CORE::fork;
  if (defined($f)) {
    if($f == 0) {
      carp "Process $$ now running" if $debug;
      # reset queue internal vars in child proccess;
      $queue_size=1;
      $queue_now=0;
      %process=();
      @captured=();
    }
    else {
      $process{$f}=1;
      $queue_now++;
      carp "Child forked (pid=$f), $queue_now processes running now" if $debug;
    }
  }
  else {
    carp "Fork failed: $!" if $debug;
  }
  return $f;
}

*CORE::GLOBAL::wait = \&new_wait;
*CORE::GLOBAL::waitpid = \&new_pidwait;
*CORE::GLOBAL::exit = \&new_exit;
*CORE::GLOBAL::fork = \&new_fork;

1;
__END__

# docs:

=head1 NAME

Fork::Queue - Perl extension to limit the number of concurrent child
process running

=head1 SYNOPSIS

  use Fork::Queue size => 4, debug => 1;

  package other;

  # this loop will create new childs, but Fork::Queue will make it
  # wait when the limit (4) is reached until some of the old childs
  # exit.
  foreach (1..10) {
    my $f=fork;
    if(defined ($f) and $f==0) {
      print "-- I'm a forked process $$\n";
      sleep rand 5;
      print "-- I'm tired, going away $$\n";
      exit(0)
    }
  }

  Fork::Queue::size(10); # changing limit to 10 concurrent processes
  Fork::Queue::trace(1); # trace mode on
  Fork::Queue::debug(0); # debug is off


  package other; # just to test it works in any package

  print "going again!\n";

  # another loop with different settings for Fork::Queue
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

=head1 DESCRIPTION

This module lets you parallelice one program using the fork, exit,
wait and waitpid calls as usual and without the need to take care of
creating too much processes and overloading the machine.

It works redefining fork, exit, wait and waitpid functions so old
programs do not have to be modified to use this module (only the 'use
Fork::Queue' sentence is needed).

Additionally, the module have two debugging modes (debug and trace)
that can be activated and that seem too be very useful when developing
parallel aplications.

Debug mode when activated dumps lots of information about processes
being created, exiting, being caught be parent, etc.

Trace mode just prints a line every time one of the fork, exit, wait
or waitpid functions is called.

Childs processes continue to use the modified functions, but its
queues are reset and the maximun process number for them is set to
1. Althought child can change it to any other value if needed.

=head2 EXPORT

This module redefines the fork, wait and exit calls

=head2 FUNCTIONS

There are several not exported functions that can be used to configure
the module:

=over 4

=item size(),  size(int)

If an argument is given the maximun number of concurrent processes is
set to it and the number of maximun processes that were allowed before
is returned.

If no argument is given, the number of processes allowed is returned.

=item debug(), debug(boolean), trace(), trace(boolean)

Change or return the status for the debug and trace modes.

=item import(name,%options)

The import functions is not usually explicitally called but by the
C<use Fork::Queue> statement. The options allowed are C<size>, C<debug>
and C<trace> and they let you configure the module instead of using
the C<size>, C<debug> or C<trace> module functions as in...

  use Fork::Queue size=>10, debug=>1;


=head2 BUGS

None that I know, but this is just version 0.01!

Child behaviuor althought deterministic could be changed to something
better. I would accept any suggestions on it.

=head1 AUTHOR

Salvador Fandino <sfandino@yahoo.com>

=head1 SEE ALSO

L<perlfunc(1)>, L<perlfork(1)>, L<Parallel::ForkManager>.

=cut
