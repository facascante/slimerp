#
# $Header: svn://svn/SWM/trunk/web/Countries.pm 11348 2014-04-23 01:11:55Z fkhezri $
#

package Countries;
use Data::Dumper;
require Exporter;
@ISA =  qw(Exporter);
@EXPORT = qw(getCountriesHash getCountriesArray getOceaniaCountriesHash getOceaniaCountriesArray);
@EXPORT_OK = qw(getCountriesHash getCountriesArray getCountriesNameToData getOceaniaCountriesHash getOceaniaCountriesArray);

    my $noCountryDisclosedID = 300;
	my %countries	=	(
		1 => ['AFGHANISTAN','AFG','AF'],
		2 => ['ALBANIA','ALB','AL'],
		3 => ['ALGERIA','DZA','DZ'],
		4 => ['AMERICAN SAMOA','ASM','AS'],
		5 => ['ANDORRA','AND','AD'],
		6 => ['ANGOLA','AGO','AO'],
		7 => ['ANGUILLA','AIA','AI'],
		8 => ['ANTARCTICA','ATA','AQ'],
		9 => ['ANTIGUA AND BARBUDA','ATG','AG'],
		10 => ['ARGENTINA','ARG','AR'],
		11 => ['ARMENIA','ARM','AM'],
		12 => ['ARUBA','ABW','AW'],
		13 => ['AUSTRALIA','AUS','AU'],
		14 => ['AUSTRIA','AUT','AT'],
		15 => ['AZERBAIJAN','AZE','AZ'],
		16 => ['BAHAMAS','BHS','BS'],
		17 => ['BAHRAIN','BHR','BH'],
		18 => ['BANGLADESH','BGD','BD'],
		19 => ['BARBADOS','BRB','BB'],
		20 => ['BELARUS','BLR','BY'],
		21 => ['BELGIUM','BEL','BE'],
		22 => ['BELIZE','BLZ','BZ'],
		23 => ['BENIN','BEN','BJ'],
		24 => ['BERMUDA','BMU','BM'],
		25 => ['BHUTAN','BTN','BT'],
		26 => ['BOLIVIA','BOL','BO'],
		27 => ['BOSNIA AND HERZEGOWINA','BIH','BA'],
		28 => ['BOTSWANA','BWA','BW'],
		29 => ['BOUVET ISLAND','BVT','BV'],
		30 => ['BRAZIL','BRA','BR'],
		31 => ['BRITISH INDIAN OCEAN TERRITORY','IOT','IO'],
		32 => ['BRUNEI DARUSSALAM','BRN','BN'],
		33 => ['BULGARIA','BGR','BG'],
		34 => ['BURKINA FASO','BFA','BF'],
		35 => ['BURUNDI','BDI','BI'],
		36 => ['CAMBODIA','KHM','KH'],
		37 => ['CAMEROON','CMR','CM'],
		38 => ['CANADA','CAN','CA'],
		39 => ['CAPE VERDE','CPV','CV'],
		40 => ['CAYMAN ISLANDS','CYM','KY'],
		41 => ['CENTRAL AFRICAN REPUBLIC','CAF','CF'],
		42 => ['CHAD','TCD','TD'],
		43 => ['CHILE','CHL','CL'],
		44 => ['CHINA','CHN','CN'],
		45 => ['CHRISTMAS ISLAND','CXR','CX'],
		46 => ['COCOS (KEELING) ISLANDS','CCK','CC'],
		47 => ['COLOMBIA','COL','CO'],
		48 => ['COMOROS','COM','KM'],
		49 => ['CONGO, Democratic Republic of','COD','CD'],
		50 => ['CONGO, People\'s Republic of','COG','CG'],
		51 => ['COOK ISLANDS','COK','CK'],
		52 => ['COSTA RICA','CRI','CR'],
		53 => ["COTE D'IVOIRE",'CIV','CI'],
		54 => ['CROATIA(local name:Hrvatska)','HRV','HR'],
		55 => ['CUBA','CUB','CU'],
		56 => ['CYPRUS','CYP','CY'],
		57 => ['CZECH REPUBLIC','CZE','CZ'],
		58 => ['DENMARK','DNK','DK'],
		59 => ['DJIBOUTI','DJI','DJ'],
		60 => ['DOMINICA','DMA','DM'],
		61 => ['DOMINICAN REPUBLIC','DOM','DO'],
		62 => ['EAST TIMOR','TLS','TL'],
		63 => ['ECUADOR','ECU','EC'],
		64 => ['EGYPT','EGY','EG'],
		65 => ['EL SALVADOR','SLV','SV'],
		66 => ['EQUATORIAL GUINEA','GNQ','GQ'],
		67 => ['ERITREA','ERI','ER'],
		68 => ['ESTONIA','EST','EE'],
		69 => ['ETHIOPIA','ETH','ET'],
		70 => ['FALKLAND ISLANDS(MALVINAS)','FLK','FK'],
		71 => ['FAROE ISLANDS','FRO','FO'],
		72 => ['FIJI','FJI','FJ'],
		73 => ['FINLAND','FIN','FI'],
		74 => ['FRANCE','FRA','FR'],
		75 => ['FRANCE','FRA','FR'],
		76 => ['FRENCH GUIANA','GUF','GF'],
		77 => ['FRENCH POLYNESIA','PYF','PF'],
		78 => ['FRENCH SOUTHERN TERRITORIES','ATF','TF'],
		79 => ['GABON','GAB','GA'],
		80 => ['GAMBIA','GMB','GM'],
		81 => ['GEORGIA','GEO','GE'],
		82 => ['GERMANY','DEU','DE'],
		83 => ['GHANA','GHA','GH'],
		84 => ['GIBRALTAR','GIB','GI'],
		85 => ['GREECE','GRC','GR'],
		86 => ['GREENLAND','GRL','GL'],
		87 => ['GRENADA','GRD','GD'],
		88 => ['GUADELOUPE','GLP','GP'],
		89 => ['GUAM','GUM','GU'],
		90 => ['GUATEMALA','GTM','GT'],
		91 => ['GUINEA','GIN','GN'],
		92 => ['GUINEA-BISSAU','GNB','GW'],
		93 => ['GUYANA','GUY','GY'],
		94 => ['HAITI','HTI','HT'],
		95 => ['HEARD AND MCDONALD ISLANDS','HMD','HM'],
		96 => ['HONDURAS','HND','HN'],
		97 => ['HONG KONG','HKG','HK'],
		98 => ['HUNGARY','HUN','HU'],
		99 => ['ICELAND','ISL','IS'],
		100 => ['INDIA','IND','IN'],
		101 => ['INDONESIA','IDN','ID'],
		102 => ['IRAN (ISLAMIC REPUBLIC OF)','IRN','IR'],
		103 => ['IRAQ','IRQ','IQ'],
		104 => ['IRELAND','IRL','IE'],
		105 => ['ISRAEL','ISR','IL'],
		106 => ['ITALY','ITA','IT'],
		107 => ['JAMAICA','JAM','JM'],
		108 => ['JAPAN','JPN','JP'],
		109 => ['JORDAN','JOR','JO'],
		110 => ['KAZAKHSTAN','KAZ','KZ'],
		111 => ['KENYA','KEN','KE'],
		112 => ['KIRIBATI','KIR','KI'],
		113 => ['KOREA, DEMOCRATIC PEOPLE\'S REPUBLIC OF','PRK','KP'],
		114 => ['KOREA, REPUBLIC OF','KOR','KR'],
		115 => ['KUWAIT','KWT','KW'],
		116 => ['KYRGYZSTAN','KGZ','KG'],
		117 => ['LAO PEOPLE\'S DEMOCRATIC REPUBLIC','LAO','LA'],
		118 => ['LATVIA','LVA','LV'],
		119 => ['LEBANON','LBN','LB'],
		120 => ['LESOTHO','LSO','LS'],
		121 => ['LIBERIA','LBR','LR'],
		122 => ['LIBYAN ARAB JAMAHIRIYA','LBY','LY'],
		123 => ['LIECHTENSTEIN','LIE','LI'],
		124 => ['LITHUANIA','LTU','LT'],
		125 => ['LUXEMBOURG','LUX','LU'],
		126 => ['MACAU','MAC','MO'],
		127 => ['MACEDONIA, THE FORMER YUGOSLAV REPUBLIC OF','MKD','MK'],
		128 => ['MADAGASCAR','MDG','MG'],
		129 => ['MALAWI','MWI','MW'],
		130 => ['MALAYSIA','MYS','MY'],
		131 => ['MALDIVES','MDV','MV'],
		132 => ['MALI','MLI','ML'],
		133 => ['MALTA','MLT','MT'],
		134 => ['MARSHALL ISLANDS','MHL','MH'],
		135 => ['MARTINIQUE','MTQ','MQ'],
		136 => ['MAURITANIA','MRT','MR'],
		137 => ['MAURITIUS','MUS','MU'],
		138 => ['MAYOTTE','MYT','YT'],
		139 => ['MEXICO','MEX','MX'],
		140 => ['MICRONESIA, FEDERATED STATES OF','FSM','FM'],
		141 => ['MOLDOVA','REPUBLIC OF','MDA','MD'],
		142 => ['MONACO','MCO','MC'],
		143 => ['MONGOLIA','MNG','MN'],
		243 => ['MONTENEGRO','MNE','ME'],
		144 => ['MONTSERRAT','MSR','MS'],
		145 => ['MOROCCO','MAR','MA'],
		146 => ['MOZAMBIQUE','MOZ','MZ'],
		147 => ['MYANMAR','MMR','MM'],
		148 => ['NAMIBIA','NAM','NA'],
		149 => ['NAURU','NRU','NR'],
		150 => ['NEPAL','NPL','NP'],
		151 => ['NETHERLANDS','NLD','NL'],
		152 => ['NETHERLANDS ANTILLES','ANT','AN'],
		153 => ['NEW CALEDONIA','NCL','NC'],
		154 => ['NEW ZEALAND','NZL','NZ'],
		155 => ['NICARAGUA','NIC','NI'],
		156 => ['NIGER','NER','NE'],
		157 => ['NIGERIA','NGA','NG'],
		158 => ['NIUE','NIU','NU'],
		159 => ['NORFOLK ISLAND','NFK','NF'],
		160 => ['NORTHERN MARIANA ISLANDS','MNP','MP'],
		161 => ['NORWAY','NOR','NO'],
		162 => ['OMAN','OMN','OM'],
		163 => ['PAKISTAN','PAK','PK'],
		164 => ['PALAU','PLW','PW'],
		165 => ['PALESTINIAN TERRITORY, Occupied','PSE','PS'],
		166 => ['PANAMA','PAN','PA'],
		167 => ['PAPUA NEW GUINEA','PNG','PG'],
		168 => ['PARAGUAY','PRY','PY'],
		169 => ['PERU','PER','PE'],
		170 => ['PHILIPPINES','PHL','PH'],
		171 => ['PITCAIRN','PCN','PN'],
		172 => ['POLAND','POL','PL'],
		173 => ['PORTUGAL','PRT','PT'],
		174 => ['PUERTO RICO','PRI','PR'],
		175 => ['QATAR','QAT','QA'],
		176 => ['REUNION','REU','RE'],
		177 => ['ROMANIA','ROU','RO'],
		178 => ['RUSSIAN FEDERATION','RUS','RU'],
		179 => ['RWANDA','RWA','RW'],
		180 => ['SAINT KITTS AND NEVIS','KNA','KN'],
		181 => ['SAINT LUCIA','LCA','LC'],
		182 => ['SAINT VINCENT AND THE GRENADINES','VCT','VC'],
		183 => ['SAMOA','WSM','WS'],
		184 => ['SAN MARINO','SMR','SM'],
		185 => ['SAO TOME AND PRINCIPE','STP','ST'],
		186 => ['SAUDI ARABIA','SAU','SA'],
		187 => ['SENEGAL','SEN','SN'],
		188 => ['SEYCHELLES','SYC','SC'],
		189 => ['SIERRA LEONE','SLE','SL'],
		190 => ['SINGAPORE','SGP','SG'],
		191 => ['SLOVAKIA (Slovak Republic)','SVK','SK'],
		192 => ['SLOVENIA','SVN','SI'],
		193 => ['SOLOMON ISLANDS','SLB','SB'],
		194 => ['SOMALIA','SOM','SO'],
		195 => ['SOUTH AFRICA','ZAF','ZA'],
		196 => ['SOUTH GEORGIA AND THE SOUTH SANDWICH ISLANDS','SGS','GS'],
		197 => ['SPAIN','ESP','ES'],
		198 => ['SRI LANKA','LKA','LK'],
		199 => ['SAINT HELENA','SHN','SH'],
		200 => ['SAINT PIERRE AND MIQUELON','SPM','PM'],
		242 => ['SERBIA','SRB','RS'],
		201 => ['SUDAN','SDN','SD'],
		202 => ['SURINAME','SUR','SR'],
		203 => ['SVALBARD AND JAN MAYEN ISLANDS','SJM','SJ'],
		204 => ['SWAZILAND','SWZ','SZ'],
		205 => ['SWEDEN','SWE','SE'],
		206 => ['SWITZERLAND','CHE','CH'],
		207 => ['SYRIAN ARAB REPUBLIC','SYR','SY'],
		241 => ['TAHITI','TAH','PF'],
		208 => ['TAIWAN','TWN','TW'],
		209 => ['TAJIKISTAN','TJK','TJ'],
		210 => ['TANZANIA, UNITED REPUBLIC OF','TZA','TZ'],
		211 => ['THAILAND','THA','TH'],
		212 => ['TOGO','TGO','TG'],
		213 => ['TOKELAU','TKL','TK'],
		214 => ['TONGA','TON','TO'],
		215 => ['TRINIDAD AND TOBAGO','TTO','TT'],
		216 => ['TUNISIA','TUN','TN'],
		217 => ['TURKEY','TUR','TR'],
		218 => ['TURKMENISTAN','TKM','TM'],
		219 => ['TURKS AND CAICOS ISLANDS','TCA','TC'],
		220 => ['TUVALU','TUV','TV'],
		221 => ['UGANDA','UGA','UG'],
		222 => ['UKRAINE','UKR','UA'],
		223 => ['UNITED ARAB EMIRATES','ARE','AE'],
		224 => ['UNITED KINGDOM','GBR','GB'],
		225 => ['UNITED STATES','USA','US'],
		226 => ['UNITED STATES MINOR OUTLYING ISLANDS','UMI','UM'],
		227 => ['URUGUAY','URY','UY'],
		228 => ['UZBEKISTAN','UZB','UZ'],
		229 => ['VANUATU','VUT','VU'],
		230 => ['VATICAN CITY STATE (HOLY SEE)','VAT','VA'],
		231 => ['VENEZUELA','VEN','VE'],
		232 => ['VIETNAM','VNM','VN'],
		233 => ['VIRGIN ISLANDS (BRITISH)','VGB','VG'],
		234 => ['VIRGIN ISLANDS (U.S.)','VIR','VI'],
		235 => ['WALLIS AND FUTUNA ISLANDS','WLF','WF'],
		236 => ['WESTERN SAHARA','ESH','EH'],
		237 => ['YEMEN','YEM','YE'],
		238 => ['YUGOSLAVIA','YUG','YU'],
		239 => ['ZAMBIA','ZMB','ZM'],
		240 => ['ZIMBABWE','ZWE','ZW'],
		244 => ['SCOTLAND','GBR','BG'],
		245 => ['WALES','GBR','BG'],
		246 => ['ENGLAND','GBR','BG'],
		247 => ['SOUTH SUDAN','SSN','SS'],
		300 => [' Do not wish to disclose','N/A','N/A'],

	);

	my %oceaniaCountries =(
		4 => 1,	
		13 => 1,
		51 => 1,
		72 => 1,
		77 => 1,	
		89 => 1,
		112 => 1,
		134 => 1,
		140 => 1,	
		149 => 1,
		153 => 1,
		154 => 1,
		158 => 1,	
		159 => 1,
		160 => 1,
		164 => 1,
		167 => 1,	
		183 => 1,
		193 => 1,
		213 => 1,
		214 => 1,	
		220 => 1,
		229 => 1,
		235 => 1,
	);		
		

