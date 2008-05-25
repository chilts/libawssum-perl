## ----------------------------------------------------------------------------

package Amazon::AwsSum::S3;

use strict;
use warnings;
use Carp;

use base qw(Amazon::AwsSum::Service);

__PACKAGE__->mk_accessors( qw(bucket key sub_resource) );

use URI::Escape;
use HTTP::Date;

sub service_version { '2006-03-01' }

my $allowed = {
    Acl => {
        'private'            => 1,
        'public-read'        => 1,
        'public-read-write'  => 1,
        'authenticated-read' => 1,
    },
};

## ----------------------------------------------------------------------------
# commands

# operations on the service

sub ListBuckets {
    my ($self) = @_;
    $self->reset();

    $self->action('ListBuckets');
    $self->method( 'GET' );
    # $self->headers({});
    # $self->params({});
    $self->decode_xml(1);
    $self->expect( 200 );

    return $self->send();
}

sub CreateBucket {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to create' );
    }

    if ( defined $params->{LocationConstraint} ) {
        unless ( $params->{LocationConstraint} eq 'EU' ) {
            croak("if LocationConstraint is provided, it must be 'EU'");
        }
    }

    $self->action('CreateBucket');
    $self->bucket( $params->{Bucket} );
    $self->method( 'PUT' );
    if ( defined $params->{LocationConstraint} && $params->{LocationConstraint} eq 'EU' ) {
        $self->content("<CreateBucketConfiguration><LocationConstraint>EU</LocationConstraint></CreateBucketConfiguration>");
    }
    $self->expect( 200 );
    $self->decode_xml(0);

    return $self->send();
}

sub DeleteBucket {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to delete' );
    }

    $self->action('DeleteBucket');
    $self->bucket( $params->{Bucket} );
    $self->method( 'DELETE' );
    $self->expect( 204 );
    $self->decode_xml(0);

    return $self->send();
}

sub ListKeys {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( "provide a bucket who's keys to list" );
    }

    $self->action('ListKeys');
    $self->bucket( $params->{Bucket} );
    $self->method( 'GET' );
    $self->add_parameter( 'prefix', $params->{Prefix} );
    $self->add_parameter( 'max-keys', $params->{MaxKeys} );
    $self->add_parameter( 'marker', $params->{Marker} );
    $self->add_parameter( 'delimeter', $params->{Delimeter} );
    $self->decode_xml(1);
    $self->expect( 200 );

    return $self->send();
}

sub BucketLocation {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to query it\'s location' );
    }

    $self->action('Location');
    $self->bucket( $params->{Bucket} );
    $self->method( 'GET' );
    $self->sub_resource( 'location' );
    return $self->send();
}

sub PutObject {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to put this object in' );
    }

    unless ( defined $params->{Key} ) {
        croak( 'provide a key under which to save this object' );
    }

    unless ( defined $params->{content} ) {
        croak( 'provide some data to put into the object' );
    }

    $self->action('PutObject');
    $self->method( 'PUT' );
    $self->bucket( $params->{Bucket} );
    $self->key( $params->{Key} );
    $self->expect( 200 );

    # we might have been given a 'Content-Type' header
    $self->headers( $params->{headers} )
        if defined $params->{headers};

    # now add in our Acl
    $self->add_header('x-amz-acl', $params->{Acl})
        if defined $params->{Acl};

    # set the content
    $self->content( $params->{content} );

    return $self->send();
}

sub GetObject {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to retrieve the object from' );
    }

    unless ( defined $params->{Key} ) {
        croak( 'provide a key to retrieve the object' );
    }

    $self->action('GetObject');
    $self->method( 'GET' );
    $self->bucket( $params->{Bucket} );
    $self->key( $params->{Key} );
    $self->decode_xml(0);
    $self->expect( 200 );

    return $self->send();
}

sub HeadObject {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to retrieve the object from' );
    }

    unless ( defined $params->{Key} ) {
        croak( 'provide a key to retrieve the object' );
    }

    $self->action('HeadObject');
    $self->method( 'HEAD' );
    $self->bucket( $params->{Bucket} );
    $self->key( $params->{Key} );
    $self->decode_xml(0);
    $self->expect( 200 );

    return $self->send();
}

sub DeleteObject {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to delete the object from' );
    }

    unless ( defined $params->{Key} ) {
        croak( 'provide a key to delete the object' );
    }

    $self->action('DeleteObject');
    $self->method( 'DELETE' );
    $self->bucket( $params->{Bucket} );
    $self->key( $params->{Key} );
    $self->decode_xml(0);
    $self->expect( 204 );

    return $self->send();
}

sub Acl {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name' );
    }

    unless ( defined $params->{Acl} ) {
        croak( 'provide a canned acl' );
    }

    unless ( exists $allowed->{Acl}{$params->{Acl}} ) {
        croak( 'provide a canned acl' );
    }

    $self->action('Acl');
    $self->method( 'PUT' );
    $self->bucket( $params->{Bucket} );
    # add the key if it is defined, else the action will be on the bucket
    $self->key( $params->{Key} )
        if defined $params->{Key};
    $self->sub_resource( 'acl' );
    $self->add_header('x-amz-acl', $params->{Acl});
    $self->decode_xml(0);

    return $self->send();
}

