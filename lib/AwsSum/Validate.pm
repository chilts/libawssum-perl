## ----------------------------------------------------------------------------

package AwsSum::Validate;
use Moose::Role;

use Date::Simple;

## ----------------------------------------------------------------------------

sub is_valid_something {
    my ($self, $something) = @_;
    return 0 unless defined $something;
    return 0 unless $something =~ m{ \S }xms;
    return 1;
}

sub is_valid_integer {
    my ($self, $integer) = @_;
    return 0 unless defined $integer;
    return 1 if $integer =~ m{ \A \d+ \z }xms;
    return 0;
}

sub is_valid_boolean {
    my ($self, $boolean) = @_;
    return 0 unless defined $boolean;
    return 1 if $boolean =~ m{ \A (0|1) \z }xms;
    return 0;
}

sub is_valid_datetime {
    my ($self, $datetime) = @_;
    return 0 unless defined $datetime;

    # try and get the individual parts out
    my ($date, $time) = $datetime =~ m{ \A (\d{4}-\d\d-\d\d) T (\d\d:\d\d:\d\d) Z \z }xms;

    return 0 unless $self->is_valid_date($date);
    return 0 unless $self->is_valid_time($time);

    # looks fine
    return 1;
}

sub is_valid_date {
    my ($self, $date) = @_;

    return 0 unless defined $date;

    return 1 if Date::Simple->new($date);

    return 0;
}

sub is_valid_time {
    my ($self, $time) = @_;

    return 0 unless defined $time;

    # get the individual parts
    my ($hr, $min, $sec) = $time =~ m{ \A (\d\d):(\d\d):(\d\d) \z }xms;

    return 0 unless $hr >=0 and $hr <= 23;
    return 0 unless $min >= 0 and $min <= 59;
    return 0 unless $sec >= 0 and $sec <= 59;

    return 1;
}


## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
