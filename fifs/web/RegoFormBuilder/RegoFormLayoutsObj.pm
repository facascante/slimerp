package RegoFormLayoutsObj;

use lib '..';
use RegoFormObj;
our @ISA = qw(RegoFormObj);

use strict;

use Defs;
use Reg_common;
use RegoFormFieldObj;
use RegoFormFieldAddedObj;
use RegoFormOrderObj;
use RegoFormNrsUtils;

sub getLayouts {
    my $self = shift;

    my (%params) = @_;
    my $Data         = $params{'Data'};
    my $entityTypeID = $params{'entityTypeID'} || 0; #can't always get from $Data, therefore has to be specifically passed
    my $entityID     = $params{'entityID'}     || 0; #ditto

    return undef if !$Data or !$entityTypeID or !$entityID;

    #could have extended even further here (RegoFormLayoutsLinkedObj, RegoFormLayoutsUnlinkedObj), however decided against.
    my $layouts = ($self->isNodeForm() or $self->isLinkedForm())
        ? _getLayoutsLinkedForm($self, $Data, $entityTypeID, $entityID)
        : _getLayoutsUnlinkedForm($Data, $self->{'ID'});

    return $layouts;
}

#nationalrego> in actuality, this sub would cater for both national (node and linked) forms as well as
#nationalrego> unlinked forms. However, was separated (and the original retrieval method retained below)
#nationalrego> to ensure no disruption to unlinked forms.
sub _getLayoutsLinkedForm {
    my ($self, $Data, $entityTypeID, $entityID) = @_;

    my $dbh = $Data->{'db'};

    my $regoFormObj;
    my $regoFormFieldObjs;
    my $formID;

    my %combinedFields = ();

    my @order  = ('intDisplayOrder');

    if ($self->isLinkedForm()) {
        $formID = $self->getValue('intParentBodyFormID');
        $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);  #get the regoFormObj for the parent body form i.e. the node form.

        my %where = (intRegoFormID=>$formID);
        $regoFormFieldObjs = RegoFormFieldObj->getList(dbh=>$dbh, where=>\%where, order=>\@order);
        _addToCombinedFields($Data, \%combinedFields, $regoFormFieldObjs, 1, $formID, $entityTypeID, $entityID, $regoFormObj); #source = node form field;

        _addAddedToCombinedFields($Data, \%combinedFields, $formID, $entityTypeID, $entityID, $regoFormObj);

        $formID = $self->{'ID'};
        $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);  #get the regoFormObj for the linked form

        %where  = (intRegoFormID=>$formID);
        $regoFormFieldObjs = RegoFormFieldObj->getList(dbh=>$dbh, where=>\%where, order=>\@order);
        _addToCombinedFields($Data, \%combinedFields, $regoFormFieldObjs, 2, $formID, $entityTypeID, $entityID, $regoFormObj); #source = linked form field;
    }
    else { #must be a node form
        $formID = $self->{'ID'};
        $regoFormObj = RegoFormObj->load(db=>$dbh, ID=>$formID);  #get the regoFormObj for the node form

        my %where = (intRegoFormID=>$formID);
        $regoFormFieldObjs = RegoFormFieldObj->getList(dbh=>$dbh, where=>\%where, order=>\@order);
        _addToCombinedFields($Data, \%combinedFields, $regoFormFieldObjs, 1, $formID, $entityTypeID, $entityID, $regoFormObj); #source = node form field;

        if (!$self->isOwnForm(entityID=>$entityID)) {
            _addAddedToCombinedFields($Data, \%combinedFields, $formID, $entityTypeID, $entityID, $regoFormObj);
        }
    }

    my @fields = ('intDisplayOrder', 'intSource', 'intFieldID', "CONCAT(intSource, 's', intFieldID) AS KeyField");
    my %where  = (intRegoFormID=>$formID, intEntityTypeID=>$entityTypeID, intEntityID=>$entityID);

    #when the order is changed for the first time, the new order is stored in tblRegoFormOrder.
    my $displayOrder = RegoFormOrderObj->getList(dbh=>$dbh, fields=>\@fields, where=>\%where, order=>\@order, format=>'allhref', keyfield=>'KeyField');

    my @layoutFields = ();

    foreach my $key (keys %combinedFields) {
        if ($combinedFields{$key}{'perm'} !~ /Hidden|ChildDefine/) {
            my $fieldName    = $key;
            my $order        = $combinedFields{$key}{'order'};
            my $fieldID      = $combinedFields{$key}{'fieldID'};
            my $text         = $combinedFields{$key}{'text'};
            my $fieldType    = $combinedFields{$key}{'type'};
            my $source       = $combinedFields{$key}{'source'};
            my $owner        = $combinedFields{$key}{'owner'};
            my $perm         = $combinedFields{$key}{'perm'};
            my $keyField     = $source.'s'.$fieldID;
            if (%$displayOrder) {
                $order = (exists $displayOrder->{$keyField}) ? $displayOrder->{$keyField}{'intDisplayOrder'} : 9999999; #if not found in the order table, show it last
            }
            push @layoutFields, [$fieldName, $order, $text, $fieldID, $fieldType, $source, $owner, $keyField, $perm];
        }
    }

    my @sortedFields = sort { $a->[1] <=> $b->[1] } @layoutFields;

    return \@sortedFields;
}

sub _addAddedToCombinedFields {
    my ($Data, $combinedFields, $formID, $entityTypeID, $entityID, $regoFormObj) = @_;

    my $createdLevel = $regoFormObj->getValue('intCreatedLevel');
    my $entityStructure = getEntityStructure($Data, $entityTypeID, $entityID, $createdLevel, 1);

    foreach my $entityArr (@$entityStructure) {
        my %where = (intRegoFormID=>$formID, intEntityTypeID=>@$entityArr[0], intEntityID=>@$entityArr[1], intStatus=>1);
        my $regoFormFieldAddedObjs = RegoFormFieldAddedObj->getList(dbh=>$Data->{'db'}, where=>\%where);
        _addToCombinedFields($Data, $combinedFields, $regoFormFieldAddedObjs, 3, $formID, @$entityArr[0], @$entityArr[1], $regoFormObj); #source = added field;
    }

    return 1;
}

