#
# Small module to send syslog messages (based on Net::Syslog)
#
package Syslog;

#use strict;
use warnings;

use Date::Format qw(time2str);
use IO::Socket;

my %syslog_priorities=(
        emerg   => 0,
        alert   => 1,
        crit    => 2,
        err     => 3,
        warning => 4,
        notice  => 5,
        info    => 6,
        debug   => 7
);

my %syslog_facilities=(
        kern    => 0,
        user    => 1,
        mail    => 2,
        daemon  => 3,
        auth    => 4,
        syslog  => 5,
        lpr     => 6,
        news    => 7,
        uucp    => 8,
        cron    => 9,
        authpriv=> 10,
        ftp     => 11,
        local0  => 16,
        local1  => 17,
        local2  => 18,
        local3  => 19,
        local4  => 20,
        local5  => 21,
        local6  => 22,
);


sub new {
	my $class = shift;
	my $this = {
		name     => undef,
		facility => 'local5',
		priority => 'info',
		host	 => undef,
		loghost	 => '127.0.0.1',
		port	 => 514,
#newline added below this
		proto	 => 'udp',
		pid	 => $$,
		@_,
	};
	$this->{sock} = new IO::Socket::INET(
				PeerAddr => $this->{loghost},
				PeerPort => $this->{port},
#				Proto    => 'udp');
				Proto    => $this->{proto});
	bless $this, $class;
}

sub send {
	my ($this, $msg) = (shift, shift);
	my %param = (%{$this}, @_);
	my $stamp    = defined $param{stamp} ? 
		       $param{stamp} :
                       time2str("%b %d %H:%M:%S", time);
	my $pri = ($syslog_facilities{$param{facility}} << 3) |
                   $syslog_priorities{$param{priority}};
#	my $send = "<$pri>" . $stamp . " " . (defined $param{host} ? $param{host} : '') .
	my $send = (defined $param{host} ? "<$pri>$stamp $param{host} " : '') .
                   (defined $param{name} ? 
                    "$param{name}" . (defined $param{pid} ? "\[$param{pid}\]: " : ': ') :
		    '' ).
		   "$msg";
        print $send;
	$this->{sock}->send($send);
}

sub close { shift->{sock}->close };

1;
