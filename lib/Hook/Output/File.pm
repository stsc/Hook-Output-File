package Hook::Output::File;

use strict;
use warnings;
use base qw(Tie::Handle);
use boolean qw(true);

use Carp qw(croak);
use Cwd qw(abs_path);
use IO::Handle ();
use Params::Validate ':all';
use Scalar::Util qw(reftype);

our ($VERSION, @ISA);

$VERSION = '0.06_02';
@ISA = qw(Tie::StdHandle);

validation_options(
    on_fail => sub
{
    my ($error) = @_;
    chomp $error;
    croak $error;
},
    stack_skip => 2,
);

sub redirect
{
    my $class = shift;
    _validate(@_);
    my %opts = @_;

    my @keys   = keys   %opts;
    my @values = values %opts;
    delete @opts{@keys};
    @opts{map uc, @keys} = @values;

    my @streams = grep { exists $opts{$_} && defined $opts{$_} } map uc, qw(stdout stderr);

    my %paths;
    foreach my $stream (@streams) {
        $paths{$stream} = abs_path($opts{$stream});
    }

    no strict 'refs';
    my $caller = caller;

    foreach my $stream (@streams) {
        tie *{"${caller}::$stream"}, __PACKAGE__;
    }
    foreach my $stream (@streams) {
        open($stream, '>>', $paths{$stream}) or croak "Cannot redirect $stream: $!";
    }
    foreach my $fh (map \*$_, @streams) {
        $fh->autoflush(true);
    }

    return bless { streams => [ @streams ] }, ref($class) || $class;
}

sub _validate
{
    validate(@_, {
        stdout => {
            type => UNDEF | SCALAR,
            optional => true,
        },
        stderr => {
            type => UNDEF | SCALAR,
            optional => true,
        },
    });

    my %opts = @_;

    croak <<'EOT'
Hook::Output::File->redirect(stdout => 'file1',
                             stderr => 'file2');
EOT
      if not defined $opts{stdout}
          || defined $opts{stderr};
}

DESTROY
{
    my $self = shift;

    return if reftype $self eq 'GLOB' && *$self =~ /^\*Tie::StdHandle/;

    no strict 'refs';
    my $caller = caller;

    no warnings 'untie';
    foreach my $stream (@{$self->{streams}}) {
        untie *{"${caller}::$stream"};
    }
}

1;
__END__

=head1 NAME

Hook::Output::File - Redirect STDOUT/STDERR to a file

=head1 SYNOPSIS

 use Hook::Output::File;

 {
     my $hook = Hook::Output::File->redirect(
         stdout => '/tmp/1.out',
         stderr => '/tmp/2.out',
     );

     saved();

     undef $hook; # restore previous state of streams

     not_saved();
 }

 sub saved {
     print STDOUT "..."; # STDOUT output is appended to file
     print STDERR "..."; # STDERR output is appended to file
 }

 sub not_saved {
     print STDOUT "..."; # STDOUT output goes to STDOUT (not to file)
     print STDERR "..."; # STDERR output goes to STDERR (not to file)
 }

=head1 DESCRIPTION

C<Hook::Output::File> redirects C<STDOUT/STDERR> to a file.

=head1 METHODS

=head2 redirect

 my $hook = Hook::Output::File->redirect(
     stdout => $stdout_file,
     # and/or
     stderr => $stderr_file,
 );

Installs a file-redirection hook for regular output streams (i.e.,
C<STDOUT/STDERR>) with lexical scope.

A word of caution: do not intermix the file paths for C<STDOUT/STDERR>
output or you will eventually receive unexpected results. The paths
may be relative or absolute; if no valid path is provided, an usage
help will be printed (because otherwise, the C<open()> call might
silently fail to satisfy expectations).

The hook may be uninstalled either explicitly or implicitly; doing it
the explicit way requires to unset the hook variable (more concisely,
it is a blessed object), whereas the implicit end of the hook will
automatically be triggered when leaving the scope the hook was
defined in.

 {
     my $hook = Hook::Output::File->redirect(
         stdout => '/tmp/1.out',
         stderr => '/tmp/2.out',
     );

     some_sub();

     undef $hook; # explicitly remove hook

     another_sub();
 }
 ... # hook implicitly removed

=head1 BUGS & CAVEATS

Does not work in a forked environment, such as the case with daemons.

=head1 SEE ALSO

L<perltie>

=head1 AUTHOR

Steven Schubiger <schubiger@cpan.org>

=head1 LICENSE

This program is free software; you may redistribute it and/or
modify it under the same terms as Perl itself.

See L<http://dev.perl.org/licenses/>

=cut
