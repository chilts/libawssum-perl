## ----------------------------------------------------------------------------

package AwsSum::Amazon::RDS;

use Moose;
use Moose::Util::TypeConstraints;
with qw(
    AwsSum::Service
    AwsSum::Amazon::Service
);

use Carp;
use DateTime;
use List::Util qw( reduce );
use Digest::SHA qw (hmac_sha1_base64 hmac_sha256_base64);
use XML::Simple;
use URI::Escape;
use MIME::Base64;

## ----------------------------------------------------------------------------
# setup details needed or pre-determined

# some things required from the user
enum 'SignatureMethod' => qw(HmacSHA1 HmacSHA256);
has 'signature_method'   => ( is => 'rw', isa => 'SignatureMethod', default => 'HmacSHA256' );

# constants
# Version: http://docs.amazonwebservices.com/AmazonRDS/latest/APIReference/WhatsNew.html
sub version { '2010-07-28' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # Instances
    # * CreateDBInstance
    # * CreateDBInstanceReadReplica
    # * DescribeDBInstances
    # * ModifyDBInstance
    # * RebootDBInstance
    # * DeleteDBInstance

    # Parameter Groups
    # * CreateDBParameterGroup
    # * DeleteDBParameterGroup
    # * DescribeDBEngineVersions
    # * DescribeEngineDefaultParameters
    # * DescribeDBParameterGroups
    # * DescribeDBParameters
    # * ModifyDBParameterGroup
    # * RebootDBInstance
    # * ResetDBParameterGroup

    # Security Groups
    # * CreateDBSecurityGroup
    # * DescribeDBSecurityGroups
    # * DeleteDBSecurityGroup
    # * AuthorizeDBSecurityGroupIngress
    # * RevokeDBSecurityGroupIngress
    # * CreateDBSnapshot
    # * DescribeDBSnapshots
    # * DeleteDBSnapshot
    # * RestoreDBInstanceFromDBSnapshot
    # * RestoreDBInstanceToPointInTime

    # Events
    # * DescribeEvents

    # Reserved Offerings
    # * DescribeReservedDBInstancesOfferings
    # * PurchaseReservedDBInstancesOffering
    # * DescribeReservedDBInstances

    # Instances
    DescribeDBInstances => {
        name => 'DescribeDBInstances',
        method => 'describe_db_instances',
    },
};

sub _host {
    my ($self) = @_;
    return q{rds.} . $self->region . q{.amazonaws.com};
}

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

# * commands
# * verb
# * url
# * code
# * sign
# * decode

sub commands { $commands }

sub cmd_attr {
    my ($self, $attr) = @_;
    return $self->_command->{$attr};
}

sub verb { 'get' }

