## ----------------------------------------------------------------------------

package Amazon::AwsSum::SNS;

use strict;
use warnings;
use Carp;

use base qw(Amazon::AwsSum::Service);
use base qw(Class::Accessor);

use URI::Escape;
use DateTime;
use List::Util qw( reduce );
use Digest::SHA qw(hmac_sha256_base64);

sub service_version { '2010-03-31' }
sub decode_xml { 1 }
sub method { 'GET' }
sub expect { 200 }

__PACKAGE__->mk_accessors(qw{
    region
});

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
    protocol => {
        'http'       => 1,
        'https'      => 1,
        'email'      => 1,
        'email-json' => 1,
        'sqs'        => 1,
    },
};

my $region = {
    'us-east-1'      => 1,
    'us-west-1'      => 1,
    'eu'             => 1,
    'ap-southeast-1' => 1,
};

## ----------------------------------------------------------------------------
# commands

sub ListTopics {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    $self->action('ListTopics');
    $self->region( $params->{Region} );

    return $self->send();
}

sub CreateTopic {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need a name to create a topic
    unless ( defined $params->{Name} ) {
        croak( 'provide a TopicName for this topic' );
    }

    $self->action('CreateTopic');
    $self->region( $params->{Region} );
    $self->add_param_value( 'Name', $params->{Name} );

    return $self->send();
}

sub DeleteTopic {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need an ARN for this topic
    unless ( defined $params->{TopicArn} ) {
        croak( 'provide a Topic Arn for this topic' );
    }

    $self->action('DeleteTopic');
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );

    return $self->send();
}

sub GetTopicAttributes {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need an ARN for this topic
    unless ( defined $params->{TopicArn} ) {
        croak( 'provide a Topic Arn for this topic' );
    }

    $self->action('GetTopicAttributes');
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );

    return $self->send();
}

sub SetTopicAttributes {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need an ARN for this topic
    unless ( defined $params->{TopicArn} ) {
        croak( 'provide a Topic Arn for this topic' );
    }

    # need an AttributeName
    unless ( defined $params->{AttributeName} ) {
        croak( 'provide an AttributeName for this topic' );
    }

    # need an AttributeValue
    unless ( defined $params->{AttributeValue} ) {
        croak( 'provide an AttributeValue for this topic' );
    }

    $self->action('SetTopicAttributes');
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );
    $self->add_param_value( 'AttributeName', $params->{AttributeName} );
    $self->add_param_value( 'AttributeValue', $params->{AttributeValue} );

    return $self->send();
}

sub ListSubscriptions {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    $self->action('ListSubscriptions');
    $self->region( $params->{Region} );

    return $self->send();
}

sub ListSubscriptionsByTopic {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    $self->action('ListSubscriptionsByTopic');
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );

    return $self->send();
}

sub Subscribe {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need an ARN for this topic
    unless ( defined $params->{TopicArn} ) {
        croak( 'provide a Topic Arn for this subscription' );
    }

    # protocol
    unless ( defined $params->{Protocol} ) {
        croak( 'provide a Protocol for this subscription' );
    }

    # this Endpoint can be a URL, Email address and SQS Queue ARN
    unless ( defined $params->{Endpoint} ) {
        croak( 'provide an endpoint for this subscription' );
    }

    $self->action('Subscribe');
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );
    $self->add_param_value( 'Protocol', $params->{Protocol} );
    $self->add_param_value( 'Endpoint', $params->{Endpoint} );

    return $self->send();
}

sub Publish {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need an ARN for this publish
    unless ( defined $params->{TopicArn} ) {
        croak( 'provide a Topic Arn for this publish' );
    }

    # message
    unless ( defined $params->{Message} ) {
        croak( 'provide a Message for this publish' );
    }

    $self->action('Publish');
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );
    $self->add_param_value( 'Message', $params->{Message} );
    $self->add_param_value( 'Subject', $params->{Subject} );

    return $self->send();
}

