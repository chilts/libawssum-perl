## ----------------------------------------------------------------------------

package AwsSum::Amazon::S3;

use Moose;
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
has '_sub_resource' => ( is => 'rw', isa => 'Str' );

# constants
sub version { '' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------
# constants

my $commands = {
    # Operations on the Service
    ListBuckets => {
        name           => 'ListBuckets',
        amz_name       => 'GET Service',
        method         => 'list_buckets',
        verb           => 'get',
        code           => 200,
    },

    # Operations on Buckets
    DeleteBucket => {
        name           => 'DeleteBucket',
        amz_name       => 'DELETE Bucket',
        method         => 'delete_bucket',
        verb           => 'delete',
        code           => 204,
    },
    # * DELETE Bucket policy

    ListObjects => {
        name           => 'ListObjects',
        amz_name       => 'GET Bucket (List Objects)',
        method         => 'list_objects',
        verb           => 'get',
        code           => 200,
    },

    # * GET Bucket acl
    # * GET Bucket policy
    # * GET Bucket location
    # * GET Bucket logging
    # * GET Bucket notification
    # * GET Bucket Object versions
    # * GET Bucket requestPayment

    DescribeBucketVersioning => {
        name           => 'DescribeBucketVersioning',
        amz_name       => 'GET Bucket versioning',
        method         => 'describe_bucket_versioning',
        verb           => 'get',
        code           => 200,
    },

    CreateBucket => {
        name           => 'CreateBucket',
        amz_name       => 'PUT Bucket',
        method         => 'create_bucket',
        verb           => 'put',
        code           => 200,
    },

    # * PUT Bucket acl
    # * PUT Bucket policy

    ModifyBucketLogging => {
        name           => 'ModifyBucketLogging',
        amz_name       => 'PUT Bucket logging',
        method         => 'modify_bucket_logging',
        verb           => 'put',
        code           => 200,
    },

    # * PUT Bucket notification
    # * PUT Bucket requestPayment
    # * PUT Bucket versioning

    # Operations on Objects
    DeleteObject => {
        name           => 'DeleteObject',
        amz_name       => 'DELETE Object',
        method         => 'delete_object',
        verb           => 'delete',
        code           => 204,
    },

    GetObject => {
        name           => 'GetObject',
        amz_name       => 'GET Object',
        method         => 'get_object',
        verb           => 'get',
        code           => 200,
        has_content    => 1,
    },
    # * GET Object acl
    # * GET Object torrent
    # * HEAD Object
    # * POST Object

    CreateObject => {
        name           => 'CreateObject',
        amz_name       => 'PUT Object',
        method         => 'create_object',
        verb           => 'put',
        code           => 200,
    },

    # * PUT Object acl
    # * PUT Object (Copy)
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

my $service_info = {
    'us-east-1' => {
        'endpoint'            => 'https://s3.amazonaws.com',
        'host'                => 's3.amazonaws.com',
        'location-constraint' => undef, # no such thing
    },
    'us-west-1' => {
        'endpoint'            => 'https://s3-us-west-1.amazonaws.com',
        'host'                => 's3-us-west-1.amazonaws.com',
        'location-constraint' => 'us-west-1',
    },
    'eu-west-1' => {
        'endpoint'            => 'https://s3-eu-west-1.amazonaws.com',
        'host'                => 's3-eu-west-1.amazonaws.com',
        'location-constraint' => 'EU',
    },
    'ap-southeast-1' => {
        'endpoint'            => 'https://s3-ap-southeast-1.amazonaws.com',
        'host'                => 's3-ap-southeast-1.amazonaws.com',
        'location-constraint' => 'ap-southeast-1',
    },
    'ap-northeast-1' => {
        'endpoint'            => 'https://s3-ap-northeast-1.amazonaws.com',
        'host'                => 's3-ap-northeast-1.amazonaws.com',
        'location-constraint' => 'ap-northeast-1',
    },
};

sub _host {
    my ($self) = @_;

    # start with the "BucketName." (for everything except ListBuckets)
    my $host = $self->_bucket_name . '.'
        unless $self->_command->{name} eq 'ListBuckets';

    # add the region host
    $host .= $service_info->{$self->region}{host};

    return $host;
}

sub _location_constraint {
    my ($self) = @_;
    return $service_info->{$self->region}{'location-constraint'};
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

    # make the base url
    my $url = q{https://} . $self->_host() . q{/};

    # add the object_name if there is one
    $url .= $self->_object_name()
        if $self->_object_name();

    # if we have a sub resource, add that on
    $url .= q{?} . $self->_sub_resource
        if $self->_sub_resource;

    return $url;
}

sub code {
    my ($self) = @_;
    return $self->_command->{code};
}

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

    # add the CanonicalizedResource (bucket, path and sub-resource)
    $str_to_sign .= '/';
    if ( $self->_bucket_name ) {
        $str_to_sign .= $self->_bucket_name . '/';
    }
    if ( $self->_object_name ) {
        $str_to_sign .= $self->_object_name;
    }
    # ToDo: fix this to the new way of doing things
    if ( $self->_sub_resource ) {
        $str_to_sign .= '?' . $self->_sub_resource;
    }

    # finally, set the 'Authorization' header
    my $digest = hmac_sha1_base64( $str_to_sign, $self->secret_access_key );
    $self->set_header( 'Authorization', "AWS " . $self->access_key_id . ':' . $digest . '=' );
}

sub decode {
    my ($self) = @_;

    my $data;

    # Firstly, check to see if we were successful or not (since this will
    # depend on how we might or might not decode the content).
    if ( $self->res_code == $self->code ) {
        # all ok, so decode the content
        if ( $self->res->content ) {
            # we have some content, now decide what to do with it
            if ( $self->_command->{has_content} ) {
                # plain content
                $data->{Content} = $self->res->content();
            }
            else {
                # this should be some XML to be decoded
                $data = XMLin( $self->res->content(), KeyAttr => [] );
            }
        }

        # let the outter program know everything was ok
        $data->{_awssum} = {
            'ok' => 1,
        }
    }
    else {
        # didn't work out ok, so decode the content and set some internal stuff
        $data = XMLin( $self->res->content(), KeyAttr => [] );
        $data->{_awssum} = {
            'ok'      => 0,
            'error'   => $data->{Code},
            'message' => $data->{Message},
        }
    }

    # save it for the outside world
    $self->data( $data );
}

## ----------------------------------------------------------------------------
# all our lovely commands

sub list_buckets {
    my ($self, $param) = @_;
    $self->clear();

    # "Get Service" - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTServiceGET.html

    $self->set_command( 'ListBuckets' );
    $self->region( $param->{Region} ) if $param->{Region};
    my $data = $self->send();

    # fix this array
    $data->{Buckets} = $self->_make_array_from( $data->{Buckets}{Bucket} );
}

sub delete_bucket {
    my ($self, $param) = @_;
    $self->clear();

    # DELETE Bucket - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTBucketDELETE.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to delete";
    }

    $self->set_command( 'DeleteBucket' );
    $self->_bucket_name( $param->{BucketName} );

    return $self->send();
}

sub describe_bucket_versioning {
    my ($self, $param) = @_;
    $self->clear();

    # GET Bucket versioning - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTBucketGETversioningStatus.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to describe it's versioning";
    }

    $self->set_command( 'DescribeBucketVersioning' );
    $self->_bucket_name( $param->{BucketName} );
    $self->_sub_resource( 'versioning' );

    return $self->send();
}

