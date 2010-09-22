## ----------------------------------------------------------------------------

package AwsSum::RackspaceCloud::Authenticate;

use Moose;
with 'AwsSum::Service';

## ----------------------------------------------------------------------------
# we require these things off the using code

# some things required from the user
has 'user' => ( is => 'rw', isa => 'Str' );
has 'key'  => ( is => 'rw', isa => 'Str' );

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    'authenticate' => {
        name           => 'authenticate',
        method         => 'authenticate',
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }
sub verb     { 'get' }
sub url      { q{https://auth.api.rackspacecloud.com/v1.0} }
sub code     { 204 }

sub sign {
    my ($self) = @_;

    # nothing to sign, but just set a couple of headers
    $self->set_header( 'X-Auth-User', $self->user );
    $self->set_header( 'X-Auth-Key', $self->key );
}

sub decode {
    my ($self) = @_;

    # Note: the service provides a '204 No Content' as the success hence why we
    # need info from the headers.

    # firstly, get the headers
    my $hdrs = $self->res_headers();

    # extract the particular headers we need
    my $data = {};
    foreach my $hdr ( 'X-Server-Management-Url', 'X-Storage-Url', 'X-CDN-Management-Url', 'X-Auth-Token' ) {
        $data->{$hdr} = $hdrs->header( $hdr );
    }

    $self->data( $data);
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub authenticate {
    my ($self, $params) = @_;

    $self->set_command( 'authenticate' );

    return $self->send();
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
