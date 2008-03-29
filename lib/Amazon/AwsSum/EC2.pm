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

sub DescribeInstances {
    my ($self, $params) = @_;

    $self->action('DescribeInstances');
    $self->add_numeral_parameters( 'InstanceId', $params->{InstanceId} );
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

sub DescribeImageAttribute {
    my ($self, $params) = @_;

    unless ( defined $params->{ImageId} ) {
        croak( 'provide an image id' );
    }

    unless ( defined $params->{Attribute} ) {
        croak( 'provide an attribute name' );
    }

    $self->action('DescribeImageAttribute');
    $self->add_parameter( 'ImageId', $params->{ImageId} );
    $self->add_parameter( 'Attribute', $params->{Attribute} );
    return $self->send();
}

sub CreateSecurityGroup {
    my ($self, $params) = @_;

    unless ( defined $params->{GroupName} ) {
        croak( 'provide a group name' );
    }

    unless ( defined $params->{GroupDescription} ) {
        croak( 'provide a group description' );
    }

    $self->action('CreateSecurityGroup');
    $self->add_parameter( 'GroupName', $params->{GroupName} );
    $self->add_parameter( 'GroupDescription', $params->{GroupDescription} );
    return $self->send();
}

sub DescribeSecurityGroups {
    my ($self, $params) = @_;

    $self->action('DescribeSecurityGroups');
    $self->add_numeral_parameters( 'GroupName', $params->{GroupName} );
    return $self->send();
}

sub DeleteSecurityGroup {
    my ($self, $params) = @_;

    unless ( defined $params->{GroupName} ) {
        croak( 'provide a group name' );
    }

    $self->action('DeleteSecurityGroup');
    $self->add_parameter( 'GroupName', $params->{GroupName} );
    return $self->send();
}

sub AllocateAddress {
    my ($self, $params) = @_;

    $self->action('AllocateAddress');
    return $self->send();
}

sub DescribeAddresses {
    my ($self, $params) = @_;

    $self->action('DescribeAddresses');
    $self->add_numeral_parameters( 'PublicIp', $params->{PublicIp} );
    return $self->send();
}

sub ReleaseAddress {
    my ($self, $params) = @_;

    unless ( defined $params->{PublicIp} ) {
        croak( 'provide an address to release' );
    }

    $self->action('ReleaseAddress');
    $self->add_parameter( 'PublicIp', $params->{PublicIp} );
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
