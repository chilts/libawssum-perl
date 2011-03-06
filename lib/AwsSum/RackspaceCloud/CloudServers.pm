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
    apiVersions => {
        name           => 'apiVersions',
        method         => 'apiVersions',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    apiVersionDetails => {
        name           => 'apiVersionDetails',
        method         => 'apiVersionDetails',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    limits => {
        name           => 'limits',
        method         => 'limits',
        verb           => 'get',
        path           => '/limits.json',
    },
    listServers => {
        name           => 'listServers',
        method         => 'listServers',
        verb           => 'get',
        path           => '/servers.json',
        code           => { 200 => 1, 203 => 1 },
    },
    listServersDetail => {
        name           => 'listServersDetail',
        method         => 'listServersDetail',
        verb           => 'get',
        path           => '/servers/detail.json',
        code           => { 200 => 1, 203 => 1 },
    },
    getServerDetails => {
        name           => 'getServerDetails',
        method         => 'getServerDetails',
        verb           => 'get',
        # path
        code           => { 200 => 1, 203 => 1 },
    },
    listFlavors => {
        name           => 'listFlavors',
        method         => 'listFlavors',
        path           => '/flavors.json',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    listFlavorsDetail => {
        name           => 'listFlavorsDetail',
        method         => 'listFlavorsDetail',
        verb           => 'get',
        path           => '/flavors/detail.json',
        code           => { 200 => 1, 203 => 1 },
    },
    getFlavorDetails => {
        name           => 'getFlavorDetails',
        method         => 'getFlavorDetails',
        verb           => 'get',
        # path
        code           => { 200 => 1, 203 => 1 },
    },
    listImages => {
        name           => 'listImages',
        method         => 'listImages',
        verb           => 'get',
        path           => '/images.json',
        code           => { 200 => 1, 203 => 1 },
    },
    listImagesDetail => {
        name           => 'listImagesDetail',
        method         => 'listImagesDetail',
        verb           => 'get',
        path           => '/images/detail.json',
        code           => { 200 => 1, 203 => 1 },
    },
    getImageDetails => {
        name           => 'getImageDetails',
        method         => 'getImageDetails',
        verb           => 'get',
        # path
        code           => { 200 => 1, 203 => 1 },
    },
    createServer => {
        name           => 'createServer',
        method         => 'createServer',
        verb           => 'post',
        path           => '/servers.json',
        code           => 200,
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }

sub cmd_attr {
    my ($self, $attr) = @_;
    return $self->_command->{$attr};
}

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

sub apiVersions {
    my ($self, $param) = @_;
    $self->set_command( 'apiVersions' );
    $self->_url( q{https://servers.api.rackspacecloud.com/.json} );
    return $self->send();
}

sub apiVersionDetails {
    my ($self, $param) = @_;

    unless ( defined $param->{apiVersionId} ) {
        croak "Provide a valid version string for the 'id' parameter";
    }

    $self->set_command( 'apiVersionDetails' );
    $self->_url( q{https://servers.api.rackspacecloud.com/} . uri_escape($param->{apiVersionId}) . q{/.json} );
    return $self->send();
}

sub listServers {
    my ($self, $param) = @_;

    $self->set_command( 'listServers' );

    return $self->send();
}

sub listServersDetail {
    my ($self, $param) = @_;

    $self->set_command( 'listServersDetail' );

    return $self->send();
}

sub getServerDetails {
    my ($self, $param) = @_;

    unless ( $self->is_valid_integer($param->{serverId}) ) {
        croak "Provide a valid integer for the 'id' parameter";
    }

    $self->set_command( 'getServerDetails' );
    $self->_url( $self->endpoint . '/servers/' . uri_escape($param->{serverId}) );

    return $self->send();
}

sub listFlavors {
    my ($self, $param) = @_;

    $self->set_command( 'listFlavors' );

    return $self->send();
}

sub listFlavorsDetail {
    my ($self, $param) = @_;

    $self->set_command( 'listFlavorsDetail' );

    return $self->send();
}

sub getFlavorDetails {
    my ($self, $param) = @_;

    unless ( $self->is_valid_integer($param->{flavorId}) ) {
        croak "Provide a valid integer for the 'id' parameter";
    }

    $self->set_command( 'getFlavorDetails' );
    $self->_url( $self->endpoint . '/flavors/' . uri_escape($param->{flavorId}) );

    return $self->send();
}

sub listImages {
    my ($self, $param) = @_;

    $self->set_command( 'listImages' );

    return $self->send();
}

sub listImagesDetail {
    my ($self, $param) = @_;

    $self->set_command( 'listImagesDetail' );

    return $self->send();
}

sub getImageDetails {
    my ($self, $param) = @_;

    unless ( $self->is_valid_integer($param->{imageId}) ) {
        croak "Provide a valid integer for the 'id' parameter";
    }

    $self->set_command( 'getImageDetails' );
    $self->_url( $self->endpoint . '/images/' . uri_escape($param->{imageId}) );

    return $self->send();
}

sub createServer {
    my ($self, $param) = @_;

    warn "here\n";

    unless ( $self->is_valid_something($param->{name}) ) {
        croak "Provide something for the server 'name'";
    }
    unless ( $self->is_valid_integer($param->{flavorId}) ) {
        croak "Provide a valid integer for the 'flavorId' parameter";
    }
    unless ( $self->is_valid_integer($param->{imageId}) ) {
        croak "Provide a valid integer for the 'imageId' parameter";
    }

    $self->set_command( 'createServer' );
    $self->content( JSON::Any->encode(
        {
            server => {
                name => $param->{name},
                imageId => $param->{imageId},
                flavorId => $param->{flavorId},
                metadata => {},
            },
        }
    ));

    return $self->send();
}

## ----------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable();
1;
## ----------------------------------------------------------------------------
