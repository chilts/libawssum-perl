## ----------------------------------------------------------------------------
package Amazon::AwsSum::Util;

use strict;
use warnings;
use Data::Dumper;

use Exporter 'import';
our @EXPORT_OK = qw(get_options vbs hdr dbg sep line cols errs force_array table);

use Getopt::Mixed "nextOption";
use List::Util qw(max sum);

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

sub sep {
    my ($hdr) = @_;
    print "=== $hdr ===\n";
}

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
        print STDERR "$_->{Code}: $_->{Message}\n";
    }
}

sub table {
    my ($headers, @rows) = @_;
    # $headers is an arrayref of strings
    # @rows is an array of arrayrefs of straings

    # get the number of columns to be printed out
    my $cols = scalar @$headers;
    my @column_lengths = map { length } @$headers;

    # check all the data
    foreach my $row ( @rows ) {
        my $i = 0;
        foreach my $data ( @$row ) {
            $column_lengths[$i] = max($column_lengths[$i], length($data))
                if defined $data;
            $i++;
        }
    }

    # get the total length of the table
    my $total = sum(@column_lengths) + (@column_lengths * 3) + 1;

    # now print it out
    table_line(\@column_lengths);
    table_row( $cols, \@column_lengths, $headers );
    table_line(\@column_lengths);

    # don't do the rest of the table if nothing there
    return unless @rows;

    # do the table contents
    foreach my $row ( @rows ) {
        table_row( $cols, \@column_lengths, $row );
    }
    table_line(\@column_lengths);
}

sub table_line {
    my ($column_lengths) = @_;

    # print out the headers
    print '+-';
    print join('-+-', map { '-' x $_ } @$column_lengths);
    print '-+';
    print "\n";
}

sub table_row {
    my ($cols, $column_lengths, $data) = @_;

    print '|';
    # print join(' | ', map { $_ . (' ' x ($column_lengths->[$i] - length($_))) } @$data);
    for my $i ( 0..$cols-1 ) {
    # foreach my $str ( @$data ) {
        my $str = defined $data->[$i] ? $data->[$i] : '';
        print " $str";
        print ' ' x ($column_lengths->[$i] - length($str));
        print " |";


        # print "| $str" . (' ' x ($column_lengths->[$i] - length($str)));
        # print '-' x $column_lengths->[$i];
        $i++;
    }
    #print " |\n";
    print "\n";
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
