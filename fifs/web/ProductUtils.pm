
package ProductUtils;

require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(get_product_attributes);
@EXPORT_OK = qw(get_product_attributes);

use strict;
use lib  '.', '..';

sub get_product_attributes {
    my $params = shift;
    my ($dbh, $product_id, $attribute_type) = @{$params}{qw/ dbh product_id attribute_type /};
    
    my %attributes;
    
    if ($dbh && $product_id){
        
        my $query = qq[
            SELECT 
                intAttributeType,
                strAttributeValue 
            FROM 
                tblProductAttributes
            WHERE 
                intProductID = ?
        ];

        my $sth = $dbh->prepare($query);
        $sth->execute($product_id);
        
        while (my ($type, $value) = $sth->fetchrow_array()) {
            next if ($value and $value eq 'NULL');
            push @{$attributes{$type}}, $value;
        }
    }
    
    if ($attribute_type){
        return $attributes{$attribute_type} || [];
    }
    else{
        return \%attributes;
    }
}