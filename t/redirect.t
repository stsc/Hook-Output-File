#!/usr/bin/perl

use strict;
use warnings;
use constant stdout => 0;
use constant stderr => 1;

use File::Temp ':POSIX';
use Hook::Output::File;
use IO::Capture::Stderr;
use IO::Capture::Stdout;
use Test::More tests => 8;

sub test_redirect
{
    my ($code, $output_messages, $test_messages) = @_;

    my $stdout_tmpfile = tmpnam();
    my $stderr_tmpfile = tmpnam();

    my $hook = Hook::Output::File->redirect(
        stdout => $stdout_tmpfile,
        stderr => $stderr_tmpfile,
    );

    $code->[stdout]->($output_messages->[stdout]);
    $code->[stderr]->($output_messages->[stderr]);

    undef $hook;

    my $get_file_content = sub
    {
        open(my $fh, '<', $_[0]) or die "Cannot open $_[0]: $!\n";
        return do { local $/; local $_ = <$fh>; s/\n+$//; $_ };
    };

    is($get_file_content->($stdout_tmpfile), $output_messages->[stdout], $test_messages->[stdout]);
    is($get_file_content->($stderr_tmpfile), $output_messages->[stderr], $test_messages->[stderr]);

    unlink $stdout_tmpfile;
    unlink $stderr_tmpfile;
}

test_redirect(
    [ sub { print STDOUT $_[0] },      sub { print STDERR $_[0] }    ],
    [ 'explicit stdout (redirected)', 'explicit stderr (redirected)' ],
    [ 'explicit stdout redirected',   'explicit stderr redirected'   ],
);
test_redirect(
    [ sub { print $_[0] },             sub { warn $_[0], "\n" }      ],
    [ 'implicit stdout (redirected)', 'implicit stderr (redirected)' ],
    [ 'implicit stdout redirected',   'implicit stderr redirected'   ],
);

sub test_capture
{
    my ($code, $output_messages, $test_messages) = @_;

    my $capture = IO::Capture::Stdout->new;
    $capture->start;
    $code->[stdout]->($output_messages->[stdout]);
    $capture->stop;
    my @stdout_lines = $capture->read;

    $capture = IO::Capture::Stderr->new;
    $capture->start;
    $code->[stderr]->($output_messages->[stderr]);
    $capture->stop;
    my @stderr_lines = $capture->read;

    chomp @stderr_lines;

    is_deeply(\@stdout_lines, [ $output_messages->[stdout] ], $test_messages->[stdout]);
    is_deeply(\@stderr_lines, [ $output_messages->[stderr] ], $test_messages->[stderr]);
}

test_capture(
    [  sub { print STDOUT $_[0] },   sub { print STDERR $_[0] }  ],
    [ 'explicit stdout (captured)', 'explicit stderr (captured)' ],
    [ 'explicit stdout captured',   'explicit stderr captured'   ],
);
test_capture(
    [  sub { print $_[0] },          sub { warn $_[0], "\n" }    ],
    [ 'implicit stdout (captured)', 'implicit stderr (captured)' ],
    [ 'implicit stdout captured',   'implicit stderr captured'   ],
);