sub _addToCombinedFields {
    my ($Data, $combinedFields, $regoFormFieldObjs, $source, $formID, $entityTypeID, $entityID, $regoFormObj) = @_;

    my $createdLevel = $regoFormObj->getValue('intCreatedLevel');

    my $multiplier = 1000;
    my $highOrder  = 9999999;

    for my $regoFormFieldObj(@$regoFormFieldObjs) {
        my $fieldName  = $regoFormFieldObj->getValue('strFieldName') || '';
        my $fieldID    = _getFieldID($regoFormFieldObj, $source);
        my $fieldType  = $regoFormFieldObj->getValue('intType');
        my $fieldPerm  = $regoFormFieldObj->getValue('strPerm');
        my $fieldOrder = $regoFormFieldObj->getValue('intDisplayOrder');

        if (!exists $combinedFields->{$fieldName}) {
            my $perm = $fieldPerm;

            if ($fieldType == 0 and $perm =~ /Hidden|ChildDefine/) {
                my $chPerm = checkHierarchicalPerms($Data, $fieldName, $entityTypeID, $entityID, $createdLevel);
                $perm = $chPerm if $chPerm and (isHeavierPerm($chPerm, $perm)); 
            }

            my $owner = _getOwner($regoFormFieldObj, $source, $regoFormObj);
            my $order = ($fieldOrder) ? $fieldOrder + $source * $multiplier : $highOrder; #put added/linked fields after the node fields. 

            $combinedFields->{$fieldName} = {
                order   => $order,
                text    => $regoFormFieldObj->getValue('strText'),
                fieldID => $fieldID,
                type    => $fieldType,
                source  => $source,
                perm    => $perm,
                owner   => $owner,
            };
        }
        elsif ($fieldPerm !~ /Hidden|ChildDefine/) {
            my $perm = $combinedFields->{$fieldName}{'perm'};

            $combinedFields->{$fieldName}{'perm'} = $fieldPerm if isHeavierPerm($fieldPerm, $perm);

            my $owner     = _getOwner($regoFormFieldObj, $source, $regoFormObj);
            my $currOwner = $combinedFields->{$fieldName}{'owner'};

            $combinedFields->{$fieldName}{'owner'} = $owner if ($owner > $currOwner) or ($currOwner > $owner and $perm =~ /Hidden|ChildDefine/);

            my $order = ($fieldOrder) ? $fieldOrder + $source * $multiplier : $highOrder; #put added/linked fields after the node fields. 

            $combinedFields->{$fieldName}{'order'} = $order;

            if ($combinedFields->{$fieldName}{'source'} != $source) {
                $combinedFields->{$fieldName}{'source'}  = $source; 
                $combinedFields->{$fieldName}{'fieldID'} = _getFieldID($regoFormFieldObj, $source);
            }
        }
    }
    return 1;
}

sub _getFieldID {
    my ($regoFormFieldObj, $source) = @_;
    my $idFieldName = ($source >= 3) ? 'intRegoFormFieldAddedID' : 'intRegoFormFieldID';
    my $fieldID     = $regoFormFieldObj->getValue($idFieldName);
    return $fieldID;
}

sub _getOwner {
    my ($regoFormFieldObj, $source, $regoFormObj) = @_;

    my $ownerLevel = $regoFormObj->getValue('intCreatedLevel');
    my $ownerID    = $regoFormObj->getValue('intCreatedID');

    if ($source == 1) {
        #it's either a nodeForm or a parentBodyForm. intCreated{Level,ID} will be set, so leave owner{Level,ID} as is.
    }
    elsif ($source == 2) {
        #it's a linked form, intCreated{Level,ID} may not be set because fields only kicked off with nationalrego.
        if (!$ownerLevel or !$ownerID) {
            my $clubID = $regoFormObj->getValue('intClubID');
            $clubID = 0 if $clubID < 0;

            if (!$ownerLevel) {
                $ownerLevel = ($clubID) ? $Defs::LEVEL_CLUB : $Defs::LEVEL_ASSOC;
            }
            if (!$ownerID) {
                $ownerID = ($clubID) ? $clubID : $regoFormObj->getValue('intAssocID');
            }
        }
    }
    else { #source == 3
        #can use the entity{Type,ID} from the regoFormFieldObj.
        $ownerLevel = $regoFormFieldObj->getValue('intEntityTypeID');
        $ownerID    = $regoFormFieldObj->getValue('intEntityID');
    }

    my $owner = "$ownerLevel.$ownerID";

    return $owner;
}

sub _getLayoutsUnlinkedForm {
    my ($Data, $formID) = @_;

    my $statement = qq[
        SELECT strFieldName, intDisplayOrder, strText, intRegoFormFieldID, intType
        FROM tblRegoFormFields
        WHERE intRegoFormID = ?  AND strPerm <> 'Hidden' AND strPerm <> 'ChildDefine'
        ORDER BY intDisplayOrder
    ];

    my $dbh = $Data->{'db'};

    my $query = $dbh->prepare($statement);
    $query->execute($formID);

    my @fields;

    while (my($field, $order_id, $bodytext, $field_id, $field_type) = $query->fetchrow_array()) {
        push @fields, [ $field, $order_id, $bodytext, $field_id, $field_type, 1 ] #(the last element, the 1, is) source = same as for a node form field.
    }

    return \@fields;
}

1;
