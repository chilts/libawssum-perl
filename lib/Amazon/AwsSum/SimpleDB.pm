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
    $self->add_parameter( 'DomainName', $params->{DomainName} );
    return $self->send();
}

sub ListDomains {
    my ($self) = @_;

    $self->action('ListDomains');
    return $self->send();
}

sub DeleteDomain {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a key name to delete' );
    }

    $self->action('DeleteDomain');
    $self->add_parameter( 'DomainName', $params->{DomainName} );
    return $self->send();
}

sub PutAttributes {
    my ($self, $params) = @_;

    unless ( defined $params->{DomainName} ) {
        croak( 'provide a domain name to put the attributes into' );
    }

    # if uuid is defined (and there is no ItemName yet), create one
    #if ( defined $params->{uuid} and !defined $params->{i} ) {
    #    $params->{i} = Data::UUID->new->create_str;
    #}

    unless ( defined $params->{ItemName} ) {
        croak( 'provide an item name' );
    }

    $self->action('PutAttributes');
    $self->add_parameter( 'DomainName', $params->{DomainName} );
    $self->add_parameter( 'ItemName', $params->{ItemName} );
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
    $self->add_parameter( 'DomainName', $params->{DomainName} );
    $self->add_parameter( 'ItemName', $params->{ItemName} );
    $self->add_numeral_parameters( 'Attribute', 'Name', $params->{AttributeName} );
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
    $self->add_parameter( 'DomainName', $params->{DomainName} );
    $self->add_parameter( 'ItemName', $params->{ItemName} );
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

    $self->action('DeleteAttributes');
    $self->add_parameter( 'DomainName', $params->{DomainName} );
    $self->add_parameter( 'QueryExpression', $params->{QueryExpression} );
    $self->add_parameter( 'MaxNumberOfItems', $params->{MaxNumberOfItems} );
    $self->add_parameter( 'NextToken', $params->{NextToken} );
    return $self->send();
}

## ----------------------------------------------------------------------------
# utils

sub add_attributes {
    my ($self, $attribute_pair) = @_;

    return unless defined $attribute_pair;

    # all av values should be of the form:
    # - key
    # - key=value
    # - !key=value
    my $i = 0;
    foreach my $ap ( @$attribute_pair ) {
        my ($replace, $name, undef, $value) = $ap =~ m{ \A (!?) ([^=]+) (= (.*))? \z }xms;

        if ( defined $name ) {
            $self->add_parameter( "Attribute.$i.Name", $name );
            $self->add_parameter( "Attribute.$i.Value", $value )
                if defined $value;
            $self->add_parameter( "Attribute.$i.Replace", $replace )
                if defined $replace;
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
