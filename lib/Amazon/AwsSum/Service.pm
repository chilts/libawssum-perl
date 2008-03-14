## ----------------------------------------------------------------------------

package Amazon::AwsSum::Service;

use strict;
use warnings;
use Carp;

use base qw(Class::Accessor);
__PACKAGE__->mk_accessors(qw{
    access_key_id secret_access_key
    method params headers request content
    url
    http_header http_request http_response
    data action errs _ua
});

use List::Util qw( reduce );
use Digest::HMAC_SHA1;
use XML::Simple;
use LWP;

## ----------------------------------------------------------------------------
# these methods should be defined in each subclass

foreach ( qw(service_version) ) {
    my $method_name = __PACKAGE__ . '::' . $_;
    unless ( defined &{$method_name} ) {
        no strict 'refs';
        *{$method_name} = sub {
            die "Please implement the '$_' method in your service subclass";
        };
    }
}

## ----------------------------------------------------------------------------
# create a new service

sub new {
    my ($class) = @_;
    $class = ref $class || $class;

    my $self = bless({}, $class);

    $self->_ua( LWP::UserAgent->new() );

    return $self;
}

## ----------------------------------------------------------------------------
# these methods may be left as the default or overridden in each subclass

sub decode_xml {
    return 1;
}

sub add_service_headers {
    my ($self) = @_;
    # generally, nothing to do
}

sub add_service_params {
    my ($self) = @_;

    # most of the services add 'Action' as a parameter
    $self->add_parameter( 'Action', $self->action );

    # and the rest of the required ones
    $self->add_parameter( 'Timestamp', DateTime->now( time_zone => 'UTC' )->strftime("%Y-%m-%dT%H:%M:%SZ") );
    $self->add_parameter( 'Version', $self->service_version );
    $self->add_parameter( 'AWSAccessKeyId', $self->access_key_id );
    $self->add_parameter( 'SignatureVersion', 1 );

    # test
    # $self->add_parameter( 'Timestamp', '2006-12-08T07:48:03Z' );
    # $self->add_parameter( 'Version', '2007-01-03' );
    # $self->add_parameter( 'AWSAccessKeyId', '10QMXFEV71ZS32XQFTR2' );
    # $self->add_parameter( 'SignatureVersion', 1 );
}

sub generate_signature {
    my ($self) = @_;

    my $params = $self->params();

    my @order = sort { lc($a) cmp lc($b) } keys %$params;
    my $data = reduce { $a . $b . $params->{$b} } '', @order;

	my $digest = Digest::HMAC_SHA1->new( $self->secret_access_key );
	$digest->add( $data );
    $self->add_parameter( 'Signature', $digest->b64digest . '=' );
}

sub add_header {
    my ($self, $name, $val) = @_;
    return unless defined $val;

    if ( $name =~ m{ \A x-amz- }xms ) {
        $name = lc $name;
    }

    if ( exists $self->{headers}{$name} ) {
        unless ( ref $self->{headers}{$name} eq 'ARRAY' ) {
            $self->{headers}{$name} = [ $self->{headers}{$name} ];
        }
        push @{$self->{headers}{$name}}, $val;
    }
    else {
        $self->{headers}{$name} = $val;
    }
}

sub add_parameter {
    my ($self, $name, $val) = @_;

    # at first we wanted to check if $val was defined, but in S3 you can have
    # parameters which do you have a value e.g. ?acl, ?logging, etc so really,
    # you should check things are defined before calling this method

    $self->{params}{$name} = $val;
}

sub add_numeral_parameters {
    my ($self, $name, $val) = @_;

    return unless defined $val;

    # just one to add
    unless ( ref $val ) {
        $self->{params}{"$name.1"} = $val;
        return;
    }

    # should be an array
    my $i = 0;
    foreach ( @$val ) {
        $i++;
        $self->{params}{"$name.$i"} = $_;
    }
}

# for SimpleDB
sub add_numeral_tuples {
    my ($self, $basename, $name, $val) = @_;

    return unless defined $val;

    # just one to add
    unless ( ref $val ) {
        $self->{params}{"$basename.1.$name"} = $val;
        return;
    }

    # should be an array
    my $i = 0;
    foreach ( @$val ) {
        $i++;
        $self->{params}{"$basename.$i.$name"} = $_;
    }
}

sub create_http_header {
    my ($self, $command) = @_;

    my $http_header = HTTP::Headers->new;
    while (my ($k, $v) = each %{$self->{headers}} ) {
        $http_header->header($k => $v);
    }
    $self->http_header( $http_header );
}

sub create_request {
    my ($self, $command) = @_;

    $self->http_request( HTTP::Request->new($self->method, $self->url, $self->http_header) );
    if ( $self->content ) {
        $self->http_request->content( $self->content );
    }
    return $self->{request};
}

# so we have a number of things
# - action
# - (given)   headers
# - (created) headers
# - (common)  parameters
# - (given)   parameters
# - (created) parameters
# - signature (somewhere)

sub prepare_request {
    my ($self) = @_;

    # add some common headers and other parameters for each service
    $self->add_service_headers();
    $self->add_service_params();

    # we know what we've got now, so sign it
    $self->generate_signature();
    $self->generate_url();

    # now let's start creating the objects
    $self->create_http_header();
    $self->create_request();
}

sub process_response {
    my ($self) = @_;

    # see if we should decode the XML for this service/message
    if ( $self->decode_xml and $self->http_response->content ) {
        $self->data( XMLin( $self->http_response->content ));
        $self->process_errs();
    }
}

sub process_errs {
    my ($self) = @_;

    my @errs;

    my $data = $self->data();
    if ( defined $data->{Errors} ) {
        $self->force_array( $data->{Errors}{Error} );
        foreach ( @{$data->{Errors}{Error}} ) {
            push @errs, {
                Code    => $_->{Code},
                Message => $_->{Message},
            };
        }
    }

    $self->errs( \@errs ) if @errs;
}

sub send {
    my ($self) = @_;
    $self->prepare_request();

    # send and save the response
    my $http_response = $self->_ua->request( $self->http_request );
    $self->http_response( $http_response );

    $self->process_response();
}

sub force_array {
    return if ref $_[1] eq 'ARRAY';
    $_[1] = [ $_[1] ];
}

sub trim {
    my ($value) = @_;

    $value =~ s/^\s+//;
    $value =~ s/\s+$//;
    return $value;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
