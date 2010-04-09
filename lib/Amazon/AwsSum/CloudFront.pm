## ----------------------------------------------------------------------------

package Amazon::AwsSum::CloudFront;

use strict;
use warnings;
use Carp;

use base qw(Amazon::AwsSum::Service);

__PACKAGE__->mk_accessors( qw(distribution_id) );

use URI::Escape;
use DateTime;
use Time::Local;
use List::Util qw( reduce );
use Digest::HMAC_SHA1;
use HTTP::Date;

sub service_version { '2010-03-01' }
sub decode_xml { 1 }
# sub expect { 200 }
sub add_service_params {}

## ----------------------------------------------------------------------------
# constants

my $allowed = {
    AttributeNames => {
        All => 1,
        ApproximateNumberOfMessages => 1,
        VisibilityTimeout => 1,
    },
    setable_AttributeNames => {
        VisibilityTimeout => 1,
    },
};

## ----------------------------------------------------------------------------
# commands

sub CreateDistribution {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to use as the distribution source' );
    }

    $self->action('CreateDistribution');
    $self->method( 'POST' );
    # $self->headers({});
    # $self->params({});
    $self->expect( 201 );

    my $bucket = $params->{Bucket};
    my $caller_reference = timelocal(localtime());
    my $enabled = $params->{Enabled} ? 'true' : 'false';

    my $content = '<?xml version="1.0" encoding="UTF-8"?>';
    $content .= '<DistributionConfig xmlns="http://cloudfront.amazonaws.com/doc/2010-03-01/">';
    $content .= " <Origin>$bucket.s3.amazonaws.com</Origin>";
    $content .= " <CallerReference>$caller_reference</CallerReference>";
    $content .= " <CNAME>$params->{CNAME}</CNAME>" if defined $params->{CNAME};
    $content .= " <Comment>$params->{Comment}</Comment>" if defined $params->{Comment};
    $content .= " <Enabled>$enabled</Enabled>";
    $content .= '</DistributionConfig>';
    $self->content($content);

    return $self->send();
}

sub GetDistributionList {
    my ($self, $params) = @_;
    $self->reset();

    $self->action('GetDistributionList');
    $self->method( 'GET' );
    # $self->headers({});
    # these only get added if the value is defined
    $self->add_param_value( 'Marker', $params->{Marker} );
    $self->add_param_value( 'MaxItems', $params->{MaxItems} );
    $self->expect( 200 );

    return $self->send();
}

sub GetDistribution {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{DistributionID} ) {
        croak( 'provide a distribution id' );
    }

    $self->action('GetDistribution');
    $self->distribution_id( $params->{DistributionID} );
    $self->method( 'GET' );
    # $self->headers({});
    # $self->params({});
    $self->expect( 200 );

    return $self->send();
}

sub GetDistributionConfig {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{DistributionID} ) {
        croak( 'provide a distribution id' );
    }

    $self->action('GetDistributionConfig');
    $self->distribution_id( $params->{DistributionID} );
    $self->method( 'GET' );
    # $self->headers({});
    # $self->params({});
    $self->expect( 200 );

    return $self->send();
}

sub PutDistributionConfig {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{DistributionID} ) {
        croak( 'provide a distribution id' );
    }

    unless ( defined $params->{Bucket} ) {
        croak( 'provide a bucket name to use as the distribution source' );
    }

    unless ( defined $params->{IfMatch} ) {
        croak( 'provide an IfMatch (the ETag from a GetDistributionConfig response)' );
    }

    unless ( defined $params->{CallerReference} ) {
        croak( 'provide a CallerReference from the original distribution config' );
    }

    $self->action('PutDistributionConfig');
    $self->distribution_id( $params->{DistributionID} );
    $self->method( 'PUT' );
    $self->headers({ 'If-Match' => $params->{IfMatch} });
    # $self->params({});
    $self->expect( 200 );

    my $bucket = $params->{Bucket};
    my $caller_reference = $params->{CallerReference};
    my $enabled = $params->{Enabled} ? 'true' : 'false';

    my $content = '<?xml version="1.0" encoding="UTF-8"?>';
    $content .= '<DistributionConfig xmlns="http://cloudfront.amazonaws.com/doc/2010-03-01/">';
    $content .= " <Origin>$bucket.s3.amazonaws.com</Origin>";
    $content .= " <CallerReference>$caller_reference</CallerReference>";
    $content .= " <CNAME>$params->{CNAME}</CNAME>" if defined $params->{CNAME};
    $content .= " <Comment>$params->{Comment}</Comment>" if defined $params->{Comment};
    $content .= " <Enabled>$enabled</Enabled>";
    $content .= '</DistributionConfig>';
    $self->content($content);


    return $self->send();
}