sub GetAcl {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name' );
    }

    $self->action('GetAcl');
    $self->method( 'GET' );
    $self->bucket( $params->{Bucket} );
    # add the key if it is defined, else the action will be on the bucket
    $self->key( $params->{Key} )
        if defined $params->{Key};
    $self->sub_resource( 'acl' );
    $self->decode_xml(1);
    return $self->send();
}

sub PutAcl {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name' );
    }

    $self->action('PutAcl');
    $self->method( 'PUT' );
    $self->bucket( $params->{Bucket} );
    # add the key if it is defined, else the action will be on the bucket
    $self->key( $params->{Key} )
        if defined $params->{Key};
    $self->sub_resource( 'acl' );
    # set the content
    $self->content( $params->{content} );
    $self->decode_xml(0);
    return $self->send();
}

sub GetLogging {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to get the logging status' );
    }

    $self->action('GetLogging');
    $self->method( 'GET' );
    $self->bucket( $params->{Bucket} );
    $self->sub_resource( 'logging' );
    $self->decode_xml(1);
    return $self->send();
}

sub PutLogging {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to put logging to' );
    }

    $self->action('PutLogging');
    $self->method( 'PUT' );
    $self->bucket( $params->{Bucket} );
    $self->sub_resource( 'logging' );
    # set the content
    $self->content( $params->{content} );
    $self->decode_xml(0);
    return $self->send();
}

## ----------------------------------------------------------------------------
# override certain base functionality

sub reset {
    my ($self) = @_;

    foreach ( qw(sub_resource method bucket key headers data params http_response http_request action url http_header errs) ) {
        $self->{$_} = undef;
    }
}

sub decode_xml {
    my ($self, $decode_xml) = @_;
    if ( defined $decode_xml ) {
        $self->{decode_xml} = $decode_xml;
    }
    return $self->{decode_xml};
}

sub add_service_headers {
    my ($self) = @_;

    # add the Date to the headers
    $self->add_header('Date', time2str(time));
}

sub add_service_params {
    my ($self) = @_;
    # nothing to do for the S3 service
}

sub generate_signature {
    my ($self) = @_;

    # collect the data to be signed into here
    my $data = '';

    # add the HTTP-Verb
    $data .= $self->method . "\n";

    # add the following headers (if available)
    foreach my $hdr ( qw(Content-MD5 Content-Type Date) ) {
        if ( exists $self->{headers}{$hdr} ) {
            $data .= $self->{headers}{$hdr};
        }
        $data .= "\n";
    }

    # add the CanonicalizedAmzHeaders
    my $headers = $self->headers;
    my @amz_headers = sort grep { /^x-amz-/ } keys %$headers;
    foreach my $header ( @amz_headers ) {
        $data .= $header . ':';
        if ( ref $headers->{$header} eq 'ARRAY' ) {
            # ToDo: unfold long headers
            $data .= join(',', map { trim($_) } @{$headers->{$header}});
        }
        else {
            $data .= $headers->{$header};
        }
        $data .= "\n";
    }

    # add the CanonicalizedResource
    $data .= '/';
    if ( $self->bucket ) {
        $data .= $self->bucket . '/';
    }
    if ( $self->key ) {
        $data .= uri_escape($self->key);
    }
    if ( $self->sub_resource ) {
        $data .= '?' . $self->sub_resource;
    }

	my $digest = Digest::HMAC_SHA1->new( $self->secret_access_key );
	$digest->add( $data );
    $self->{headers}{Authorization} = "AWS " . $self->access_key_id . ':' . $digest->b64digest . '=';
}

sub generate_url {
    my ($self) = @_;
    my $url = $self->url;

    # see if this is a command on the service
    my $action = $self->action;
    if ( $self->action eq 'ListBuckets' ) {
        $url = 's3.amazonaws.com';
    }
    else {
        $url = $self->bucket . '.s3.amazonaws.com';
    }

    $url = "https://$url:443/";

    $url .= $self->key if $self->key;

    # add all the params on
    my $params = $self->params;
    if ( defined $params and %$params ) {
        $url .= '?';
        $url .= join('&', map {
            defined $params->{$_}
                ? "$_=" . uri_escape($params->{$_})
                : $_
            } keys %$params);
    }

    # NOTE: the above and below are probably mutually exclusive, but you really
    # should check and make sure the '?' is only added once

    # do the sub_resource if available
    if ( $self->sub_resource ) {
        $url .= '?' . $self->sub_resource;
    }

    $self->url( $url );
}

## ----------------------------------------------------------------------------
# utils

sub process_errs {
    my ($self) = @_;

    my $data = $self->data();

    # currently, we're checking to see if these two elements are defined in the
    # returned message - but this is just heuristics, it really should be
    # better
    return unless defined $data->{Code} and defined $data->{Message};

    $self->errs( [ $data ] );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
