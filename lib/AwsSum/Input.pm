## ----------------------------------------------------------------------------

package AwsSum::Input;

use strict;
use warnings;

## ----------------------------------------------------------------------------
# constants

# This hash has 3 levels:
# 1) Service
# 2) Command
# 3) Options (opts, bools and lists). Each of these may be missing.

my $input = {

    'Amazon:EC2' => {
        # ConfirmProductInstance => {},
        # CreateImage => {},
        # DeregisterImage => {},
        # DescribeImageAttribute => {},
        DescribeImages => {
            list => {
                ImageId => 1,
            },
        },
        # ModifyImageAttribute => {},
        DescribeAvailabilityZones => {
            opts => [ qw(Region) ],
        },
        DescribeRegions => {},
        # AttachVolume => {},
        # CreateSnapshot => {},
        # CreateVolume => {},
        # DeleteSnapshot => {},
        DeleteVolume => {
            opts => [ qw(VolumeId Region) ],
        },
        # DescribeSnapshotAttribute => {},
        # DescribeSnapshots => {},
        DescribeVolumes => {
            opts => [ qw(Region) ],
            list => {
                VolumeId => qr{ \A VolumeId\. \z }xmsm,
                Filter => qr{ \A Filter\. \z }xmsm,
            },
        },
        # DetachVolume => {},
        # ModifySnapshotAttribute => {},
        # ResetSnapshotAttribute => {},
        AllocateAddress => {
            opts => [ qw(Region) ],
        },
        AssociateAddress => {
            opts => [ qw(PublicIp InstanceId Region) ],
        },
        DescribeAddresses => {
            opts => [ qw(Region) ],
        },
        DisassociateAddress => {
            opts => [ qw(PublicIp) ],
        },
        ReleaseAddress => {
            opts => [ qw(PublicIp Region) ],
        },
        # GetConsoleOutput => {},
        # RegisterImage => {},
        # ResetImageAttribute => {},
        DescribeInstanceAttribute => {
            opts => [ qw(InstanceId Attribute Region) ],
        },
        DescribeInstances => {
            opts => [ qw(Region) ],
            list => {
                InstanceId => 1,
            },
        },
        ModifyInstanceAttribute => {
            opts => [ qw(InstanceId Attribute Value Region) ],
        },
        RebootInstances => {
            opts => [ qw(Region) ],
            list => {
                InstanceId => 1,
            },
        },
        # ResetInstanceAttribute => {},
        RunInstances => {
            opts => [ qw(Region ImageId MinCount MaxCount KeyName InstanceType DisableApiTermination InstanceInitiatedShutdownBehavior) ],
            list => {
                SecurityGroup => 1,
                BlockDeviceMapping => 1,
            },
            hash => {
                Placement  => 1,
                Monitoring => 1,
            },
        },
        StartInstances => {
            opts => [ qw(Region) ],
            list => {
                InstanceId => 1,
            },
        },
        StopInstances => {
            opts => [ qw(Force Region) ],
            list => {
                InstanceId => 1,
            },
        },
        TerminateInstances => {
            opts => [ qw(Region) ],
            list => {
                InstanceId => 1,
            },
        },
        CreateKeyPair => {
            opts => [ qw(KeyName Region) ],
        },
        DeleteKeyPair => {
            opts => [ qw(KeyName Region) ],
        },
        DescribeKeyPairs => {
            opts => [ qw(KeyName Region) ],
            list => {
                KeyName => 1,
                Filter => 1,
            },
        },
        ImportKeyPair => {
            opts => [ qw(KeyName PublicKeyMaterial Region) ],
        },
        # MonitorInstances => {},
        # UnmonitorInstances => {},
        # CreatePlacementGroup => {},
        # DeletePlacementGroup => {},
        # DescribePlacementGroups => {},
        DescribeReservedInstances => {
            opts => [ qw(Region) ],
            list => {
                ReservedInstancesId => 1,
            },
        },
        DescribeReservedInstancesOfferings => {
            opts => [ qw(InstanceType AvailabilityZone ProductDescription Region) ],
            list => {
                ReservedInstancesOfferingId => 1,
                Filter => 1,
            },
        },
        PurchaseReservedInstancesOffering => {
            opts => [ qw(Region) ],
            list => {
                ReservedInstancesOfferingId => 1,
                InstanceCount => 1,
            },
        },
        AuthorizeSecurityGroupIngress => {
            opts => [ qw(GroupName Region) ],
            list => {
                IpPermissions => qr{ \A IpPermissions\. \z }xmsm,
            },
        },
        CreateSecurityGroup => {
            opts => [ qw(GroupName GroupDescription Region) ],
        },
        DeleteSecurityGroup => {
            opts => [ qw(GroupName Region) ],
        },
        DescribeSecurityGroups => {
            opts => [ qw(Region) ],
            list => {
                GroupName => 1,
            },
        },
        RevokeSecurityGroupIngress => {
            opts => [ qw(GroupName Region) ],
            list => {
                IpPermissions => qr{ \A IpPermissions\. \z }xms,
            },
        },
        # CancelSpotInstanceRequests => {},
        # CreateSpotDatafeedSubscription => {},
        # DeleteSpotDatafeedSubscription => {},
        # DescribeSpotDatafeedSubscription => {},
        # DescribeSpotInstanceRequests => {},
        # DescribeSpotPriceHistory => {},
        # RequestSpotInstances => {},
        CreateTags => {
            list => {
                ResourceId => 1,
                Tag => 1,
            },
        },
        DeleteTags => {
            list => {
                ResourceId => 1,
                Tag => 1,
            },
        },
        DescribeTags => {
            list => {
                Filter => 1,
            },
        },
        # BundleInstance => {},
        # CancelBundleTask => {},
        # DescribeBundleTasks => {},
        # GetPasswordData => {},
    },

    'Amazon:S3' => {
        # Operations on the Service
        ListBuckets => {},
        # Operations on Buckets
        CreateBucket => {
            opts => [ qw(BucketName) ],
        },
        # Operations on Objects
    },

    PayPal => {
        GetBalance => {
            bools => {
                'RETURNALLCURRENCIES' => 1,
            },
        },
        TransactionSearch => {
            opts => [ qw(STARTDATE) ],
        },
        GetTransactionDetails => {
            opts => [ qw(TRANSACTIONID) ],
        },
    },

    Flickr => {
        'test.echo' => {},
        'test.null' => {},
        'auth.checkToken' => {},
    },

    'RackspaceCloud:Authenticate' => {
        authenticate => {},
    },

    'RackspaceCloud:CloudServers' => {
        apiVersions => {},
        apiVersionDetails => {
            opts => [ qw(apiVersionId) ],
        },
        limits => {},
        listServers => {},
        listServersDetail => {},
        getServerDetails => {
            opts => [ qw(serverId) ],
        },
        listFlavors => {},
        listFlavorsDetail => {},
        getFlavorDetails => {
            opts => [ qw(flavorId) ],
        },
        listImages => {},
        listImagesDetail => {},
        getImageDetails => {
            opts => [ qw(imageId) ],
        },
        createServer => {
            opts => [ qw(name imageId flavorId) ],
        },
    },

};

