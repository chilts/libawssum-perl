## ----------------------------------------------------------------------------

package Amazon::AwsSum::SimpleDB;

use strict;
use warnings;
use Carp;

use base qw(Amazon::AwsSum::Service);

use URI::Escape;
use DateTime;

sub service_version { '2007-11-07' }
sub decode_xml { 1 }
sub method { 'GET' }
sub expect { 200 }

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

sub CreateDomain {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a domain name to create' );
    }

    $self->action('CreateDomain');
    $self->add_param_value( 'DomainName', $params->{DomainName} );
    return $self->send();
}

sub ListDomains {
    my ($self, $params) = @_;

    $self->action('ListDomains');
    $self->add_param_value( 'MaxNumberOfDomains', $params->{MaxNumberOfDomains} );
    $self->add_param_value( 'NextToken', $params->{NextToken} );
    return $self->send();
}

sub DeleteDomain {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a key name to delete' );
    }

    $self->action('DeleteDomain');
    $self->add_param_value( 'DomainName', $params->{DomainName} );
    return $self->send();
}

sub PutAttributes {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a domain name to put the attributes into' );
    }

    unless ( defined $params->{ItemName} ) {
        croak( 'provide an item name' );
    }

    $self->action('PutAttributes');
    $self->add_param_value( 'DomainName', $params->{DomainName} );
    $self->add_param_value( 'ItemName', $params->{ItemName} );
    if ( defined $params->{AttributePair} ) {
        $self->add_attributes( $params->{AttributePair});
    }
    else {
        $self->add_numeral_tuples( 'Attribute', 'Name', $params->{AttributeName} );
        $self->add_numeral_tuples( 'Attribute', 'Value', $params->{AttributeValue} );
        $self->add_numeral_tuples( 'Attribute', 'Replace', $params->{AttributeReplace} );
    }

    return $self->send();
}

sub GetAttributes {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a domain name to query' );
    }

    unless ( defined $params->{ItemName} ) {
        croak( 'provide an item name to retrieve' );
    }

    $self->action('GetAttributes');
    $self->add_param_value( 'DomainName', $params->{DomainName} );
    $self->add_param_value( 'ItemName', $params->{ItemName} );
    $self->add_param_value( 'AttributeName', $params->{AttributeName} );
    return $self->send();
}

sub DeleteAttributes {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a domain name which this item is in' );
    }

    unless ( defined $params->{ItemName} ) {
        croak( 'provide an item name to delete from' );
    }

    $self->action('DeleteAttributes');
    $self->add_param_value( 'DomainName', $params->{DomainName} );
    $self->add_param_value( 'ItemName', $params->{ItemName} );
    if ( defined $params->{AttributePair} ) {
        $self->add_attributes( $params->{AttributePair});
    }
    else {
        $self->add_numeral_tuples( 'Attribute', 'Name', $params->{AttributeName} );
        $self->add_numeral_tuples( 'Attribute', 'Value', $params->{AttributeValue} );
    }
    return $self->send();
}

sub Query {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a domain name to query against' );
    }

    $self->action('Query');
    $self->add_param_value( 'DomainName', $params->{DomainName} );
    $self->add_param_value( 'QueryExpression', $params->{QueryExpression} );
    $self->add_param_value( 'MaxNumberOfItems', $params->{MaxNumberOfItems} );
    $self->add_param_value( 'NextToken', $params->{NextToken} );
    return $self->send();
}

## ----------------------------------------------------------------------------
# utils

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
    $url = "https://sdb.amazonaws.com:443/?Action=" . $self->action;

    # ...then add all the params on
    my $params = $self->params;
    $url .= '&' . join('&', map { "$_=" . uri_escape($params->{$_}) } keys %$params);

    $self->url( $url );
}

## ----------------------------------------------------------------------------
1;
## ----------------------------------------------------------------------------
