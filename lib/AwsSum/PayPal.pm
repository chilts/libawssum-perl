## ----------------------------------------------------------------------------

package AwsSum::PayPal;

use Moose;
use Moose::Util::TypeConstraints;
with 'AwsSum::Service';

use Carp;
use URI::Escape;

my $API_VERSION = '64.0';

## ----------------------------------------------------------------------------
# we require these things off the using code

# some things required from the user
has 'username'  => ( is => 'rw', isa => 'Str' );
has 'password'  => ( is => 'rw', isa => 'Str' );
has 'signature' => ( is => 'rw', isa => 'Str' );

# let the user decide which endpoint they wish to use
enum 'Endpoint' => qw(Live Sandbox);
has 'endpoint' => ( is => 'rw', isa => 'Endpoint', default => 'Live' );

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    'get-balance' => {
        name           => 'GetBalance',
        method         => 'get_balance',
        params         => {
            'return-all-currencies' => {
                type     => 'Boolean',
                required => 0,
            },
        },
        opts           => [ 'return-all-currencies' ],
        opts_booleans  => {
            'return-all-currencies' => 1,
        },
    },
    'transaction-search' => {
        name           => 'TransactionSearch',
        method         => 'transaction_search',
        params         => {
            'start-datetime' => {
                name     => 'STARTDATE',
                type     => 'DateTime',
                required => 1,
            },
        },
        opts           => [ 'start-datetime=s' ],
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }

sub verb { 'post' }

sub url {
    my ($self) = @_;

    # depending on the end point, return a particular URL
    return q{https://api-3t.paypal.com/nvp}
        if $self->endpoint eq 'Live';
    return q{https://api-3t.sandbox.paypal.com/nvp}
        if $self->endpoint eq 'Sandbox';

    die "Program error: unknown endpoint '" . $self->endpoint . "'";
}

sub code { 200 }

sub sign {
    my ($self) = @_;

    # add some params, no headers
    $self->set_param( 'METHOD', $self->_command->{name} );
    $self->set_param( 'USER', $self->username );
    $self->set_param( 'PWD', $self->password );
    $self->set_param( 'VERSION', $API_VERSION );

    # this isn't really signing it, but just add the signature to the params
    $self->set_param( 'SIGNATURE', $self->signature );
}

sub decode {
    my ($self) = @_;

    # get the content from the response
    my $response_text = $self->res->content();

    my @pairs = split('&', $response_text);
    my $h = {};
    foreach ( @pairs ) {
        my ($key, $value) = split('=');
        $h->{$key} = uri_unescape($value);
    }

    # ToDo: merge some keys into specific lists

    # find out all the final L_*n elements that we haven't put into proper lists yet
    foreach my $key ( sort keys %$h ) {
        # if this is a list, split it out
        next unless $key =~ m{ \A L_ ([A-Z]+) (\d+) \z }xms;
        my ($name, $index) = ($1, $2);
        $h->{list}[$index]{$name} = $h->{$key};
        delete $h->{$key};
    }

    $self->data( $h );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub get_balance {
    my ($self, $param) = @_;

    if ( $param->{'return-all-currencies'} and !$self->is_valid_boolean($param->{'return-all-currencies'}) ) {
        croak "Provide a valid boolean (0|1) for 'return-all-currencies'";
    }

    $self->set_command( 'get-balance' );
    $self->set_param( 'RETURNALLCURRENCIES', "$param->{'return-all-currencies'}" )
        if exists $param->{'return-all-currencies'};

    return $self->send();
}

sub transaction_search {
    my ($self, $param) = @_;

    unless ( $self->is_valid_datetime($param->{'start-datetime'}) ) {
        croak "Provide a valid datetime for the 'start-datetime' parameter";
    }

    $self->set_command( 'transaction-search' );
    $self->set_param( 'STARTDATE', "$param->{'start-datetime'}" );

    return $self->send();
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
