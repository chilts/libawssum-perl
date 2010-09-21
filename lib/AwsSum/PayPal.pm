## ----------------------------------------------------------------------------

package AwsSum::PayPal;

use Moose;
use Moose::Util::TypeConstraints;
use URI::Escape;

with 'AwsSum::Service';

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
    'GetBalance' => {
        name           => 'GetBalance',
        method         => 'get_balance',
        params         => {
            RETURNALLCURRENCIES => {
                type     => 'Boolean',
                required => 0,
            },
        },
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub command_sub_name {
    my ($class, $command) = @_;
    return $commands->{$command}{method};
}

sub http_method { 'post' }
sub add_service_headers {}

sub add_service_params {
    my ($self) = @_;

    $self->set_param( 'METHOD', $self->_command->{name} );
    $self->set_param( 'USER', $self->username );
    $self->set_param( 'PWD', $self->password );
    $self->set_param( 'SIGNATURE', $self->signature );
    $self->set_param( 'VERSION', $API_VERSION );
}

sub sign_request {
    my ($self) = @_;

    # if we don't need to sign this request, get out of here
    return unless $self->_command->{authentication};

    # print "AwsSum::Flickr::Service::sign_request(): enter\n";

    # See: http://www.flickr.com/services/api/auth.spec.html

    # start off the string to be signed
    my $str = $self->api_secret;

    # add the (sorted) name-value pairs from the params
    my $params = $self->params;
    foreach my $p ( sort keys %$params ) {
        $str .= $p . $params->{$p};
    }

    # print "Signing [$str]\n";

    # calculate the md5_hex hash and add it as 'api_sig'
    $self->set_param( 'api_sig', md5_hex($str) );
}

sub make_url {
    my ($self) = @_;
    # depending on the end point, return a particular URL
    if ( $self->endpoint eq 'Sandbox' ) {
        $self->url( q{https://api-3t.sandbox.paypal.com/nvp} );
    }
    elsif ( $self->endpoint eq 'Live' ) {
        $self->url( q{https://api-3t.paypal.com/nvp} );
    }
    else {
        die "Program error: unknown endpoint";
    }
}

sub decode_response {
    my ($self, $response_text) = @_;

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

sub set_command {
    my ($self, $command_name) = @_;
    $self->_command( $commands->{$command_name} );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub get_balance {
    my ($self, $params) = @_;

    $self->set_command( 'GetBalance' );

    return $self->send();
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
