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
    add_service_headers
    add_service_params
    sign_request
    make_url
    http_method
    decode_response
);

# the URL to hit
has 'url' => (
    is => 'rw',
    isa => 'Str',
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
has '_http_request' => (
    is  => 'rw',
    isa => 'HTTP::Request',
);

has '_http_response' => (
    is  => 'rw',
    isa => 'HTTP::Response',
);

## ----------------------------------------------------------------------------

sub set_param {
    my ($self, $name, $value) = @_;
    $self->params->{$name} = $value;
}

sub prepare_request {
    my ($self) = @_;

    # add some common headers and other parameters for each service
    $self->add_service_headers();
    $self->add_service_params();

    # we know what we've got now, so sign it
    $self->sign_request();
    $self->make_url();

    # now let's start creating the objects
    # $self->create_http_header();
    # $self->create_request();
}

sub send {
    my ($self) = @_;

    $self->prepare_request();

    # ToDo: need to put the headers into the request somewhere

    my $ua = LWP::UserAgent->new();
    my $http_method = $self->http_method();

    my $res = $ua->$http_method(
        $self->url,
        $self->params,
        # ( $self->headers ? $self->headers : () ),
    );

    $self->_http_request( $res->request );
    $self->_http_response( $res );

    unless ( $res->is_success ) {
        die $res->status_line;
    }

    # decode response should fill in 'data'
    $self->decode_response( $res->content );
    return $self->data;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
