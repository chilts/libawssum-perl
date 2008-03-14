## ----------------------------------------------------------------------------
package Amazon::AwsSum::Util;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(get_options vbs hdr dbg line cols errs force_array);

use Getopt::Mixed "nextOption";

# for logging stuff
my ($vbs, $dbg, $hdr);

## ----------------------------------------------------------------------------
# option processing

sub get_options {
    my ($in_opts, $booleans) = @_;

    my $args = {};
    Getopt::Mixed::init( @$in_opts );
    while( my($opt, $val) = nextOption() ) {
        # if boolean, keep a count of how many there is only
        if ( exists $booleans->{$opt} ) {
            $args->{$opt}++;
            next;
        }
        # normal 'string' value
        if ( defined $args->{$opt} ) {
            unless ( ref $args->{$opt} eq 'ARRAY' ) {
                $args->{$opt} = [ $args->{$opt} ];
            }
            push @{$args->{$opt}}, $val;
        }
        else {
            $args->{$opt} = $val;
        }
    }
    Getopt::Mixed::cleanup();
    return $args;
}

## ----------------------------------------------------------------------------
# xml helpers

sub force_array {
    return unless defined $_[0];
    return if ref $_[0] eq 'ARRAY';
    $_[0] = [ $_[0] ];
}

## ----------------------------------------------------------------------------
# output stuff - verbose, debug and hdr - all if 'switched on'

sub set_vbs { $vbs = $_[0] }
sub set_hdr { $hdr = $_[0] }
sub vbs { print $_[0], "\n" if $vbs }
sub hdr { print $_[0], "\n" if $hdr }

sub line {
    my ($hdr) = @_;
    return unless $vbs;
    print '=' x 79, "\n";
    print "--- $hdr ", '-' x ( 74 - length $hdr ), "\n" if defined $hdr;
}

sub cols {
    my ($hash, @cols) = @_;
    foreach my $col ( @cols ) {
        print "\t$hash->{$col}";
    }
}

sub errs {
    my ($errs) = @_;
    foreach ( @$errs ) {
        print "$_->{Code}: $_->{Message}\n";
    }
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
