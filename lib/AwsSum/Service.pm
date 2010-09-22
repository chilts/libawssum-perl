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
    command_sub_name
    verb
    url
    code
    sign
    decode
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
has 'req' => (
    is  => 'rw',
    isa => 'HTTP::Request',
);

sub req_url {
    my ($self) = @_;
    return $self->req->uri();
}

sub req_headers {
    my ($self) = @_;
    return $self->req->headers();
}

sub req_params {
    my ($self) = @_;
    return $self->req->params();
}

sub req_content {
    my ($self) = @_;
    return $self->req->content();
}

has 'res' => (
    is  => 'rw',
    isa => 'HTTP::Response',
);

sub res_code {
    my ($self) = @_;
    return $self->res->code();
}

sub res_headers {
    my ($self) = @_;
    return $self->res->headers();
}

sub res_content {
    my ($self) = @_;
    return $self->res->content();
}

## ----------------------------------------------------------------------------

sub set_param {
    my ($self, $name, $value) = @_;
    $self->params->{$name} = $value;
}

sub send {
    my ($self) = @_;

    # Signing of the request can consist of any or all of the following:
    # * adding service headers
    # * adding service parameters
    # * calculating the signature (or using a ready made one)
    # * adding the signature as either a parameter or a header
    $self->sign();

    # ToDo: need to put the headers into the request somewhere

    my $ua = LWP::UserAgent->new();
    my $verb = $self->verb();

    my $res = $ua->$verb(
        $self->url,
        $self->params,
        # ( $self->headers ? $self->headers : () ),
    );

    $self->req( $res->request );
    $self->res( $res );

    unless ( $res->is_success ) {
        die $res->status_line;
    }

    # ToDo: check the the return HTTP code is the same as $self->code()

    # decode response should fill in 'data'
    $self->decode();
    return $self->data;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
