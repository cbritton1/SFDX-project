/**
 * Trigger handler for Rate_Template_Tier__c object
 * Extends TriggerHandler base class
 * Handles automatic regeneration of User Rate Tiers when template tiers change
 */
public without sharing class RateTemplateTierTriggerHandler extends TriggerHandler {

    /**
     * After Insert logic
     * Regenerate User Rate Tiers for all users assigned to this template
     */
    protected override void afterInsert() {
        Set<Id> templateIds = getAffectedTemplateIds(Trigger.new);
        regenerateUserRateTiersForTemplates(templateIds);
    }

    /**
     * After Update logic
     * Regenerate User Rate Tiers when tier values change
     */
    protected override void afterUpdate() {
        Set<Id> templateIds = new Set<Id>();

        for (Rate_Template_Tier__c newTier : (List<Rate_Template_Tier__c>) Trigger.new) {
            Rate_Template_Tier__c oldTier = (Rate_Template_Tier__c) Trigger.oldMap.get(newTier.Id);

            // Check if any relevant fields changed
            if (hasRelevantFieldChanges(newTier, oldTier)) {
                templateIds.add(newTier.Rate_Template__c);
            }
        }

        if (!templateIds.isEmpty()) {
            regenerateUserRateTiersForTemplates(templateIds);
        }
    }

    /**
     * After Delete logic
     * Regenerate User Rate Tiers when tiers are deleted
     */
    protected override void afterDelete() {
        Set<Id> templateIds = getAffectedTemplateIds(Trigger.old);
        regenerateUserRateTiersForTemplates(templateIds);
    }

    /**
     * Get template IDs from trigger records
     */
    private Set<Id> getAffectedTemplateIds(List<Rate_Template_Tier__c> tiers) {
        Set<Id> templateIds = new Set<Id>();
        for (Rate_Template_Tier__c tier : tiers) {
            if (tier.Rate_Template__c != null) {
                templateIds.add(tier.Rate_Template__c);
            }
        }
        return templateIds;
    }

    /**
     * Check if relevant fields changed
     */
    private Boolean hasRelevantFieldChanges(Rate_Template_Tier__c newTier, Rate_Template_Tier__c oldTier) {
        return newTier.Tier_Number__c != oldTier.Tier_Number__c
            || newTier.Threshold_Min__c != oldTier.Threshold_Min__c
            || newTier.Threshold_Max__c != oldTier.Threshold_Max__c
            || newTier.Recurring_Rate__c != oldTier.Recurring_Rate__c
            || newTier.Non_Recurring_Rate__c != oldTier.Non_Recurring_Rate__c;
    }

    /**
     * Regenerate User Rate Tiers for all users assigned to the given templates
     */
    private void regenerateUserRateTiersForTemplates(Set<Id> templateIds) {
        if (templateIds.isEmpty()) {
            return;
        }

        // Find all active Rate Template Assignments for these templates
        List<Rate_Template_Assignment__c> assignments = [
            SELECT Id, User__c, Rate_Template__c, Fiscal_Year__c, Active__c
            FROM Rate_Template_Assignment__c
            WHERE Rate_Template__c IN :templateIds
            AND Active__c = true
        ];

        if (assignments.isEmpty()) {
            System.debug('No active assignments found for templates: ' + templateIds);
            return;
        }

        // Group assignments by user and template
        Map<Id, Id> userToTemplateMap = new Map<Id, Id>();
        Map<Id, String> userToFiscalYearMap = new Map<Id, String>();

        for (Rate_Template_Assignment__c assignment : assignments) {
            userToTemplateMap.put(assignment.User__c, assignment.Rate_Template__c);
            userToFiscalYearMap.put(assignment.User__c, assignment.Fiscal_Year__c);
        }

        // Regenerate tiers for each user
        for (Id userId : userToTemplateMap.keySet()) {
            Id templateId = userToTemplateMap.get(userId);
            String fiscalYear = userToFiscalYearMap.get(userId);

            // Delete existing tiers for this user/fiscal year
            UserRateTemplateService.deleteExistingTiers(userId, fiscalYear);

            // Generate new tiers
            UserRateTemplateService.generateUserRateTiers(userId, templateId);
        }

        System.debug('Regenerated User Rate Tiers for ' + userToTemplateMap.size() + ' users');
    }
}
