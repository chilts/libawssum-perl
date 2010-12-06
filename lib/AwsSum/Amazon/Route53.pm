## ----------------------------------------------------------------------------

package AwsSum::Amazon::Route53;

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
# From: http://docs.amazonwebservices.com/Route53/latest/APIReference/
sub version { '2010-10-01' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # In order of: http://docs.amazonwebservices.com/Route53/latest/APIReference/

    # Actions on Hosted Zones
    # * POST CreateHostedZone
    # * POST CreateHostedZone
    # * GET GetHostedZone
    # * DELETE DeleteHostedZone
    ListHostedZones => {
        name   => 'ListHostedZones',
        method => 'list_hosted_zones',
        verb   => 'get',
    },

    # Actions on Resource Records Sets
    # * POST ChangeResourceRecordSets
    # * GET ListResourceRecordSets
    # * GET GetChange
};

sub _host {
    my ($self) = @_;
    # From: http://docs.amazonwebservices.com/Route53/latest/DeveloperGuide/DNSEndpoints.html
    return qq{route53.amazonaws.com};
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

sub verb {
    my ($self) = @_;
    return $self->_command->{verb};
}

sub url {
    my ($self) = @_;
    my $path = $self->version . q{/};

    my $name = $self->_command()->{name};
    if ( $name eq 'ListHostedZones' ) {
        $path .= q{hostedzone};
    }

    return q{https://} . $self->_host . q{/} . $path;
}

sub code { 200 }

sub sign {
    my ($self) = @_;

    # date needs to be in RFC1123 format
    my $date = DateTime->now( time_zone => 'UTC' )->strftime("%a, %d %b %Y %H:%M:%S %Z");

    # add the service params first before signing
    # From: http://docs.amazonwebservices.com/Route53/latest/APIReference/Headers.html
    $self->set_header( 'Date', $date );

    # From: http://docs.amazonwebservices.com/Route53/latest/DeveloperGuide/RESTAuthentication.html
    my $signature = ( $self->signature_method eq 'HmacSHA1' )
        ? hmac_sha1_base64($date, $self->secret_access_key )
        : hmac_sha256_base64($date, $self->secret_access_key );

    # set the 'X-Amzn-Authorization' header
    $self->set_header(
        q{X-Amzn-Authorization},
        qq{AWS3-HTTPS AWSAccessKeyId=} . $self->access_key_id . qq{,Algorithm=} . $self->signature_method . qq{,Signature=$signature=}
    );
}

sub decode {
    my ($self) = @_;

    # With Route52, we _always_ get some XML back no matter what happened.
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
            'error'   => $data->{Errors}{Error}{Code},
            'message' => $data->{Errors}{Error}{Message},
        }
    }

    # save it for the outside world
    $self->data( $data );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub list_hosted_zones {
    my ($self, $param) = @_;
    $self->clear();

    $self->set_command( 'ListHostedZones' );
    $self->set_params_if_defined(
        $param,
        qw(Marker MaxItems)
    );

    my $data = $self->send();
    # $self->_force_array( $data->{ListDomainsResult}{DomainName} );
    return $data;
}

## ----------------------------------------------------------------------------
# internal methods

sub _force_array {
    my $self = shift;
    $_[0] = $self->_make_array_from( $_[0] );
}

## ----------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable();
1;
## ----------------------------------------------------------------------------

=pod

=head1 NAME

AwsSum::Amazon::Route53 - interface to Amazon's Route53 web service

=head1 SYNOPSIS

    $r53 = AwsSum::Amazon::R53->new();
    $r53->access_key_id( 'abc' );
    $r53->secret_access_key( 'xyz' );

    # create a hosted zone
    my $zone = $r53->create_hosted_zone({
        Name    => 'example.com',
        Comment => 'This is my first zone.'
    });

    # list the resource record sets
    $r53->list_resource_record_sets({
        HostedZoneId => 'Z1PA6795UKMFR9',
    });

    # change a resource record set
    $r53->change_resource_record_set({
        HostedZoneId => 'Z1PA6795UKMFR9',
        Comment => q{Adding subdomain 'www' and changing subdomain 'foo'.},
        Changes => [
            {
                Action => 'CREATE',
                Name   => 'www.example.com.',
                Type   => 'A', # A, AAAA, CNAME, MX, NS, PTR, SOA, SPF, SRV, TXT
                TTL    => 300,
                ResourceRecords => [
                    '192.0.2.1',
                ],
            },
            {
                Action => 'DELETE',
                Name   => 'foo.example.com.',
                Type   => 'A',
                TTL    => 600,
                ResourceRecords => [
                    '192.0.2.3',
                ],
            },
            {
                Action => 'CREATE',
                Name   => 'foo.example.com.',
                Type   => 'A',
                TTL    => 600,
                ResourceRecords => [
                    '192.0.2.1',
                ],
            },
        ],
    });

=cut
