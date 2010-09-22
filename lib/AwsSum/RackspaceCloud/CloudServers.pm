## ----------------------------------------------------------------------------

package AwsSum::RackspaceCloud::CloudServers;

use Moose;
with 'AwsSum::Service';

use JSON::Any;

## ----------------------------------------------------------------------------
# we require these things off the using code

# some things required from the user
has 'auth_token' => ( is => 'rw', isa => 'Str' );
has 'endpoint'   => ( is => 'rw', isa => 'Str' );

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    'api-versions' => {
        name           => 'api-versions',
        path           => '/versions.json',
        method         => 'api_versions',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    'limits' => {
        name           => 'limits',
        path           => '/limits.json',
        method         => 'limits',
        http_method    => 'get',
    },
    'servers' => {
        name           => 'servers',
        path           => '/servers.json',
        method         => 'servers',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
    'servers-detail' => {
        name           => 'servers-detail',
        path           => '/servers/detail.json',
        method         => 'servers_detail',
        verb           => 'get',
        code           => { 200 => 1, 203 => 1 },
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub set_command {
    my ($self, $command_name) = @_;
    $self->_command( $commands->{$command_name} );
}

sub command_sub_name {
    my ($class, $command) = @_;
    return $commands->{$command}{method};
}

sub verb {
    my ($self) = @_;
    return $self->_command->{verb};
}
sub url {
    my ($self) = @_;
    return $self->endpoint . $self->_command->{path};
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

sub servers {
    my ($self, $params) = @_;

    $self->set_command( 'servers' );

    return $self->send();
}

sub servers_detail {
    my ($self, $params) = @_;

    $self->set_command( 'servers-detail' );

    return $self->send();
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
