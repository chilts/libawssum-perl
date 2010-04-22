## ----------------------------------------------------------------------------

package Amazon::AwsSum::SQS;

use strict;
use warnings;
use Carp;

use base qw(Amazon::AwsSum::Service);

use URI::Escape;
use DateTime;
use JSON::Any;
use Amazon::AwsSum::Util qw(force_array);

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
    ActionName => {
        '*' => 1,
        SendMessage => 1,
        ReceiveMessage => 1,
        DeleteMessage => 1,
        ChangeMessageVisibility => 1,
        GetQueueAttributes => 1,
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

sub AddPermission {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to add this permission to' );
    }

    unless ( defined $params->{Label} ) {
        croak( 'provide a label for this permission' );
    }

    unless ( defined $params->{AWSAccountId} ) {
        croak( 'provide at least one AWSAccountID for this permission' );
    }

    unless ( defined $params->{ActionName} ) {
        croak( 'provide at least one ActionName for this permission' );
    }

    # make sure we have arrays rather than just single valued scalars
    force_array($params->{AWSAccountId});
    force_array($params->{ActionName});

    unless ( scalar @{$params->{AWSAccountId}} == scalar @{$params->{ActionName}} ) {
        croak( 'provide the same number of AWSAccountIDs as ActionNames' )
    }

    # check all the IDs
    foreach my $i ( @{$params->{AWSAccountId}} ) {
        # should match 123456789012 (12 digits)
        unless ( $i =~ m{ \A \d{12} \z }xms ) {
            croak( 'action ' . "'$a'" . ' not allowed, provide:' . join(', ', sort keys %{$allowed->{ActionName}}) );
        }
    }

    # check all the ActionNames
    foreach my $a ( @{$params->{ActionName}} ) {
        unless ( defined $allowed->{ActionName}{$a} ) {
            croak( 'action ' . "'$a'" . ' not allowed, provide:' . join(', ', sort keys %{$allowed->{ActionName}}) );
        }
    }

    $self->action('AddPermission');
    $self->url( $params->{QueueUrl} );
    $self->add_parameter( 'Label', $params->{Label} );
    $self->add_numeral_parameters( 'AWSAccountId', $params->{AWSAccountId} );
    $self->add_numeral_parameters( 'ActionName', $params->{ActionName} );
    return $self->send();
}

sub RemovePermission {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to add this permission to' );
    }

    unless ( defined $params->{Label} ) {
        croak( 'provide a label for this permission' );
    }

    $self->action('RemovePermission');
    $self->url( $params->{QueueUrl} );
    $self->add_parameter( 'Label', $params->{Label} );
    return $self->send();
}

sub ChangeMessageVisibility {
    my ($self, $params) = @_;
    $self->reset();

    unless ( defined $params->{QueueUrl} ) {
        croak( 'provide a queue url to add this permission to' );
    }

    $self->action('ChangeMessageVisibility');
    $self->url( $params->{QueueUrl} );
    $self->add_parameter( 'VisibilityTimeout', $params->{VisibilityTimeout} );
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