## ----------------------------------------------------------------------------
# class methods

sub get_inputs_for {
    my ($class, $service, $command) = @_;
    return $input->{$service}{$command};
}

sub process_args {
    my ($class, $service, $command, @args) = @_;

    # if this command doesn't exist, then we should just return empty args
    return {} unless exists $input->{$service}{$command};

    # make sure there is something in each of these first
    $input->{$service}{$command}{opts} ||= [];
    $input->{$service}{$command}{bools} ||= {};
    $input->{$service}{$command}{list} ||= {};

    # save them locally so it's easier
    my $opts = { map { $_ => 1 } @{$input->{$service}{$command}{opts}} };
    my $bools = $input->{$service}{$command}{bools};
    my $hash = $input->{$service}{$command}{hash};
    my $list = $input->{$service}{$command}{list};

    # this is the dumping ground for what we find, either $args or the $rest
    my $args = {};
    my $rest = [];

    # start looping through the args
    while ( @args ) {
        # get the next one off the list
        my $this = shift @args;

        # if this doesn't look like a param, save it in @$rest
        if ( $this !~ m{ \A -- ([\w\.]*) \z }xms ) {
            push @$rest, $this;
            next;
        }

        # remember this param name this parameter name
        my $param = $1;

        # see if this might be a bool
        if ( exists $bools->{$param} ) {
            # yep, so save as a bool
            $args->{$param} = 1;
        }
        elsif ( exists $opts->{$param} ) {
            # an option, so save the next item too
            $args->{$param} = shift @args;
        }
        else {
            # see if this is a list or hash of some sort
            # Note: do the \d ones before \w (at the same level) since \d is wholly contained in \w
            if ( $param =~ m{ \A (\w+)\.(\d+) \z }xms and exists $list->{$1} ) {
                # e.g. --SecurityGroup.n
                $args->{$1}[$2] = shift @args;
            }
            elsif ( $param =~ m{ \A (\w+)\.(\w+) \z }xms and exists $hash->{$1} ) {
                # e.g. --LaunchSpecification.ImageId
                $args->{$1}{$2} = shift @args;
            }
            elsif ( $param =~ m{ \A (\w+)\.(\d+)\.(\w+) \z }xms and exists $list->{$1} ) {
                # e.g. --BlockDeviceMapping.n.DeviceName
                $args->{$1}[$2]{$3} = shift @args;
            }
            elsif ( $param =~ m{ \A (\w+)\.(\w+)\.(\w+) \z }xms and exists $hash->{$1} ) {
                # e.g. --LaunchSpecification.Placement.AvailabilityZone
                $args->{$1}{$2}{$3} = shift @args;
            }
            elsif ( $param =~ m{ \A (\w+)\.(\d+)\.(\w+)\.(\d+) \z }xms and exists $list->{$1} ) {
                # e.g. --Filter.n.Value.m
                $args->{$1}[$2]{$3}[$4] = shift @args;
            }
            elsif ( $param =~ m{ \A (\w+)\.(\w+)\.(\d+)\.(\w+) \z }xms and exists $hash->{$1} ) {
                # e.g. --LaunchSpecification.blockDeviceMapping.n.DeviceName
                $args->{$1}{$2}[$3]{$4} = shift @args;
            }
            elsif ( $param =~ m{ \A (\w+)\.(\d+)\.(\w+)\.(\w+) \z }xms and exists $list->{$1} ) {
                # e.g. --BlockDeviceMapping.n.Ebs.DeleteOnTermination
                print "HERE 1=$1, 2=$2, 3=$3, 4=$4\n";
                $args->{$1}[$2]{$3}{$4} = shift @args;
            }
            elsif ( $param =~ m{ \A (\w+)\.(\d+)\.(\w+)\.(\d+)\.(\w+) \z }xms and exists $list->{$1} ) {
                # e.g. --IpPermissions.n.Groups.m.GroupName
                $args->{$1}[$2]{$3}[$4]{$5} = shift @args;
            }
            else {
                # looks like an option, but we don't know about it
                print STDERR "Warning: Unknown option '$this'\n";
            }
        }
    }
    return $args;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
