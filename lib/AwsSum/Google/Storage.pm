## ----------------------------------------------------------------------------

package AwsSum::Google::Storage;

use Moose;
with 'AwsSum::Service';
with qw(
    AwsSum::Service
    AwsSum::Amazon::Service
);
use Carp;
use Digest::SHA qw (hmac_sha1_base64);
use Digest::MD5 qw(md5_base64);
use XML::Simple;

## ----------------------------------------------------------------------------
# constants

my $NL = qq{\n};
my $EMPTY = q{};
my $SPACE = q{ };

my $commands = {
    # Service Requests
    ListBuckets => {
        name   => q{ListBuckets},
        method => q{list_buckets},
        verb   => q{get},
        code   => 200,
    },

    # Bucket Requests
    CreateBucket => {
        name   => q{CreateBucket},
        method => q{create_bucket},
        verb   => q{put},
        code   => 200,
    },
    ListObjects => {
        name   => q{ListObjects},
        method => q{list_objects},
        verb   => q{get},
        code   => 200,
    },
    DeleteBucket => {
        name   => q{DeleteBucket},
        method => q{delete_bucket},
        verb   => q{delete},
        code   => 204,
    },

    # Object Requests
    GetObject => {
        name           => 'GetObject',
        method         => 'get_object',
        verb           => 'get',
        code           => 200,
        has_content    => 1,
    },
    PutObject => {
        name           => 'PutObject',
        method         => 'put_object',
        verb           => 'put',
        code           => 200,
    },
    DeleteObject => {
        name           => 'DeleteObject',
        method         => 'delete_object',
        verb           => 'delete',
        code           => 204,
    },
};

## ----------------------------------------------------------------------------
# setup details needed or pre-determined

# some things required from the user
has 'id'         => ( is => 'rw', isa => 'Str' );
has 'access_key' => ( is => 'rw', isa => 'Str' );
has 'secret'     => ( is => 'rw', isa => 'Str' );

## ----------------------------------------------------------------------------
# internal helpers/methods

# some things which we use constantly within the Google Storage service
has '_command' => ( is => 'rw', isa => 'HashRef' );
has '_bucket_name'  => ( is => 'rw', isa => 'Str' );
has '_object_name'  => ( is => 'rw', isa => 'Str' );
has '_sub_resource' => ( is => 'rw', isa => 'Str' );