sub url {
    my ($self) = @_;

    # From: http://docs.amazonwebservices.com/AmazonRDS/latest/APIReference/
    return q{https://} . $self->_host . q{/};
}

sub code { 200 }

sub sign {
    my ($self) = @_;

    my $date = DateTime->now( time_zone => 'UTC' )->strftime("%Y-%m-%dT%H:%M:%SZ");

    # add the service params first before signing
    $self->set_param( 'Action', $self->_command->{name} );
    $self->set_param( 'Version', $self->version );
    $self->set_param( 'AWSAccessKeyId', $self->access_key_id );
    $self->set_param( 'Timestamp', $date );
    $self->set_param( 'SignatureVersion', 2 );
    $self->set_param( 'SignatureMethod', $self->signature_method );

    # See: http://docs.amazonwebservices.com/AWSEC2/2010-08-31/DeveloperGuide/index.html?using-query-api.html

    # sign the request (remember this is SignatureVersion '2')
    my $str_to_sign = '';
    $str_to_sign .= uc($self->verb) . "\n";
    $str_to_sign .= $self->_host . "\n";
    $str_to_sign .= "/\n";

    my $param = $self->params();
    $str_to_sign .= join('&', map { "$_=" . uri_escape($param->{$_}) } sort keys %$param);

    # sign the $str_to_sign
    my $signature = ( $self->signature_method eq 'HmacSHA1' )
        ? hmac_sha1_base64($str_to_sign, $self->secret_access_key )
        : hmac_sha256_base64($str_to_sign, $self->secret_access_key );
    $self->set_param( 'Signature', $signature . '=' );
}

sub decode {
    my ($self) = @_;

    # With RDS, we _always_ get some XML back no matter what happened.
    # Note: KeyAttr => [] is to stop folding into a hash
    my $data = XMLin( $self->res->content(), KeyAttr => [] );

    # see if this request passed the expected return code (this is the only
    # check we do here)
    if ( $self->res_code == $self->code ) {
        $data->{_awssum} = {
            'ok' => 1,
        }
    }
    else {
        $data->{_awssum} = {
            'ok'      => 0,
            'type'    => $data->{Error}{Type},
            'error'   => $data->{Error}{Code},
            'message' => $data->{Error}{Message},
        }
    }

    # save it for the outside world
    $self->data( $data );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub describe_db_instances {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeDBInstances' );
    foreach ( qw(DBInstanceIdentifier MaxRecords Marker) ) {
        $self->set_param( $_, $param->{$_} )
            if $param->{$_};
    }
    return $self->send();
}

sub create_db_instance {
    my ($self, $param) = @_;

    $self->set_command( 'CreateDBInstance' );
    unless ( $self->is_valid_something($param->{DBInstanceIdentifier}) ) {
        croak q{Provide a 'DBInstanceIdentifier' for the new DB instance};
    }
    unless ( $self->is_valid_integer($param->{AllocatedStorage}) ) {
        croak q{Provide 'AllocatedStorage' (GB) for initial storage};
    }
    unless ( $self->is_valid_something($param->{DBInstanceClass}) ) {
        croak q{Provide the 'DBInstanceClass' for this DB instance};
    }
    unless ( $self->is_valid_something($param->{Engine}) ) {
        croak q{Provide the 'Engine' for this DB instance};
    }
    unless ( $self->is_valid_something($param->{MasterUsername}) ) {
        croak q{Provide the 'MasterUsername' for this DB instance};
    }
    unless ( $self->is_valid_something($param->{MasterUserPassword}) ) {
        croak q{Provide the 'MasterUserPassword' for this DB instance};
    }

    foreach ( qw(MultiAZ Port DBName DBParameterGroupName DBSecurityGroups AvailabilityZone PreferredMaintenanceWindow BackupRetentionPeriod PreferredBackupWindow EngineVersion AutoMinorVersionUpgrade) ) {
        $self->set_param( $_, $param->{$_} )
            if $param->{$_};
    }
    return $self->send();
}

## ----------------------------------------------------------------------------
# internal methods

sub _fix_hash_to_array {
    my ($self, $hash) = @_;

    return unless defined $hash;

    croak "Trying to fix something that is not a hash" unless ref $hash eq 'HASH';
    croak "Trying to fix a hash which has more than one child" if keys %$hash > 1;

    # use $_[1] to change the 'actual' thing passed in
    if ( exists $hash->{item} ) {
        $_[1] = $self->_make_array_from( $hash->{item} );
    }
    else {
        $_[1] = [];
    }
    return;
}

## ----------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable();
1;
## ----------------------------------------------------------------------------

=pod

=head1 NAME

AwsSum::Amazon::EC2 - interface to Amazon's EC2 web service

=head1 SYNOPSIS

    $ec2 = AwsSum::Amazon::EC2->new();
    $ec2->access_key_id( 'abc' );
    $ec2->secret_access_key( 'xyz' );

    # reserve an IP address
    $ec2->allocate_address();

    # list IP addresses
    $ec2->describe_addresses();

    # release an IP
    $ec2->release_address({ PublicIp => '1.2.3.4' });

=cut
