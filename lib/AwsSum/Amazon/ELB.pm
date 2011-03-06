## ----------------------------------------------------------------------------

package AwsSum::Amazon::ELB;

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
sub version { '2010-07-01' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # In order of: http://docs.amazonwebservices.com/ElasticLoadBalancing/latest/DeveloperGuide/CHAP_LoadBalancing_OpListAlphabetical.html

    # Creation and Deletion Actions:
    # * CreateLoadBalancer
    # * DeleteLoadBalancer
    # * CreateLoadBalancerListeners
    # * DeleteLoadBalancerListeners

    # Registration and Configuration Actions:
    # * RegisterInstancesWithLoadBalancer
    # * SetLoadBalancerListenerSSLCertificate
    # * DeregisterInstancesFromLoadBalancer

    # Descriptive Actions (LoadBalancers):
    # * DescribeLoadBalancers
    # * DescribeInstanceHealth

    # Availability Zone Actions:
    # * EnableAvailabilityZonesForLoadBalancer
    # * DisableAvailabilityZonesForLoadBalancer

    # Healthcheck Actions:
    # * ConfigureHealthCheck

    # Sticky Session Actions:
    # * CreateAppCookieStickinessPolicy
    # * CreateLBCookieStickinessPolicy
    # * SetLoadBalancerPoliciesOfListener
    # * DeleteLoadBalancerPolicy

    # Descriptive Actions (LoadBalancers)
    DescribeLoadBalancers => {
        name => 'DescribeLoadBalancers',
        method => 'describe_load_balancers',
    },
};

sub _host {
    my ($self) = @_;
    return q{elasticloadbalancing.} . $self->region . q{.amazonaws.com};
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

    # From: http://docs.amazonwebservices.com/ElasticLoadBalancing/latest/DeveloperGuide/Using_Query_API.html
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

    # See: http://docs.amazonwebservices.com/ElasticLoadBalancing/latest/DeveloperGuide/Using_Query_API.html#query-authentication

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

    # With ELB, we _always_ get some XML back no matter what happened.
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

sub describe_load_balancers {
    my ($self, $param) = @_;

    $self->set_command( 'DescribeLoadBalancers' );
    $self->region( $param->{Region} ) if $param->{Region};
    my $data = $self->send();

    $data->{DescribeLoadBalancersResult} = $self->_make_array_from( $data->{DescribeLoadBalancersResult} );

    return $data;
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

AwsSum::Amazon::ELB - interface to Amazon's ElasticLoadBalancing web service

=head1 SYNOPSIS

    $elb = AwsSum::Amazon::ELB->new();
    $elb->access_key_id( 'abc' );
    $elb->secret_access_key( 'xyz' );

    # ToDo

=cut
