## ----------------------------------------------------------------------------

package AwsSum::Amazon::CloudFront;

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
use String::Random qw(random_string);

## ----------------------------------------------------------------------------
# setup details needed or pre-determined

# some things required from the user
enum 'SignatureMethod' => qw(HmacSHA1 HmacSHA256);
has 'signature_method'   => ( is => 'rw', isa => 'SignatureMethod', default => 'HmacSHA256' );

# which distribution we are working on
has '_distribution_id' => ( is => 'rw', isa => 'Str' );

# constants
# Version: http://docs.amazonwebservices.com/AmazonCloudFront/latest/APIReference/APIVersion.html
sub version { '2010-11-01' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # Actions on Distributions
    CreateDistribution => {
        name     => 'CreateDistribution',
        amz_name => 'POST Distribution',
        method   => 'create_distribution',
        verb     => 'post',
        code     => 201,
    },
    GetDistributionList => {
        name     => 'GetDistributionList',
        amz_name => 'GET Distribution List',
        method   => 'get_distribution_list',
        verb     => 'get',
        code     => 200,
    },
    GetDistribution => {
        name     => 'GetDistribution',
        amz_name => 'GET Distribution',
        method   => 'get_distribution',
        verb     => 'get',
        code     => 200,
    },
    # * GET Distribution
    # * GET Distribution Config
    # * PUT Distribution Config
    # * DELETE Distribution

    # Actions on Streaming Distributions
    # * POST Streaming Distribution
    # * GET Streaming Distribution List
    # * GET Streaming Distribution
    # * GET Streaming Distribution Config
    # * PUT Streaming Distribution Config
    # * DELETE Streaming Distribution

    # Actions on Origin Access Identities
    # * POST Origin Access Identity
    # * GET Origin Access Identity List
    # * GET Origin Access Identity
    # * GET Origin Access Identity Config
    # * PUT Origin Access Identity Config
    # * DELETE Origin Access Identity

    # Actions on Invalidations
    # * POST Invalidation
    # * GET Invalidation List
    # * GET Invalidation
};

sub _host {
    my ($self) = @_;
    return q{cloudfront.amazonaws.com};
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

sub verb {
    my ($self) = @_;
    return $self->_command->{verb};
}

sub url {
    my ($self) = @_;

    # From: http://docs.amazonwebservices.com/AmazonCloudFront/latest/DeveloperGuide/CFEndpoints.html
    my $url = q{https://} . $self->_host . q{/} . $self->version;

    my $command = $self->_command()->{name};
    if ( $command eq 'GetDistributionList' ) {
        $url .= q{/distribution};
    }
    elsif ( $command eq 'GetDistribution' ) {
        $url .= q{/distribution/} . $self->_distribution_id();
    }

    return $url
}

sub code {
    my ($self) = @_;
    return $self->_command->{code};
}

sub sign {
    my ($self) = @_;

    # Add the Common REST Headers, see: http://docs.amazonwebservices.com/AmazonCloudFront/latest/APIReference/Headers.html
    my $date = DateTime->now( time_zone => 'UTC' )->strftime("%a, %d %b %Y %H:%M:%S %z");
    $self->set_header( q{Date}, $date );

    # Sign the request, see: http://docs.amazonwebservices.com/AmazonCloudFront/latest/DeveloperGuide/RESTAuthentication.html
    my $str_to_sign = $date;

    # sign the request (remember this is SignatureVersion '2')
    # sign the $str_to_sign
    my $signature = hmac_sha1_base64($str_to_sign, $self->secret_access_key );
    $self->set_header( q{Authorization}, q{AWS } . $self->access_key_id() . qq{:$signature=} );
}

sub decode {
    my ($self) = @_;

    # With SQS, we _always_ get some XML back no matter what happened.
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

sub create_distribution {
    my ($self, $param) = @_;

    # see if we have an S3Origin or a CustomOrigin (must have one of them)
    unless ( defined $param->{S3Origin} or defined $param->{CustomOrigin} ) {
        croak "Provide either a 'S3Origin' or a 'CustomOrigin' as this distributions origin";
    }
    if ( defined $param->{S3Origin} and defined $param->{CustomOrigin} ) {
        croak "Provide only one of 'S3Origin' or 'CustomOrigin', not both";
    }

    # we need a DNSName for distributions of either type
    unless ( defined $param->{DNSName} ) {
        croak "Provide a 'DNSName' when creating a distribution";
    }

    # check the details of a CustomOrigin
    if ( defined $param->{CustomOrigin} ) {
        unless ( defined $param->{OriginProtocolPolicy} ) {
            croak "Provide a 'OriginProtocolPolicy' when creating a CustomOrigin distribution";
        }
    }

    # make a CallerReference if we don't have one
    $param->{CallerReference} ||= random_string( q{s} x 16 );

    # check we have 'Enabled' given
    unless ( defined $param->{Enabled} ) {
        croak "Provide 'Enabled' when creating a distribution (false|true)";
    }
    unless ( $self->is_valid_boolean_string($param->{Enabled}) ) {
        croak "Provide a valid 'Enabled' boolean (false|true)";
    }

    my $xml = <<'EOF';
<DistributionConfig xmlns="http://cloudfront.amazonaws.com/doc/2010-11-01/">
   <S3Origin>
      <DNSName/>
      <OriginAccessIdentity/>
   </S3Origin>
   <CallerReference/>
   <CNAME/>
   <Comment/>
   <Enabled/>
   <DefaultRootObject>index.html</DefaultRootObject>
   <Logging>
      <Bucket/>
      <Prefix/>
   </Logging>
   <TrustedSigners>
      <Self/>
      <AwsAccountNumber/>
   </TrustedSigners>
   <RequiredProtocols>
      <Protocol>https</Protocol>
   </RequiredProtocols>
</DistributionConfig>
EOF

    # create some XML (wow, this is going to be boring, painful and lame)
    my $doc = $self->_make_root_element( q{DistributionConfig} );

    if ( defined $param->{S3Origin} ) {
        my $s3origin = $doc->add_element( q{S3Origin} );
    }

    # set up and send the request
    $self->set_command( q{CreateBucket} );
    $self->content( $doc->as_string() );
    return $self->send();
}

sub get_distribution_list {
    my ($self, $param) = @_;

    # set up and send the request
    $self->set_command( q{GetDistributionList} );
    $self->set_param_maybe( q{Marker}, $param->{Market} );
    $self->set_param_maybe( q{MaxItems}, $param->{MaxItems} );

    my $data = $self->send();
    $self->_fix_hash_to_array( $data->{DistributionSummary} );
    return $data;
}

sub get_distribution {
    my ($self, $param) = @_;

    # set up and send the request
    $self->set_command( q{GetDistribution} );

    # check we have a distribution id
    unless ( $self->is_valid_something($param->{DistributionId}) ) {
        croak q{Provide a 'DistributionId' to be queried};
    }
    $self->_distribution_id( $param->{DistributionId} );

    my $data = $self->send();
    # $self->_fix_hash_to_array( $data->{DistributionSummary} );
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

AwsSum::Amazon::CloudFront - interface to Amazon's CloudFront web service

=head1 SYNOPSIS

    $ec2 = AwsSum::Amazon::CloudFront->new();
    $ec2->access_key_id( 'abc' );
    $ec2->secret_access_key( 'xyz' );

=cut
