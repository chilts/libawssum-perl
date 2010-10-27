## ----------------------------------------------------------------------------

package AwsSum::Service;

use Moose::Role;
with 'AwsSum::Validate';

use Carp;
use Data::Dumper;
use LWP::UserAgent;
use HTTP::Request::Common qw(POST);
use HTTP::Request;
use URI;

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

# the content to be sent to the service for this request
has 'content' => (
    is => 'rw',
    isa => 'Str',
);

# this is the data returned from the service (no default)
has 'data' => (
    is => 'rw',
    isa => 'Any',
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

sub set_param_maybe {
    my ($self, $name, $value) = @_;
    return unless defined $value;
    $self->params->{$name} = $value;
}

sub get_param {
    my ($self, $name) = @_;
    return $self->params->{$name};
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
    my $content = $self->content();
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
            ( defined $content ? (Content => $content) : () ),
        );
    }
    elsif ( $verb eq 'put' ) {
        # we need to put the params into the URL
        my $uri = URI->new( $url );
        $uri->query_form( $self->params );

        # now create the request
        my $req = HTTP::Request->new(
            uc $verb,
            $uri,
            [ %{$self->headers} ],
            $content,
        );

        # send it and get the response
        $res = $ua->request( $req );
    }
    elsif ( $verb eq 'delete' ) {
        # we need to put the params into the URL
        my $uri = URI->new( $url );
        $uri->query_form( $self->params );

        # now create the request
        my $req = HTTP::Request->new(
            uc $verb,
            $uri,
            [ %{$self->headers} ],
            $content,
        );

        # send it and get the response
        $res = $ua->request( $req );
    }
    else {
        # currently unsupported
        croak "This HTTP Verb '$verb' is currently unsupported ... please help by adding it for me and sending me a patch :)";
    }

    $self->req( $res->request );
    $self->res( $res );

    # decode response should fill in 'data' (independent of whether LWP regards
    # the request as success or failure).
    $self->decode();

    # ToDo: could check here if something went wrong, and throw an error?

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

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
