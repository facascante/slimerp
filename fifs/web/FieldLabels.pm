package FieldLabels;
require Exporter;
@ISA = qw(Exporter);
@EXPORT=qw(getFieldLabels);

use strict;

use lib '.', '..';

use Defs;
require CustomFields;

sub getFieldLabels	{
	my($Data, $level)=@_;

	my %labels=();
	return \%labels if(!$Data or !$level);

	my $CustomFieldNames=CustomFields::getCustomFieldNames($Data);
    my $natnumname=$Data->{'SystemConfig'}{'NationalNumName'} || 'National Number';

	if($level== $Defs::LEVEL_PERSON)	{

		%labels = (
			strNationalNum => $natnumname,
			strStatus => "Status",
			strSalutation => 'Title',
			strLocalFirstname => 'First name',
			strLocalMiddlename => 'Middle name',
			strPreferredName => 'Preferred name',
			strLocalSurname => 'Family name',
			strLatinSurname => 'Family name (Latin)',


			strMaidenName => 'Maiden name',
			strMotherCountry=> 'Country of Birth (Mother)',
			strFatherCountry=> 'Country of Birth (Father)',
			dtDOB => 'Date of Birth',
			strPlaceofBirth => 'Place (Town) of Birth',
            strCountryOfBirth => 'Country of Birth',
			intGender => 'Gender',
			strAddress1 => 'Address Line 1',
			strAddress2 => 'Address Line 2',
			strSuburb => 'Suburb',
			strState => 'State',
			strCountry => 'Country',
			strPostalCode => 'Postal Code',
			strPhoneHome => 'Phone (Home)',
			strPhoneWork => 'Phone (Work)',
			strPhoneMobile => 'Phone (Mobile)',
			strPager => 'Pager',
			strFax => 'Fax',
			strEmail => 'Email',
			strEmail2 => 'Email 2',
			intEthnicityID => 'Ethnicity',
			intDeceased => 'Deceased?',
			strLoyaltyNumber => 'Loyalty Number',
			strPassportNationality => 'Passport Nationality',
			strPassportNo => 'Passport Number',
			strPassportIssueCountry => 'Passport Country of Issue',
			dtPassportExpiry => 'Passport Expiry Date',
			strEmergContName => 'Emergency Contact Name',
			strEmergContNo => 'Emergency Contact Number',
			strEmergContNo2 => 'Emergency Contact Number 2',
			strEmergContRel => 'Emergency Contact Relationship',
			intP1Gender => 'Parent/Guardian 1 Gender',
			intP2Gender => 'Parent/Guardian 2 Gender',
			strP1Salutation=> 'Parent/Guardian 1 Salutation',
			strP1FName => 'Parent/Guardian 1 Firstname',
			strP1SName => 'Parent/Guardian 1 Surname',
			strP2Salutation=> 'Parent/Guardian 2 Salutation',
			strP2FName => 'Parent/Guardian 2 Firstname',
			strP2SName => 'Parent/Guardian 2 Surname',
			strP1Phone => 'Parent/Guardian 1 Phone',
			strP1Phone2 => 'Parent/Guardian 1 Phone 2',
			strP1PhoneMobile => 'Parent/Guardian 1 Mobile',
			strP2Phone => 'Parent/Guardian 2 Phone',
			strP2Phone2 => 'Parent/Guardian 2 Phone 2',
			strP2PhoneMobile => 'Parent/Guardian 2 Mobile',
			strP1Email=> 'Parent/Guardian 1 Email',
			strP2Email=> 'Parent/Guardian 2 Email',
			strP1Email2=> 'Parent/Guardian 1 Email 2',
			strP2Email2=> 'Parent/Guardian 2 Email 2',
			strEyeColour => 'Eye Colour',
			strHairColour => 'Hair Colour',
			strHeight => 'Height',
			strWeight => 'Weight',
			strNotes => 'Notes',
			dtLastUpdate => 'Last Updated',
			tTimeStamp => 'Last Updated',
			dtPoliceCheck => $Data->{'SystemConfig'}{'dtPoliceCheck_Text'} ? $Data->{'SystemConfig'}{'dtPoliceCheck_Text'} : 'Police Check Date',
			dtPoliceCheckExp => $Data->{'SystemConfig'}{'dtPoliceCheckExp_Text'} ? $Data->{'SystemConfig'}{'dtPoliceCheckExp_Text'} : 'Police Check Expiry Date',
			strPoliceCheckRef => 'Police Check Number',
            intMemberToHideID => "Upload to Website Results",
			strPreferredLang => 'Preferred Language',
       
		);
	}

	if($level== $Defs::LEVEL_CLUB)	{
		%labels = (
            strFIFAID => 'FIFA ID',
            strLocalName => 'Name',
            strLocalShortName => 'Short Name',
            strLatinName => 'Name (Latin)',
            strLatinShortName => 'Short Name (Latin)',
            strStatus => 'Status',
            strISOCountry => 'Country (ISO)',

            strRegion => 'Region',
            strPostalCode => 'Postal Code',
            strTown => 'Town',
            strAddress => 'Address',
            strWebURL => 'Website',
            strEmail => 'Email',
            strPhone => 'Phone',
            strFax => 'Fax',
            strContactTitle => 'Contact Person Title',
            strContactEmail => 'Contact Person Email',
            strContactPhone => 'Contact Person Phone',
            strContact => 'Contact Person',
		);
	}
	for my $k (keys %labels)	{
		$labels{$k}= ($Data->{'SystemConfig'}{'FieldLabel_'.$k} || '') if exists $Data->{'SystemConfig'}{'FieldLabel_'.$k};
	}

    my $lang = $Data->{lang};

    foreach my $key (keys %labels) {
        $labels{$key} = $lang->txt($labels{$key});
    }

	return \%labels;
}
