## ----------------------------------------------------------------------------

package Amazon::AwsSum::EC2;

use strict;
use warnings;
use Carp;

use base qw(Amazon::AwsSum::Service);

use URI::Escape;
use DateTime;

sub service_version { '2008-02-01' }
sub decode_xml { 1 }
sub method { 'GET' }

## ----------------------------------------------------------------------------
# commands

sub DescribeImages {
    my ($self, $params) = @_;

    $self->action('DescribeImages');
    foreach my $param_name ( qw(ImageId Owner ExecutableBy) ) {
        $self->add_numeral_parameters( $param_name, $params->{$param_name} );
    }

    return $self->send();
}

sub DescribeKeyPairs {
    my ($self, $params) = @_;

    $self->action('DescribeKeyPairs');
    $self->add_numeral_parameters( 'KeyName', $params->{KeyName} );
    return $self->send();
}

sub CreateKeyPair {
    my ($self, $params) = @_;

    unless ( defined $params->{KeyName} ) {
        croak( 'provide a key name to create' );
    }

    $self->action('CreateKeyPair');
    $self->add_parameter( 'KeyName', $params->{KeyName} );
    return $self->send();
}

sub DeleteKeyPair {
    my ($self, $params) = @_;

    unless ( defined $params->{KeyName} ) {
        croak( 'provide a key name to delete' );
    }

    $self->action('DeleteKeyPair');
    $self->add_parameter( 'KeyName', $params->{KeyName} );
    return $self->send();
}

sub DescribeAvailabilityZone {
    my ($self, $params) = @_;

    $self->action('DescribeAvailabilityZones');
    $self->add_numeral_parameters( 'ZoneName', $params->{ZoneName} );
    return $self->send();
}

## ----------------------------------------------------------------------------
# utils

sub generate_url {
    my ($self) = @_;
    my $url;

    # create the URL with the action...
    $url = "https://ec2.amazonaws.com:443/?Action=" . $self->action;

    # ...then add all the params on
    my $params = $self->params;
    $url .= '&' . join('&', map { "$_=" . uri_escape($params->{$_}) } keys %$params);

    $self->url( $url );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
