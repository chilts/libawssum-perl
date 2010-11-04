## ----------------------------------------------------------------------------

package AwsSum::Amazon::SQS;

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

# which QueueName are we working on (can be set on the service as a
# default, or each command will just get it from $params->{QueueName})
has '_queue_name' => ( is => 'rw', isa => 'Str' );

# constants
# Version: http://docs.amazonwebservices.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/WhatsNew.html
sub version { '2009-02-01' }

# internal helpers
has '_command' => ( is => 'rw', isa => 'HashRef' );

## ----------------------------------------------------------------------------

my $commands = {
    # Actions for Queues
    # * CreateQueue
    # * DeleteQueue
    # * ListQueues
    # * GetQueueAttributes
    # * SetQueueAttributes
    # Actions for Access Control on Queues
    # * AddPermission
    # * RemovePermission
    # Actions for Messages
    # * SendMessage
    # * ReceiveMessage
    # * DeleteMessage
    # * ChangeMessageVisibility

    # Actions for Queues
    CreateQueue => {
        name      => 'CreateQueue',
        method    => 'create_queue',
        req_queue => 0,
        verb      => 'get',
    },
    DeleteQueue => {
        name      => 'DeleteQueue',
        method    => 'delete_queue',
        req_queue => 1,
        verb      => 'get',
    },
    ListQueues => {
        name      => 'ListQueues',
        method    => 'list_queues',
        req_queue => 0,
        verb      => 'get',
    },

    # Actions for Messages
    ReceiveMessage => {
        name      => 'ReceiveMessage',
        method    => 'receive_message',
        req_queue => 1,
        verb      => 'get'
    },
};

sub _host {
    my ($self) = @_;
    return q{sqs.} . $self->region . q{.amazonaws.com};
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

    # From: http://docs.amazonwebservices.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/endpoints.html
    my $url = q{https://} . $self->_host . q{/};

    # Yes, I've read this:
    # http://docs.amazonwebservices.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/index.html?ImportantIdentifiers.html
    # but seriously! This makes it easier. Also, they won't change the URL
    # unless they update the version number of the API, so we'll get time to
    # fix it either way.
    if ( $self->_command->{req_queue} ) {
        $url .= $self->account_number . q{/} . $self->_queue_name;
    }

    return $url
}

sub code { 200 }
#sub code {
#    my ($self) = @_;
#    return $self->_command->{code};
#}

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

    # See: http://docs.amazonwebservices.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/Query_QueryAuth.html

    # sign the request (remember this is SignatureVersion '2')
    my $str_to_sign = '';
    $str_to_sign .= uc($self->verb) . "\n";
    $str_to_sign .= $self->_host . "\n";
    if ( $self->_command->{req_queue} ) {
        $str_to_sign .= '/' . $self->account_number . q{/} . $self->_queue_name . "\n";
    }
    else {
        $str_to_sign .= "/\n"; # ToDo: need the path here ... (HTTPRequestURI) !
    }

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

sub create_queue {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{QueueName}) ) {
        croak q{Provide a 'QueueName' for the new queue};
    }

    $self->set_command( 'CreateQueue' );
    $self->set_params_if_defined( $param, 'QueueName', 'DefaultVisibilityTimeout' );
    return $self->send();
}

sub delete_queue {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{QueueName}) ) {
        croak q{Provide a 'QueueName' for the new queue};
    }

    $self->set_command( 'DeleteQueue' );
    $self->_queue_name( $param->{QueueName} );
    $self->set_params_if_defined( $param, 'QueueName', 'DefaultVisibilityTimeout' );
    return $self->send();
}

sub list_queues {
    my ($self, $param) = @_;

    $self->set_command( 'ListQueues' );
    $self->set_param_maybe( 'QueueNamePrefix', $param->{QueueNamePrefix} );
    my $data = $self->send();

    $data->{ListQueuesResult}{QueueUrl} = $self->_make_array_from( $data->{ListQueuesResult}{QueueUrl} );

    return $data;
}

sub receive_message {
    my ($self, $param) = @_;

    unless ( $self->is_valid_something($param->{QueueName}) ) {
        croak q{Provide a 'QueueName' to be deleted};
    }

    $self->set_command( 'ReceiveMessage' );
    $self->_queue_name( $param->{QueueName} );
    return $self->send();
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
