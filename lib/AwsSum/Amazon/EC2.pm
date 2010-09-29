## ----------------------------------------------------------------------------

package AwsSum::Amazon::EC2;

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

my $allowed = {
    # From: http://docs.amazonwebservices.com/AWSEC2/latest/DeveloperGuide/index.html?instance-types.html
    'instance-type' => {
        'm1.small'    => 1,
        'm1.large'    => 1,
        'm1.xlarge'   => 1,
        't1.micro'    => 1,
        'c1.medium'   => 1,
        'c1.xlarge'   => 1,
        'm2.xlarge'   => 1,
        'm2.2xlarge'  => 1,
        'm2.4xlarge'  => 1,
        'cc1.4xlarge' => 1,
    },
};

## ----------------------------------------------------------------------------
# setup details needed or pre-determined

# some things required from the user
enum 'SignatureMethod' => qw(HmacSHA1 HmacSHA256);
has 'signature_method'   => ( is => 'rw', isa => 'SignatureMethod', default => 'HmacSHA256' );

# constants
sub version { '2010-08-31' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # In order of: http://docs.amazonwebservices.com/AWSEC2/latest/APIReference/index.html?OperationList-query.html

    # Amazon DevPay
    # * ConfirmProductInstance
    # AMIs
    # * CreateImage
    # * DeregisterImage
    # * DescribeImageAttribute
    # * DescribeImages
    # * ModifyImageAttribute
    # Availability Zones and Regions
    # * DescribeAvailabilityZones
    # * DescribeRegions
    # Elastic Block Store
    # * AttachVolume
    # * CreateSnapshot
    # * CreateVolume
    # * DeleteSnapshot
    # * DeleteVolume
    # * DescribeSnapshotAttribute
    # * DescribeSnapshots
    # * DescribeVolumes
    # * DetachVolume
    # * ModifySnapshotAttribute
    # * ResetSnapshotAttribute
    # Elastic IP Addresses
    # * AllocateAddress
    # * AssociateAddress
    # * DescribeAddresses
    # * DisassociateAddress
    # * ReleaseAddress
    # General
    # * GetConsoleOutput
    # Images
    # * RegisterImage
    # * ResetImageAttribute
    # Instances
    # * DescribeInstanceAttribute
    # * DescribeInstances
    # * ModifyInstanceAttribute
    # * RebootInstances
    # * ResetInstanceAttribute
    # * RunInstances
    # * StartInstances
    # * StopInstances
    # * TerminateInstances
    # Key Pairs
    # * CreateKeyPair
    # * DeleteKeyPair
    # * DescribeKeyPairs
    # * ImportKeyPair
    # Monitoring
    # * MonitorInstances
    # * UnmonitorInstances
    # Placement Groups
    # * CreatePlacementGroup
    # * DeletePlacementGroup
    # * DescribePlacementGroups
    # Reserved Instances
    # * DescribeReservedInstances
    # * DescribeReservedInstancesOfferings
    # * PurchaseReservedInstancesOffering
    # Security Groups
    # * AuthorizeSecurityGroupIngress
    # * CreateSecurityGroup
    # * DeleteSecurityGroup
    # * DescribeSecurityGroups
    # * RevokeSecurityGroupIngress
    # Spot Instances
    # * CancelSpotInstanceRequests
    # * CreateSpotDatafeedSubscription
    # * DeleteSpotDatafeedSubscription
    # * DescribeSpotDatafeedSubscription
    # * DescribeSpotInstanceRequests
    # * DescribeSpotPriceHistory
    # * RequestSpotInstances
    # Tags
    # * CreateTags
    # * DeleteTags
    # * DescribeTags
    # Windows
    # * BundleInstance
    # * CancelBundleTask
    # * DescribeBundleTasks
    # * GetPasswordData

    # AMIs
    DescribeImages => {
        name           => 'DescribeImages',
        method         => 'describe_images',
    },

    # Availability Zones and Regions
    DescribeAvailabilityZones => {
        name           => 'DescribeAvailabilityZones',
        method         => 'describe_availability_zones',
    },
    DescribeRegions => {
        name           => 'DescribeRegions',
        method         => 'describe_regions',
    },

    # Elastic Block Store
    DescribeVolumes => {
        name           => 'DescribeVolumes',
        method         => 'describe_volumes',
    },

    # Elastic IP Addresses
    AllocateAddress => {
        name           => 'AllocateAddress',
        method         => 'allocate_address',
    },
    DescribeAddresses => {
        name           => 'DescribeAddresses',
        method         => 'describe_addresses',
    },
    ReleaseAddress => {
        name           => 'ReleaseAddress',
        method         => 'release_address',
    },

    # Instances
    DescribeInstances => {
        name           => 'DescribeInstances',
        method         => 'describe_instances',
    },
    RunInstances => {
        name           => 'RunInstances',
        method         => 'run_instances',
    },
    StartInstances => {
        name           => 'StartInstances',
        method         => 'start_instances',
    },
    StopInstances => {
        name           => 'StopInstances',
        method         => 'stop_instances',
    },
    TerminateInstances => {
        name           => 'TerminateInstances',
        method         => 'terminate_instances',
    },

    # Key Pairs
    CreateKeyPair => {
        name           => 'CreateKeyPair',
        method         => 'create_key_pair',
    },
    DeleteKeyPair => {
        name           => 'DeleteKeyPair',
        method         => 'delete_key_pair',
    },
    DescribeKeyPairs => {
        name           => 'DescribeKeyPairs',
        method         => 'describe_key_pairs',
    },
    # * ImportKeyPair

    # Security Groups
    AuthorizeSecurityGroupIngress => {
        name           => 'AuthorizeSecurityGroupIngress',
        method         => 'authorize_security_group_ingress',
    },
    CreateSecurityGroup => {
        name           => 'CreateSecurityGroup',
        method         => 'create_security_group',
    },
    DeleteSecurityGroup => {
        name           => 'DeleteSecurityGroup',
        method         => 'delete_security_group',
    },
    DescribeSecurityGroups => {
        name           => 'DescribeSecurityGroups',
        method         => 'describe_security_groups',
    },
    RevokeSecurityGroupIngress => {
        name           => 'RevokeSecurityGroupIngress',
        method         => 'revoke_security_group_ingress',
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }
sub verb { 'get' }
sub url {
    my ($self) = @_;

    # From: http://docs.amazonwebservices.com/AWSEC2/latest/DeveloperGuide/index.html?using-query-api.html
    return q{https://ec2.} . $self->endpoint . q{.amazonaws.com/};
}
sub host {
    my ($self) = @_;
    return q{ec2.} . $self->endpoint . q{.amazonaws.com};
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
    $str_to_sign .= $self->host . "\n";
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

    $self->data( XMLin( $self->res->content() ));
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub describe_images {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeImages' );
    $self->_amazon_add_flattened_array_to_params( 'ImageId', $param->{ImageId} );
    my $data = $self->send();

    # manipulate the imagesSet list we got back
    $data->{imagesSet} = $self->_make_array( $data->{imagesSet}{item} );
    $_->{productCodes} = $self->_make_array( $_->{productCodes}{item} )
        foreach @{$data->{imagesSet}};
    $_->{blockDeviceMapping} = $self->_make_array( $_->{blockDeviceMapping}{item} )
        foreach @{$data->{imagesSet}};
    $self->data( $data );
    return $self->data;
}

sub describe_availability_zones {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeAvailabilityZones' );
    return $self->send();
}

sub describe_regions {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeRegions' );
    return $self->send();
}

sub describe_volumes {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeVolumes' );
    $self->_amazon_add_flattened_array_to_params( 'VolumeId', $param->{VolumeId} );
    $self->_amazon_add_flattened_array_to_params( 'Filter', $param->{Filter} );
    my $data = $self->send();

    # manipulate the volumeSet list we got back
    $data->{volumeSet} = $self->_make_array( $data->{volumeSet}{item} );
    $self->data( $data );
    return $self->data;
}

sub allocate_address {
    my ($self, $param) = @_;

    $self->set_command( 'AllocateAddress' );
    return $self->send();
}

sub describe_addresses {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeAddresses' );
    my $data = $self->send();

    # manipulate the addressesSet list we got back
    $data->{addressesSet} = $self->_make_array( $data->{addressesSet}{item} );
    $self->data( $data );
    return $self->data;
}

sub release_address {
    my ($self, $param) = @_;

    unless ( defined $param->{PublicIp} ) {
        croak "Provide a 'PublicIp' address to release";
    }

    $self->set_command( 'ReleaseAddress' );
    $self->set_param( 'PublicIp', $param->{PublicIp} );
    return $self->send();
}

sub describe_instances {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeInstances' );
    my $data = $self->send();

    # reservationSet
    $self->_fix_hash_to_array( $data->{reservationSet} );
    foreach my $reservation ( @{$data->{reservationSet}} ) {
        # groupSet
        $self->_fix_hash_to_array( $reservation->{groupSet} );

        # instancesSet
        $self->_fix_hash_to_array( $reservation->{instancesSet} );
        foreach my $instance ( @{$reservation->{instancesSet}} ) {
            # blockDeviceMapping
            $self->_fix_hash_to_array( $instance->{blockDeviceMapping} );
        }
    }

    return $self->data;
}

sub run_instances {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{ImageId}) ) {
        croak "Provide an 'ImageId' for the new instance";
    }
    unless ( $self->is_valid_integer($param->{MinCount}) ) {
        croak "Provide a valid 'MinCount' for the number of new instances";
    }
    unless ( $self->is_valid_integer($param->{MaxCount}) ) {
        croak "Provide a valid 'MaxCount' for the number of new instances";
    }

    $self->set_command( 'RunInstances' );
    $self->set_param( 'ImageId', $param->{ImageId} );
    $self->set_param( 'MinCount', $param->{MinCount} );
    $self->set_param( 'MaxCount', $param->{MaxCount} );
    $self->set_param( 'KeyName', $param->{KeyName} );
    $self->set_param( 'InstanceType', $param->{InstanceType} );
    return $self->send();
}

sub start_instances {
    my ($self, $param) = @_;

    $self->set_command( 'StartInstances' );
    $self->_amazon_add_flattened_array_to_params( 'InstanceId', $param->{InstanceId} );
    my $data = $self->send();

    # flatten {instancesSet}
    $data->{instancesSet} = $self->_make_array( $data->{instancesSet}{item} );
    return $self->data;
}

sub stop_instances {
    my ($self, $param) = @_;

    $self->set_command( 'StopInstances' );
    $self->_amazon_add_flattened_array_to_params( 'InstanceId', $param->{InstanceId} );
    my $data = $self->send();

    # flatten {instancesSet}
    $data->{instancesSet} = $self->_make_array( $data->{instancesSet}{item} );
    return $self->data;
}

sub terminate_instances {
    my ($self, $param) = @_;

    $self->set_command( 'TerminateInstances' );
    $self->_amazon_add_flattened_array_to_params( 'InstanceId', $param->{InstanceId} );
    my $data = $self->send();

    # flatten {instancesSet}
    $data->{instancesSet} = $self->_make_array( $data->{instancesSet}{item} );
    return $self->data;
}

sub create_key_pair {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{KeyName}) ) {
        croak "Provide a 'KeyName' for the new key pair";
    }

    $self->set_command( 'CreateKeyPair' );
    $self->set_param( 'KeyName', $param->{KeyName} );
    return $self->send();
}

