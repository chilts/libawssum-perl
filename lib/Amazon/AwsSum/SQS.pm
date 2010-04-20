## ----------------------------------------------------------------------------

package Amazon::AwsSum::SQS;

use strict;
use warnings;
use Carp;

use base qw(Amazon::AwsSum::Service);

use URI::Escape;
use DateTime;
use JSON::Any;

sub service_version { '2009-02-01' }
sub decode_xml { 1 }
sub method { 'GET' }
sub expect { 200 }

## ----------------------------------------------------------------------------
# constants

my $allowed = {
    AttributeNames => {
        All => 1,
        ApproximateNumberOfMessages => 1,
        ApproximateNumberOfMessagesNotVisible => 1,
        VisibilityTimeout => 1,
        CreatedTimestamp => 1,
        LastModifiedTimestamp => 1,
        Policy => 1,
        QueueArn => 1,
    },
    setable_AttributeNames => {
        VisibilityTimeout => 1,
        Policy => 1,
    },
};

## ----------------------------------------------------------------------------
# commands

sub CreateQueue {
    my ($self, $params) = @_;

    $self->reset();

    unless ( defined $params->{QueueName} ) {
        croak( 'provide a queue name to create' );
    }

    $self->action('CreateQueue');
    $self->add_parameter( 'QueueName', $params->{QueueName} );
    $self->add_parameter( 'DefaultVisibilityTimeout', $params->{DefaultVisibilityTimeout} )
        if defined $params->{DefaultVisibilityTimeout};
    return $self->send();
}

sub ListQueues {
    my ($self, $params) = @_;

    $self->reset();

    $self->action('ListQueues');
    $self->add_parameter( 'QueueNamePrefix', $params->{QueueNamePrefix} )
        if defined $params->{QueueNamePrefix};
    return $self->send();
}

sub GetQueueAttributes {
    my ($self, $params) = @_;

    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to query' );
    }

    unless ( defined $params->{AttributeName} ) {
        croak( 'provide an attribute name to retrieve' );
    }

    unless ( exists $allowed->{AttributeNames}{$params->{AttributeName}} ) {
        croak( 'provide [' . (join('|', sort keys %{$allowed->{AttributeNames}})) . '] as an attribute name' );
    }

    $self->action('GetQueueAttributes');
    $self->url( $params->{QueueUrl} );
    $self->add_parameter( 'AttributeName', $params->{AttributeName} );
    return $self->send();
}

sub SetQueueAttributes {
    my ($self, $params) = @_;

    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to query' );
    }

    unless ( defined $params->{AttributeName} ) {
        croak( 'provide an attribute/value pair' );
    }

    unless ( exists $allowed->{setable_AttributeNames}{$params->{AttributeName}} ) {
        croak( "unknown attribute, try: " . join(', ', keys %{$params->{AttributeName}}) );
    }

    unless ( defined $params->{AttributeValue} ) {
        croak( 'provide an attribute value' );
    }

    # if we have a Policy for the attribute, check that the JSON is valid
    if ( $params->{AttributeName} eq 'Policy' ) {
        my $obj = JSON::Any->jsonToObj($params->{AttributeValue});
        use Data::Dumper;
        print Dumper($obj);
        print JSON::Any->objToJson( $obj );
    }

    $self->action('SetQueueAttributes');
    $self->url( $params->{QueueUrl} );
    $self->add_parameter( 'Attribute.Name', $params->{AttributeName} );
    $self->add_parameter( 'Attribute.Value', $params->{AttributeValue} );
    return $self->send();
}

sub DeleteQueue {
    my ($self, $params) = @_;

    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to delete' );
    }

    $self->action('DeleteQueue');
    $self->url( $params->{QueueUrl} );
    return $self->send();
}

sub SendMessage {
    my ($self, $params) = @_;

    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to add this message to' );
    }

    unless ( defined $params->{MessageBody} ) {
        croak( 'provide a message body' );
    }

    $self->action('SendMessage');
    $self->url( $params->{QueueUrl} );
    $self->add_parameter( 'MessageBody', $params->{MessageBody} );
    return $self->send();
}

sub ReceiveMessage {
    my ($self, $params) = @_;

    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to retrieve this message from' );
    }

    $self->action('ReceiveMessage');
    $self->url( $params->{QueueUrl} );
    $self->add_param_value( 'VisibilityTimeout', $params->{VisibilityTimeout} );
    $self->add_param_value( 'MaxNumberOfMessages', $params->{MaxNumberOfMessages} );

    # might as well ask for all the Attributes whilst we're here
    $self->add_param_value( 'AttributeName.1', 'All' );

    return $self->send();
}

sub DeleteMessage {
    my ($self, $params) = @_;

    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to add this message to' );
    }

    unless ( defined $params->{ReceiptHandle} ) {
        croak( 'provide a receipt handle' );
    }

    $self->action('DeleteMessage');
    $self->url( $params->{QueueUrl} );
    $self->add_parameter( 'ReceiptHandle', $params->{ReceiptHandle} );
    return $self->send();
}

## ----------------------------------------------------------------------------
# utils

sub reset {
    my ($self) = @_;

    foreach ( qw(headers data params http_response http_request action url http_header errs) ) {
        $self->{$_} = undef;
    }
}

sub generate_url {
    my ($self) = @_;
    my $url = $self->url;

    # already got the URL for the Queue with some actions, therefore use the
    # service URL if not already defined
    unless ( $self->url ) {
        $self->url("https://queue.amazonaws.com:443/");
        $url = $self->url;
    }

    # create the URL with the action...
    $url .= "?Action=" . $self->action;

    # ...then add all the params on
    my $params = $self->params;
    $url .= '&' . join('&', map { "$_=" . uri_escape($params->{$_}) } keys %$params);

    $self->url( $url );
}

sub process_errs {
    my ($self) = @_;
    my @errs;

    my $data = $self->data();
    if ( defined $data->{Error} ) {
        push @errs, $data->{Error};
    }

    $self->errs( \@errs ) if @errs;
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
