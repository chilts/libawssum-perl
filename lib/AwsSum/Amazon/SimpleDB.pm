## ----------------------------------------------------------------------------

package AwsSum::Amazon::SimpleDB;

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
# From: http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/DocumentHistory.html
sub version { '2009-04-15' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # In order of: http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/SDB_API_Operations.html

    # BatchPutAttributes
    # CreateDomain
    # DeleteAttributes
    # DeleteDomain
    # DomainMetadata
    # GetAttributes
    ListDomains => {
        name           => 'ListDomains',
        method         => 'list_domains',
    },
    # PutAttributes
    # Select
};

sub _host {
    my ($self) = @_;
    return $self->region eq 'us-east-1'
        ? q{sdb.amazonaws.com}
        : q{sdb.} . $self->region . q{.amazonaws.com}
    ;
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

sub verb { 'get' }

sub url {
    my ($self) = @_;
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

    # See: http://docs.amazonwebservices.com/AmazonSimpleDB/latest/DeveloperGuide/HMACAuth.html

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

    # With SimpleDB, we _always_ get some XML back no matter what happened.
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

sub list_domains {
    my ($self, $param) = @_;
    $self->clear();

    $self->set_command( 'ListDomains' );
    $self->set_params_if_defined(
        $param,
        qw(MaxNumberOfDomains NextToken)
    );

    my $data = $self->send();
    $self->_force_array( $data->{ListDomainsResult}{DomainName} );
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