sub delete_key_pair {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{KeyName}) ) {
        croak "Provide a 'KeyName' for the key pair to be deleted";
    }

    $self->set_command( 'DeleteKeyPair' );
    $self->set_param( 'KeyName', $param->{KeyName} );
    return $self->send();
}

sub describe_key_pairs {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeKeyPairs' );
    my $data = $self->send();

    # flatten {keySet}
    $data->{keySet} = $self->_make_array( $data->{keySet}{item} );

    return $self->data;
}

sub authorize_security_group_ingress {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{GroupName}) ) {
        croak "Provide a 'GroupName' to apply this authorization to ";
    }

    unless ( $self->is_valid_array( $param->{IpPermissions} ) ) {
        croak "Provide an 'IpPermissions' array to authorize";
    }

    $self->set_command( 'AuthorizeSecurityGroupIngress' );
    $self->set_param( 'GroupName', $param->{GroupName} );
    $self->_amazon_add_flattened_array_to_params( 'IpPermissions', $param->{IpPermissions} );
    return $self->send();
}

sub create_security_group {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{GroupName}) ) {
        croak "Provide a 'GroupName' for the new security group";
    }

    unless ( $self->is_valid_something($param->{GroupDescription}) ) {
        croak "Provide a 'GroupDescription' for the new security group";
    }

    $self->set_command( 'CreateSecurityGroup' );
    $self->set_param( 'GroupName', $param->{GroupName} );
    $self->set_param( 'GroupDescription', $param->{GroupDescription} );
    return $self->send();
}