sub getCountriesHash	{
    my ($Data) =@_;
	my %cnames=();
	for my $key (keys %countries)	{ $cnames{$key}=$countries{$key}[0]; }
    if(defined $Data and $Data->{'SystemConfig'}{'AllowNoCountrySelection'} ) {
        delete $cname->{$noCountryDisclosedID};        
    }
	return \%cnames;
}

sub getCountriesNameToData {
    my ($Data) =@_;
	my %cnames=();
	for my $key (keys %countries)	{ $cnames{uc($countries{$key}[0])}=[ $countries{$key}[1], $countries{$key}[2],$key]; }
    if( defined $Data and $Data->{'SystemConfig'}{'AllowNoCountrySelection'} ) {
        delete $cname->{$noCountryDisclosedID};
    }
	return \%cnames;
}


sub getCountriesArray	{
    my ($Data) =@_;
	my @countries=();
    my $force_select_country = 0;
    if(defined $Data and $Data->{'SystemConfig'}{'AllowNoCountrySelection'}) {
        $force_select_country = 1;
    }
	for my $key (sort { $countries{$a}[0] cmp $countries{$b}[0]} keys %countries)	{
        #if system config is set for AllowNoCountrySelection then we need to display option " Do not wish to enclose"
		push @countries, $countries{$key}[0] unless(!$force_select_country and $key == $noCountryDisclosedID );
	}
	return @countries;
}

sub getOceaniaCountriesHash {
	my %cnames=();
	for my $key (keys %countries)	{ 
			if (defined($oceaniaCountries{$key})) {
				$cnames{$key}=$countries{$key}[0]; 
			}
	}
	return \%cnames;
}

sub getOceaniaCountriesArray {
	my @countries=();
	for my $key (sort { $countries{$a}[0] cmp $countries{$b}[0]} keys %countries)	{
		if (defined($oceaniaCountries{$key})) {
			push @countries, $countries{$key}[0];
		}
	}
	return @countries;
}