sub create_bucket {
    my ($self, $param) = @_;
    $self->clear();

    # "PUT Bucket" - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTBucketPUT.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to create";
    }

    $self->set_command( 'CreateBucket' );
    $self->region( $param->{Region} ) if $param->{Region};
    $self->_bucket_name( $param->{BucketName} );

    # depending on the Region, set the location constraint
    my $location_constraint = $self->_location_constraint();
    if ( $location_constraint ) {
        $self->content( "<CreateBucketConfiguration><LocationConstraint>$location_constraint</LocationConstraint></CreateBucketConfiguration>" );
    }

    return $self->send();
}

sub list_objects {
    my ($self, $param) = @_;
    $self->clear();

    # GET Bucket - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTBucketGET.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to list objects from";
    }

    $self->set_command( 'ListObjects' );
    $self->_bucket_name( $param->{BucketName} );
    $self->set_param_maybe( 'delimiter', $param->{Delimiter} );
    $self->set_param_maybe( 'marker', $param->{Market} );
    $self->set_param_maybe( 'max-keys', $param->{MaxKeys} );
    $self->set_param_maybe( 'prefix', $param->{Prefix} );

    my $data = $self->send();

    # fix up the Contents array
    $self->_fix_to_array( $data->{Contents} );

    return $data;
}