sub delete_security_group {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{GroupName}) ) {
        croak "Provide a 'GroupName' to be deleted";
    }

    $self->set_command( 'DeleteSecurityGroup' );
    $self->set_param( 'GroupName', $param->{GroupName} );
    return $self->send();
}

sub describe_security_groups {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeSecurityGroups' );
    my $data = $self->send();

    # manipulate the securityGroupInfo list we got back
    $data->{securityGroupInfo} = $self->_make_array( $data->{securityGroupInfo}{item} );
    $self->data( $data );

    # flatten {ipPermissions}
    foreach my $info ( @{$data->{securityGroupInfo}} ) {
        $info->{ipPermissions} = $self->_make_array( $info->{ipPermissions}{item} );
        # flatten {groups} and {ipRanges}
        foreach my $ip ( @{$info->{ipPermissions}} ) {
            $ip->{groups} = $self->_make_array( $ip->{groups}{item} );
            $ip->{ipRanges} = $self->_make_array( $ip->{ipRanges}{item} );
        }
    }

    return $self->data;
}

sub revoke_security_group_ingress {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{GroupName}) ) {
        croak "Provide a 'GroupName' from which to revoke authorization";
    }

    unless ( $self->is_valid_array( $param->{IpPermissions} ) ) {
        croak "Provide an 'IpPermissions' array to revoke";
    }

    $self->set_command( 'RevokeSecurityGroupIngress' );
    $self->set_param( 'GroupName', $param->{GroupName} );
    $self->_amazon_add_flattened_array_to_params( 'IpPermissions', $param->{IpPermissions} );
    return $self->send();
}

## ----------------------------------------------------------------------------
# internal methods

sub _fix_hash_to_array {
    my ($self, $hash) = @_;

    print "self=$self, hash=$hash\n";

    croak "Trying to fix something that is not a hash" unless ref $hash eq 'HASH';
    croak "Trying to fix a hash which has more than one child" if keys %$hash > 1;

    # use $_[1] to change the 'actual' thing passed in
    if ( exists $hash->{item} ) {
        $_[1] = $self->_make_array( $hash->{item} );
    }
    else {
        $_[1] = [];
    }
    return;
}

sub _make_array {
    my ($self, $from) = @_;

    # return an empty list if not defined
    return [] unless defined $from;

    # return as-is if already an array
    return $from if ref $from eq 'ARRAY';

    # if this is a HASH, firstly check if there is anything in there
    if ( ref $from eq 'HASH' ) {
        # if nothing there, return an empty array
        return [] unless %$from;

        # just return the hash as the first element of an array
        return [ $from ];
    }

    # we probably have a scalar, so just return it as the first element of an array
    return [ $from ];
}

## ----------------------------------------------------------------------------
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
