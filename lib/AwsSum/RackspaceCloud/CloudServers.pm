## ----------------------------------------------------------------------------

package AwsSum::RackspaceCloud::CloudServers;

use Moose;
with 'AwsSum::Service';

use Carp;
use JSON::Any;
use URI::Escape;

## ----------------------------------------------------------------------------
# we require these things off the using code

# some things required from the user
has 'auth_token' => ( is => 'rw', isa => 'Str' );
has 'endpoint'   => ( is => 'rw', isa => 'Str' );

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

# since URL changes dependent on the command, we'll just set it in each
# command's method rather than creating it during execution. Then we just
# return as usual it when asked.
has '_url' => ( is => 'rw', isa => 'Str' );

## ----------------------------------------------------------------------------

my $commands = {
    'api-versions' => {
        name           => 'api-versions',
        method         => 'api_versions',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    'api-version-details' => {
        name           => 'api-version-details',
        method         => 'api_version_details',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
        opts           => [ 'id=s' ],
    },
    'limits' => {
        name           => 'limits',
        path           => '/limits.json',
        method         => 'limits',
        http_method    => 'get',
    },
    'list-servers' => {
        name           => 'list-servers',
        path           => '/servers.json',
        method         => 'list_servers',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    'list-servers-detail' => {
        name           => 'list-servers-detail',
        path           => '/servers/detail.json',
        method         => 'list_servers_detail',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    'get-server-details' => {
        name           => 'get-server-details',
        method         => 'get_server_details',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
        opts           => [ 'id=s' ],
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }

sub verb {
    my ($self) = @_;
    return $self->_command->{verb};
}

sub url {
    my ($self) = @_;

    # if we have made a URL then just return it
    return $self->_url if $self->_url;

    # else, use the predetermined one
    if ( $self->_command->{path} ) {
        return $self->endpoint . $self->_command->{path};
    }

    die "Program error: no URL created, therefore we don't know what to do";
}

sub code {
    my ($self) = @_;
    return $self->_command->{code};
}

sub sign {
    my ($self) = @_;

    # not much to do for RackspaceCloud's signatures
    $self->set_header( 'X-Auth-Token', $self->auth_token );
}

sub decode {
    my ($self) = @_;
    $self->data( JSON::Any->jsonToObj( $self->res->content() ) );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub api_versions {
    my ($self, $params) = @_;
    $self->set_command( 'api-versions' );
    $self->_url( q{https://servers.api.rackspacecloud.com/.json} );
    return $self->send();
}

sub api_version_details {
    my ($self, $param) = @_;

    unless ( defined $param->{id} ) {
        croak "Provide a valid version string for the 'id' parameter";
    }

    $self->set_command( 'api-version-details' );
    $self->_url( q{https://servers.api.rackspacecloud.com/} . uri_escape($param->{id}) . q{/.json} );
    return $self->send();
}

sub list_servers {
    my ($self, $param) = @_;

    $self->set_command( 'list-servers' );

    return $self->send();
}

sub list_servers_detail {
    my ($self, $param) = @_;

    $self->set_command( 'list-servers-detail' );

    return $self->send();
}

sub get_server_details {
    my ($self, $param) = @_;

    unless ( $self->is_valid_integer($param->{id}) ) {
        croak "Provide a valid integer for the 'id' parameter";
    }

    $self->set_command( 'get-server-details' );
    $self->_url( $self->endpoint . '/servers/' . uri_escape($param->{id}) );

    return $self->send();
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
