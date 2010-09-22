## ----------------------------------------------------------------------------

package AwsSum::Flickr;

use Moose;
with 'AwsSum::Service';

use Digest::MD5 qw(md5_hex);
use JSON::Any;

## ----------------------------------------------------------------------------
# we require these things off the using code

# some things required from the user
has 'api_key'    => ( is => 'rw', isa => 'Str' );
has 'api_secret' => ( is => 'rw', isa => 'Str' );
has 'auth_token' => ( is => 'rw', isa => 'Str' );

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    'flickr.test.echo' => {
        name           => 'flickr.test.echo',
        api_key        => 1,
        authentication => 0,
        signature      => 0,
        method         => 'test_echo',
        verb           => 'post',
        params         => {},
    },
    'flickr.test.null' => {
        name           => 'flickr.test.null',
        api_key        => 1,
        authentication => 1,
        signature      => 1,
        method         => 'test_null',
        verb           => 'post',
        params         => {},
    },
    'flickr.auth.checkToken' => {
        name           => 'flickr.auth.checkToken',
        api_key        => 1,
        authentication => 1,
        signature      => 1,
        method         => 'auth_check_token',
        verb           => 'post',
        params         => {},
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }
sub verb {
    my ($self) = @_;
    return $self->_command->{verb};
}
sub url { q{http://api.flickr.com/services/rest/} }
sub code { 200 }

sub sign {
    my ($self) = @_;

    # add the service params first before signing
    $self->set_param( 'method', $self->_command->{name} );
    $self->set_param( 'format', 'json' );
    $self->set_param( 'nojsoncallback', 1 );
    $self->set_param( 'api_key', $self->api_key )
        if $self->_command->{api_key};

    # if we don't need to sign this request, get out of here
    return unless $self->_command->{authentication};

    # See: http://www.flickr.com/services/api/auth.spec.html

    # start off the string to be signed
    my $str = $self->api_secret;

    # add the (sorted) name-value pairs from the params
    my $params = $self->params;
    foreach my $p ( sort keys %$params ) {
        $str .= $p . $params->{$p};
    }

    # calculate the md5_hex hash and add it as 'api_sig'
    $self->set_param( 'api_sig', md5_hex($str) );
}

sub decode {
    my ($self) = @_;

    $self->data( JSON::Any->jsonToObj( $self->res->content() ) );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub test_echo {
    my ($self, $param) = @_;

    $self->set_command( 'flickr.test.echo' );

    return $self->send();
}

sub test_null {
    my ($self, $param) = @_;

    $self->set_command( 'flickr.test.null' );
    $self->set_param( 'auth_token', $self->auth_token );

    return $self->send();
}

sub auth_check_token {
    my ($self, $param) = @_;

    $self->set_command( 'flickr.auth.checkToken' );
    $self->set_param( 'auth_token', $self->auth_token );

    return $self->send();
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
