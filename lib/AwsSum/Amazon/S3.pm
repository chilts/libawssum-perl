## ----------------------------------------------------------------------------

package AwsSum::Amazon::S3;

use Moose;
with 'AwsSum::Service';
with qw(
    AwsSum::Service
    AwsSum::Amazon::Service
);

use Carp;
use Digest::SHA qw (hmac_sha1_base64);
use HTTP::Date;
use XML::Simple;

## ----------------------------------------------------------------------------
# we require these things off the using code

# some things required from the user
has 'access_key_id'     => ( is => 'rw', isa => 'Str' );
has 'secret_access_key' => ( is => 'rw', isa => 'Str' );

# which bucket/object are we working on (can be set on the service as a
# default, or each command will just get it from $params->{BucketName} or
# $params->{ObjectName}
has '_bucket_name' => ( is => 'rw', isa => 'Str' );
has '_object_name' => ( is => 'rw', isa => 'Str' );

# constants
sub version { '' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------
# constants

my $commands = {
    'ListBuckets' => {
        name           => 'ListBuckets',
        method         => 'list_buckets',
        verb           => 'get',
        code           => 200,
    },
    'CreateBucket' => {
        name           => 'CreateBucket',
        method         => 'create_bucket',
        verb           => 'put',
        code           => 200,
    },
};

my $allowed = {
    'bucket_acl' => {
        'private' => 1,
        'public-read' => 1,,
        'public-read-write' => 1,
        'authenticated-read' => 1,
        'bucket-owner-read' => 1,
        'bucket-owner-full-control' => 1,
    },
};

## ----------------------------------------------------------------------------
# things to fill in to fulfill AwsSum::Service

sub commands { $commands }

sub verb {
    my ($self) = @_;
    return $self->_command->{verb};
}

sub url {
    my ($self) = @_;

    my $url;

    # firstly, create the URL (add bucket if not ListBuckets)
    $url = $self->s3_host( $self->region );
    $url = $self->_bucket_name . '.' . $url
        unless $self->_command->{name} eq 'ListBuckets';
    $url = "https://$url/";

    # add the object_name
    $url .= $self->_object_name()
        if $self->_object_name();

    return $url;
}

sub host {
    my ($self) = @_;
    die "ToDo: host()";
    return q{ec2.} . $self->region . q{.amazonaws.com};
}

sub code { 200 }

sub sign {
    my ($self) = @_;

    # add the service params first before signing
    $self->set_header( 'Date', time2str(time) );

    # See: http://docs.amazonwebservices.com/AmazonS3/latest/dev/RESTAuthentication.html

    my $header = $self->headers;
    my $param = $self->params;

    # start creating the string we need to sign
    my $str_to_sign = '';
    $str_to_sign .= uc($self->verb) . "\n";

    # add the following headers (if available)
    foreach my $hdr ( qw(Content-MD5 Content-Type Date) ) {
        if ( exists $header->{$hdr} ) {
            $str_to_sign .= $header->{$hdr};
        }
        $str_to_sign .= "\n";
    }

    # add the CanonicalizedAmzHeaders
    my @amz_headers = sort grep { /^x-amz-/ } map { lc } keys %$header;
    foreach my $header ( @amz_headers ) {
        $str_to_sign .= $header . ':';
        my $header_value;
        if ( ref $header->{$header} eq 'ARRAY' ) {
            # combine
            $header_value = join(',', map { trim($_) } @{$header->{$header}});
        }
        else {
            $header_value = $header->{$header};
        }
        # unfold long headers before adding
        $header_value =~ s{ \s+ }{ }gxms;
        $str_to_sign .= $header_value . "\n";
    }

    # add the CanonicalizedResource
    $str_to_sign .= '/';
    if ( $self->_bucket_name ) {
        $str_to_sign .= $self->_bucket_name . '/';
    }
    if ( exists $param->{ObjectName} ) {
        # this should be URI Escaped, but the new URI::Escape is too aggressive
        # since it encodes '/' into '%2F' which is not required
        $str_to_sign .= $self->key;
    }
    # ToDo: fix this to the new way of doing things
    #if ( $self->sub_resource ) {
    #    $str_to_sign .= '?' . $self->sub_resource;
    #}

    # finally, set the 'Authorization' header
    my $digest = hmac_sha1_base64( $str_to_sign, $self->secret_access_key );
    $self->set_header( 'Authorization', "AWS " . $self->access_key_id . ':' . $digest . '=' );
}

sub decode {
    my ($self) = @_;

    $self->data( XMLin( $self->res->content() ));
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub list_buckets {
    my ($self, $params) = @_;

    $self->set_command( 'ListBuckets' );

    my $data = $self->send();

    # fix this array
    $data->{Buckets} = $self->_make_array_from( $data->{Buckets}{Bucket} );
}

sub create_bucket {
    my ($self, $params) = @_;

    unless ( defined $params->{BucketName} ) {
        croak "Provide a 'BucketName' to create";
    }

    $params->{LocationConstraint} ||= 'us-east-1';
    unless ( $self->is_valid_region($params->{LocationConstraint}) ) {
        croak "Provide a valid 'LocationConstraint' to create the bucket in";
    }

    $self->set_command( 'CreateBucket' );
    $self->_bucket_name( $params->{BucketName} );

    # set the location constraint, but not if it is the normal region
    my $loc_value = $self->s3_location_constraint( $params->{LocationConstraint} );
    if ( $loc_value ) {
        $self->content( "<CreateBucketConfiguration><LocationConstraint>$loc_value</LocationConstraint></CreateBucketConfiguration>" );
    }

    return $self->send();
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
