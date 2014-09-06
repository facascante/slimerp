ALTER TABLE tblEntity
    ADD COLUMN strPaymentNotificationAddress VARCHAR(250),
    ADD COLUMN strEntityPaymentBusinessNumber VARCHAR(100) DEFAULT '',
    ADD COLUMN strEntityPaymentInfo TEXT;
