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
        # DescribeImages => {},
        # ModifyImageAttribute => {},
        DescribeAvailabilityZones => {},
        DescribeRegions => {},
        # AttachVolume => {},
        # CreateSnapshot => {},
        # CreateVolume => {},
        # DeleteSnapshot => {},
        # DeleteVolume => {},
        # DescribeSnapshotAttribute => {},
        # DescribeSnapshots => {},
        # DescribeVolumes => {},
        # DetachVolume => {},
        # ModifySnapshotAttribute => {},
        # ResetSnapshotAttribute => {},
        AllocateAddress => {},
        # AssociateAddress => {},
        DescribeAddresses => {},
        # DisassociateAddress => {},
        ReleaseAddress => {
            opts => [ qw(PublicIp) ],
        },
        # GetConsoleOutput => {},
        # RegisterImage => {},
        # ResetImageAttribute => {},
        # DescribeInstanceAttribute => {},
        # DescribeInstances => {},
        # ModifyInstanceAttribute => {},
        # RebootInstances => {},
        # ResetInstanceAttribute => {},
        # RunInstances => {},
        # StartInstances => {},
        # StopInstances => {},
        # TerminateInstances => {},
        # CreateKeyPair => {},
        # DeleteKeyPair => {},
        # DescribeKeyPairs => {},
        # ImportKeyPair => {},
        # MonitorInstances => {},
        # UnmonitorInstances => {},
        # CreatePlacementGroup => {},
        # DeletePlacementGroup => {},
        # DescribePlacementGroups => {},
        # DescribeReservedInstances => {},
        # DescribeReservedInstancesOfferings => {},
        # PurchaseReservedInstancesOffering => {},
        AuthorizeSecurityGroupIngress => {
            opts => [ qw(GroupName) ],
            lists => [ 'IpPermissions.#.IpProtocol', 'IpPermissions.#.FromPort', 'IpPermissions.#.ToPort' ],
        },
        CreateSecurityGroup => {
            opts => [ qw(GroupName GroupDescription) ],
        },
        DeleteSecurityGroup => {
            opts => [ qw(GroupName) ],
        },
        DescribeSecurityGroups => {},
        RevokeSecurityGroupIngress => {
            opts => [ qw(GroupName) ],
            lists => {
                IpPermissions => {
                    IpProtocol => 1,
                    FromPort => 1,
                    ToPort => 1,
                },
            },
        },
        # CancelSpotInstanceRequests => {},
        # CreateSpotDatafeedSubscription => {},
        # DeleteSpotDatafeedSubscription => {},
        # DescribeSpotDatafeedSubscription => {},
        # DescribeSpotInstanceRequests => {},
        # DescribeSpotPriceHistory => {},
        # RequestSpotInstances => {},
        # CreateTags => {},
        # DeleteTags => {},
        # DescribeTags => {},
        # BundleInstance => {},
        # CancelBundleTask => {},
        # DescribeBundleTasks => {},
        # GetPasswordData => {},
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

    # make sure there is something in each of these
    $input->{$service}{$command}{opts} ||= [];
    $input->{$service}{$command}{bools} ||= {};
    $input->{$service}{$command}{lists} ||= {};

    # save them locally so it's easier
    my $opts = { map { $_ => 1 } @{$input->{$service}{$command}{opts}} };
    my $bools = $input->{$service}{$command}{bools};
    my $lists = $input->{$service}{$command}{lists};

    # this is the dumping ground for what we find, either $args or the $rest
    my $args = {};
    my $rest = [];

    # start looping through the args
    while ( @args ) {
        # get the next one off the list
        my $this = shift @args;

        if ( $this =~ m{ \A -- ([\w\.]*) \z }xms ) {
            # save this parameter name
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
                # looks like an option, but we don't know about it
                print STDERR "Warning: Unknown option '$this'\n";
            }
        }
        else {
            # this doesn't look like an option, so save it as the $rest
            push @$rest, $this;
        }
    }
    return $args;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