sub _host {
    my ($self) = @_;

    # From: https://code.google.com/apis/storage/docs/developer-guide.html#endpoints
    if ( $self->_bucket_name ) {
        return $self->_bucket_name . q{.commondatastorage.googleapis.com};
    }
    else {
        return q{commondatastorage.googleapis.com};
    }
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

    # make the base url (always use SSL)
    my $url = q{https://} . $self->_host() . q{/};

    # add the object_name if there is one
    $url .= $self->_object_name()
        if $self->_object_name();

    # ToDo: sub resource

    return $url;
}

sub code {
    my ($self) = @_;
    return $self->_command->{code};
}

sub sign {
    my ($self) = @_;

    # add the service params first before signing
    my $date = DateTime->now( time_zone => 'UTC' )->strftime("%a, %d %b %Y %H:%M:%S %z");
    $self->set_header( 'Date', $date );

    # if we have content, set the type and MD5
    if ( $self->content ) {
        $self->set_header( q{Content-MD5}, md5_base64($self->content) );
    }

    # See: https://code.google.com/apis/storage/docs/developer-guide.html#authentication
    # Authorization: GOOG1 google_storage_access_key:signature
    # Signature = Base64-Encoding-Of(HMAC-SHA1(UTF-8-Encoding-Of(YourGoogleStorageSecretKey, MessageToBeSigned)))
    # MessageToBeSigned = UTF-8-Encoding-Of(CanonicalHeaders + CanonicalExtensionHeaders + CanonicalResource)

    my $headers = $self->headers();

    # Canonical Headers
    my $canonical_headers = q{};
    $canonical_headers .= uc($self->verb) . $NL;
    $canonical_headers .= ($headers->{'Content-MD5'} // $EMPTY) . $NL;
    $canonical_headers .= ($headers->{'Content-Type'} // $EMPTY) . $NL;
    $canonical_headers .= qq{$date$NL};

    # ToDo: Canonical Extension Headers
    my $canonical_extension_headers = q{};
    # get all the x-goog- headers, lowercased and sorted
    my @headers = sort grep { m{ \A x-goog- }xms } map { lc } keys %{$self->headers};

    # Canonical Resource
    my $canonical_resource = $EMPTY;
    $canonical_resource .= q{/} . $self->_bucket_name
        if $self->_bucket_name;
    $canonical_resource .= q{/} . ($self->_object_name // $EMPTY);
    $canonical_resource .= q{?} . $self->_sub_resource
        if $self->_sub_resource;

    # String to Sign
    my $str_to_sign = $canonical_headers . $canonical_extension_headers . $canonical_resource;
    # warn '-' x 79, "\n";
    # warn $str_to_sign, "\n";
    # warn '-' x 79, "\n";
    my $signature = hmac_sha1_base64($str_to_sign, $self->secret );
    $self->set_header( q{Authorization}, q{GOOG1} . $SPACE . $self->access_key . qq{:$signature=} );
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

    # "GET service" - https://code.google.com/apis/storage/docs/reference-methods.html#getservice

    $self->set_command( 'ListBuckets' );
    my $data = $self->send();

    # fix this array
    $data->{Buckets} = $self->_make_array_from( $data->{Buckets}{Bucket} );
}

sub create_bucket {
    my ($self, $param) = @_;
    $self->clear();

    # "PUT bucket" - https://code.google.com/apis/storage/docs/reference-methods.html#putbucket

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to create";
    }

    # do the content length, otherwise we get "411 Length Required"
    $self->set_header( q{Content-Length}, 0 );

    $self->set_command( 'CreateBucket' );
    $self->_bucket_name( $param->{BucketName} );

    return $self->send();
}

sub delete_bucket {
    my ($self, $param) = @_;
    $self->clear();

    # DELETE Bucket - https://code.google.com/apis/storage/docs/reference-methods.html#deletebucket

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to delete";
    }

    $self->set_command( 'DeleteBucket' );
    $self->_bucket_name( $param->{BucketName} );

    return $self->send();
}

sub list_objects {
    my ($self, $param) = @_;
    $self->clear();

    # GET Bucket - https://code.google.com/apis/storage/docs/reference-methods.html#getbucket

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

sub get_object {
    my ($self, $param) = @_;
    $self->clear();

    # GET Object - https://code.google.com/apis/storage/docs/reference-methods.html#getobject

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

sub put_object {
    my ($self, $param) = @_;

    # PUT Object - https://code.google.com/apis/storage/docs/reference-methods.html#putobject

    unless ( defined $param->{BucketName} ) {
        croak "Provide a 'BucketName' to put this object into";
    }
    unless ( defined $param->{ObjectName} ) {
        croak "Provide an 'ObjectName' to create";
    }
    unless ( defined $param->{Content} or defined $self->content ) {
        croak q{Provide some content for this object (either via a 'Content' parameter or via $s3->content(...)};
    }

    $self->set_command( 'PutObject' );
    $self->_bucket_name( $param->{BucketName} );
    $self->_object_name( $param->{ObjectName} );

    # the locally passed 'Content' will override the already existing content()
    if ( defined $param->{Content} ) {
        $self->content( $param->{Content} );
    }

    # ToDo: add all the headers that we are able to send

    return $self->send();
}

sub delete_object {
    my ($self, $param) = @_;
    $self->clear();

    # DELETE Object - https://code.google.com/apis/storage/docs/reference-methods.html#deleteobject

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

=pod

=head1 NAME

AwsSum::Google::Storage - interface to Google's Storage web service

=head1 SYNOPSIS

    $storage = AwsSum::Google::Storage->new();
    $storage->id( 'Your ID Here );
    $storage->access_key( 'Your Access Key' );
    $storage->secret( 'Your Secret' );

    # list buckets
    $storage->list_buckets();

=cut