sub DeleteDistribution {
    my ($self, $params) = @_;

    unless ( defined $params->{DistributionID} ) {
        croak( 'provide a distribution id' );
    }

    $self->action('DeleteDistribution');
    $self->distribution_id( $params->{DistributionID} );
    $self->method( 'DELETE' );
    $self->headers({
        'If-Match' => $params->{IfMatch},
    });
    # $self->params({});
    $self->expect( 204 );

    return $self->send();
}

## ----------------------------------------------------------------------------
# override certain base functionality

sub reset {
    my ($self) = @_;

    foreach ( qw() ) {
    # foreach ( qw(method headers data params http_response action url http_header http_request errs) ) {
        $self->{$_} = undef;
    }
}

sub add_service_headers {
    my ($self) = @_;

    # add the Date to the headers
    $self->add_header('Date', time2str(time));
}

sub add_attributes {
    my ($self, $attribute_pair) = @_;

    return unless defined $attribute_pair;

    $attribute_pair = [ $attribute_pair ]
        unless ref $attribute_pair eq 'ARRAY';

    # all av values should be of the form:
    # - key
    # - key=value
    # - !key=value
    my $i = 0;
    foreach my $ap ( @$attribute_pair ) {
        my ($replace, $name, undef, $value) = $ap =~ m{ \A (!?) ([^=]+) (= (.*))? \z }xms;

        if ( defined $name ) {
            $self->add_param_value( "Attribute.$i.Name", $name );
            $self->add_param_value( "Attribute.$i.Value", $value )
                if defined $value;
            $self->add_param_value( "Attribute.$i.Replace", $replace ? 'true' : 'false' );
        }
        else {
            croak "invalid attribute pair '$ap'";
        }
        $i++;
    }
}

sub generate_url {
    my ($self) = @_;
    my $url;

    # create the URL with the action...
    if ( $self->action eq 'CreateDistribution' ) {
        $url = 'https://cloudfront.amazonaws.com:443/' . $self->service_version() . '/distribution';
    }
    elsif ( $self->action eq 'GetDistributionList' ) {
        $url = 'https://cloudfront.amazonaws.com:443/' . $self->service_version() . '/distribution';
    }
    elsif ( $self->action eq 'GetDistribution' ) {
        $url = 'https://cloudfront.amazonaws.com:443/' . $self->service_version() . '/distribution/' . $self->distribution_id();
    }
    elsif ( $self->action eq 'GetDistributionConfig' ) {
        $url = 'https://cloudfront.amazonaws.com:443/' . $self->service_version() . '/distribution/' . $self->distribution_id() . '/config';
    }
    elsif ( $self->action eq 'PutDistributionConfig' ) {
        $url = 'https://cloudfront.amazonaws.com:443/' . $self->service_version() . '/distribution/' . $self->distribution_id() . '/config';
    }
    elsif ( $self->action eq 'DeleteDistribution' ) {
        $url = 'https://cloudfront.amazonaws.com:443/' . $self->service_version() . '/distribution/' . $self->distribution_id();
    }
    else {
        die 'not sure what URL this action is';
    }

    # ...then add all the params on
    my $params = $self->params || {};
    if ( %$params ) {
        $url .= '?' . join('&', map { uri_escape($_) . "=" . uri_escape($params->{$_}) } keys %$params);
    }

    $self->url( $url );
}

sub generate_signature {
    my ($self) = @_;

    # collect the data to be signed into here
    my $data = '';

    # print "date=$self->{headers}{Date}\n";

    # add the following headers (if available)
    foreach my $hdr ( qw(Date) ) {
        $data .= $self->{headers}{$hdr};
    }

	my $digest = Digest::HMAC_SHA1->new( $self->secret_access_key );
	$digest->add( $data );
    $self->{headers}{Authorization} = "AWS " . $self->access_key_id . ':' . $digest->b64digest . '=';
}

sub process_errs {
    my ($self) = @_;

    my @errs;

    my $data = $self->data();
    return unless defined $data->{Error};
    push @errs, {
        Code    => "$data->{Error}{Code}($data->{Error}{Type})",
        Message => $data->{Error}{Message},
    };

    $self->errs( \@errs ) if @errs;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
