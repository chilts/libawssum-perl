## ----------------------------------------------------------------------------

package AwsSum::Service;

use Moose::Role;
with 'AwsSum::Validate';

use Carp;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);

## ----------------------------------------------------------------------------
# set the things that the implementing class should do

requires qw(
    commands
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

sub set_header {
    my ($self, $name, $value) = @_;
    $self->headers->{$name} = $value;
}

sub send {
    my ($self) = @_;

    # Signing of the request can consist of any or all of the following:
    # * adding service headers
    # * adding service parameters
    # * calculating the signature (or using a ready made one)
    # * adding the signature as either a parameter or a header
    $self->sign();

    my $ua = LWP::UserAgent->new();
    my $url = $self->url;
    my $verb = $self->verb();
    my $res;
    if ( $verb eq 'get' ) {
        $url = URI->new( $url );
        $url->query_form( %{$self->params} );
        $res = $ua->get( $url, %{$self->headers} );
    }
    elsif ( $verb eq 'post' ) {
        $res = $ua->post(
            $self->url,
            $self->params,
            %{$self->headers},
        );
    }
    else {
        # currently unsupported
        croak "This HTTP Verb '$verb' is currently unsupported ... please help by adding it for me and sending me a patch :)";
    }

    $self->req( $res->request );
    $self->res( $res );

    # ToDo: check the the return HTTP code is the same as $self->code()

    # if we failed, just return nothing
    return unless $res->is_success;

    # decode response should fill in 'data'
    $self->decode();
    return $self->data;
}

sub set_command {
    my ($self, $command_name) = @_;
    $self->_command( $self->commands->{$command_name} );
}

sub command_sub_name {
    my ($self, $command) = @_;
    return $self->commands->{$command}{method};
}

sub command_opts {
    my ($self, $command) = @_;
    return $self->commands->{$command}{opts} || [];
}

sub command_opts_booleans {
    my ($self, $command) = @_;
    return $self->commands->{$command}{opts_booleans} || {};
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