sub modify_bucket_logging {
    my ($self, $param) = @_;
    $self->clear();

    # PUT Bucket logging - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTBucketPUTlogging.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to modify it's logging";
    }

    $self->set_command( 'ModifyBucketLogging' );
    $self->_bucket_name( $param->{BucketName} );

    # ToDo: create the XML we need to send

    return $self->send();
}

sub modify_bucket_versioning {
    my ($self, $param) = @_;
    $self->clear();

    # PUT Bucket versioning - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTBucketPUTVersioningStatus.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to modify it's versioning";
    }
    # ToDo: check both Status and MfaDelete have valid values

    $self->set_command( 'ModifyBucketVersioning' );
    $self->_bucket_name( $param->{BucketName} );

    # create the XML we need to send
    my $xml = q{<VersioningConfiguration xmlns="http://s3.amazonaws.com/doc/2006-03-01/">};
    $xml .= qq{<Status>$param->{Status}</Status>}
        if $param->{Status};
    $xml .= qq{<MfaDelete>$param->{MfaDelete}</MfaDelete>}
        if $param->{MfaDelete};
    $xml .= q{</VersioningConfiguration>};
    $self->content( $xml );

    # ToDo: add all the headers that we are able to send

    return $self->send();
}

sub delete_object {
    my ($self, $param) = @_;
    $self->clear();

    # DELETE Object - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTObjectDELETE.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' from which to delete this object";
    }
    unless ( defined $param->{ObjectName} ) {
        croak "Provide an 'ObjectName' to delete";
    }

    $self->set_command( 'DeleteObject' );
    $self->_bucket_name( $param->{BucketName} );
    $self->_object_name( $param->{ObjectName} );

    # ToDo: add all the headers that we are able to send

    return $self->send();
}

sub get_object {
    my ($self, $param) = @_;
    $self->clear();

    # GET Object - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTObjectGET.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' from which to retrieve this object";
    }
    unless ( defined $param->{ObjectName} ) {
        croak "Provide an 'ObjectName' to retrieve";
    }

    $self->set_command( 'GetObject' );
    $self->_bucket_name( $param->{BucketName} );
    $self->_object_name( $param->{ObjectName} );

    # ToDo: add all the headers that we are able to send

    return $self->send();
}

sub create_object {
    my ($self, $param) = @_;
    $self->clear();

    # PUT Object - http://docs.amazonwebservices.com/AmazonS3/latest/API/RESTObjectPUT.html

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to put this object into";
    }
    unless ( defined $param->{ObjectName} ) {
        croak "Provide an 'ObjectName' to create";
    }
    unless ( defined $param->{Content} or defined $self->content ) {
        croak q{Provide some content for this object (either via a 'Content' parameter or via $s3->content(...)};
    }

    $self->set_command( 'CreateObject' );
    $self->_bucket_name( $param->{BucketName} );
    $self->_object_name( $param->{ObjectName} );

    # the locally passed 'Content' will override the already existing content()
    if ( defined $param->{Content} ) {
        $self->content( $param->{Content} );
    }

    # ToDo: add all the headers that we are able to send

    return $self->send();
}

## ----------------------------------------------------------------------------
# internal methods

sub _fix_to_array {
    my ($self, $item) = @_;

    # use $_[1] to change the 'actual' thing passed in
    $_[1] = $self->_make_array_from( $item );
    return;
}

## ----------------------------------------------------------------------------
__PACKAGE__->meta->make_immutable();
1;
## ----------------------------------------------------------------------------