sub Unsubscribe {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need a Subscription ARN
    unless ( defined $params->{SubscriptionArn} ) {
        croak( 'provide a Subscription Arn for this unsubscribe' );
    }

    $self->action('Unsubscribe');
    $self->region( $params->{Region} );
    $self->add_param_value( 'SubscriptionArn', $params->{SubscriptionArn} );

    return $self->send();
}

sub AddPermission {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need an ARN for this publish
    unless ( defined $params->{TopicArn} ) {
        croak( 'provide a Topic Arn for this publish' );
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
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );
    $self->add_parameter( 'Label', $params->{Label} );
    $self->add_numeral_parameters( 'AWSAccountId.member', $params->{AWSAccountId} );
    $self->add_numeral_parameters( 'ActionName.member', $params->{ActionName} );
    return $self->send();
}

sub RemovePermission {
    my ($self, $params) = @_;
    $self->reset();

    # set a default region and check for it to be valid
    $params->{Region} ||= 'us-east-1';
    unless ( $region->{$params->{Region}} ) {
        croak( 'unknown region, try:' . join(', ', keys %$region) );
    }

    # need an ARN for this publish
    unless ( defined $params->{TopicArn} ) {
        croak( 'provide a Topic Arn for this publish' );
    }

    unless ( defined $params->{Label} ) {
        croak( 'provide a label for this permission' );
    }

    $self->action('RemovePermission');
    $self->region( $params->{Region} );
    $self->add_param_value( 'TopicArn', $params->{TopicArn} );
    $self->add_parameter( 'Label', $params->{Label} );
    return $self->send();
}

## ----------------------------------------------------------------------------
# overriden Service.pm methods

sub add_service_params {
    my ($self) = @_;

    # most of the services add 'Action' as a parameter
    $self->add_parameter( 'Action', $self->action );

    # and the rest of the required ones
    $self->add_parameter( 'Timestamp', DateTime->now( time_zone => 'UTC' )->strftime("%Y-%m-%dT%H:%M:%SZ") );
    # $self->add_parameter( 'Version', $self->service_version );
    $self->add_parameter( 'AWSAccessKeyId', $self->access_key_id );
    $self->add_parameter( 'SignatureMethod', 'HmacSHA256' );
    $self->add_parameter( 'SignatureVersion', 2 );
}

# Needs to be HMAC SHA256 for SignatureVersion=2 (SNS doesn't allow
# SignatureVersion=1)
sub generate_signature {
    my ($self) = @_;

    # make the param portion of the signature
    my $params = $self->params();
    my $canonicalized_query_string = reduce { $a . '&' . $b } map { $_ . '=' . uri_escape($params->{$_}) } sort { $a cmp $b } keys %$params;

    my $digest = hmac_sha256_base64(
        $self->method, "\n",
        lc( 'sns.' . $self->region . '.amazonaws.com:443'), "\n",
        "/\n",
        $canonicalized_query_string,
        $self->secret_access_key
    );
    $self->add_parameter( 'Signature', "$digest=" );
}

# generate the URL for this service
sub generate_url {
    my ($self) = @_;
    my $url = $self->url;

    # already got the URL for the Queue with some actions, therefore use the
    # service URL if not already defined
    unless ( $self->url ) {
        $self->url( 'https://sns.' . $self->region . '.amazonaws.com:443/' );
        $url = $self->url;
    }

    # create the URL with the action...
    $url .= "?Action=" . $self->action;

    # ...then add all the params on
    my $params = $self->params;
    $url .= '&' . join('&', map { "$_=" . uri_escape($params->{$_}) } keys %$params);

    $self->url( $url );
}

## ----------------------------------------------------------------------------
# utils

sub reset {
    my ($self) = @_;

    foreach ( qw(headers data params http_response http_request action url http_header errs) ) {
        $self->{$_} = undef;
    }
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
