## ----------------------------------------------------------------------------

package AwsSum::Service;

use Moose::Role;

use Carp;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

## ----------------------------------------------------------------------------
# set the things that the implementing class should do

requires qw(
    http_method
    add_service_info
    sign
    url
    decode_response
    http_code_expected
);

# the params to be sent to the service for this request
has 'params' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

# the headers to be sent to the service for this request
has 'headers' => (
    is => 'rw',
    isa => 'HashRef',
    default => sub { {} },
);

# this is the data returned from the service (no default)
has 'data' => (
    is => 'rw',
    isa => 'HashRef',
);

# these are functions so that we can return what was sent and received
has 'http_request' => (
    is  => 'rw',
    isa => 'HTTP::Request',
);

has 'http_response' => (
    is  => 'rw',
    isa => 'HTTP::Response',
);

## ----------------------------------------------------------------------------

sub set_param {
    my ($self, $name, $value) = @_;
    $self->params->{$name} = $value;
}

sub send {
    my ($self) = @_;

    $self->add_service_info();
    $self->sign();

    # ToDo: need to put the headers into the request somewhere

    my $ua = LWP::UserAgent->new();
    my $http_method = $self->http_method();

    my $res = $ua->$http_method(
        $self->url,
        $self->params,
        # ( $self->headers ? $self->headers : () ),
    );

    $self->http_request( $res->request );
    $self->http_response( $res );

    unless ( $res->is_success ) {
        die $res->status_line;
    }

    # decode response should fill in 'data'
    $self->decode_response();
    return $self->data;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
