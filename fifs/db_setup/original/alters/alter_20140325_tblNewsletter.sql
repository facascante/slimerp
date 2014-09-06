alter table tblNewsletter
    add column intRealmID int(11) NOT NULL after intNewsletterID,
    add column intTalkToExactTarget tinyint(4) default 0;
