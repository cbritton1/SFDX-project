/**
 * Trigger for Rate_Template_Tier__c object
 * Automatically regenerates User Rate Tiers when template tiers are modified
 */
trigger RateTemplateTierTrigger on Rate_Template_Tier__c (after insert, after update, after delete) {
    RateTemplateTierTriggerHandler handler = new RateTemplateTierTriggerHandler();
    handler.execute();
}