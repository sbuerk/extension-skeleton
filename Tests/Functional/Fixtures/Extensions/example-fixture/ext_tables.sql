#
# Table structure for table 'tx_examplefixture_domain_model_greeting'
#
# Only the own fields are declared. TYPO3 derives everything the TCA implies —
# "uid", "pid", "deleted", the language fields and the "t3ver_*" workspace
# fields — from the TCA of the table, see
# \TYPO3\CMS\Core\Database\Schema\DefaultTcaSchema.
#
CREATE TABLE tx_examplefixture_domain_model_greeting (
    title varchar(255) DEFAULT '' NOT NULL,
    message text
);
