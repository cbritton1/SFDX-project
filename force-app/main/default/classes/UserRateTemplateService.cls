/**
 * Service class for managing User Rate Tiers based on Rate Template Assignments
 * Handles the creation and updates of User_Rate_Tier__c records when Rate_Template_Assignment__c changes
 */
public with sharing class UserRateTemplateService {

    /**
     * Process Rate Template Assignment changes
     * Called from RateTemplateAssignmentTriggerHandler after insert/update
     */
    public static void processAssignmentChanges(List<Rate_Template_Assignment__c> newAssignments, Map<Id, Rate_Template_Assignment__c> oldAssignmentMap) {
        List<Id> assignmentsToProcess = new List<Id>();
        Map<Id, Id> assignmentToTemplateMap = new Map<Id, Id>();
        Map<Id, Id> assignmentToUserMap = new Map<Id, Id>();

        for (Rate_Template_Assignment__c newAssignment : newAssignments) {
            Rate_Template_Assignment__c oldAssignment = oldAssignmentMap?.get(newAssignment.Id);

            // Process if new assignment OR template changed OR active status changed
            Boolean isInsert = (oldAssignment == null);
            Boolean templateChanged = !isInsert && (newAssignment.Rate_Template__c != oldAssignment.Rate_Template__c);
            Boolean activeStatusChanged = !isInsert && (newAssignment.Active__c != oldAssignment.Active__c);

            if (isInsert || templateChanged || activeStatusChanged) {
                assignmentsToProcess.add(newAssignment.Id);
                if (newAssignment.Active__c && newAssignment.Rate_Template__c != null && newAssignment.User__c != null) {
                    assignmentToTemplateMap.put(newAssignment.Id, newAssignment.Rate_Template__c);
                    assignmentToUserMap.put(newAssignment.Id, newAssignment.User__c);
                }
            }
        }

        if (assignmentsToProcess.isEmpty()) {
            return;
        }

        // Process each assignment
        for (Id assignmentId : assignmentsToProcess) {
            if (assignmentToTemplateMap.containsKey(assignmentId)) {
                Id userId = assignmentToUserMap.get(assignmentId);
                Id templateId = assignmentToTemplateMap.get(assignmentId);
                generateUserRateTiers(userId, templateId);
            } else {
                // Assignment is inactive or missing required fields - delete tiers
                Rate_Template_Assignment__c assignment = newAssignments[0];
                for (Rate_Template_Assignment__c a : newAssignments) {
                    if (a.Id == assignmentId) {
                        assignment = a;
                        break;
                    }
                }
                if (assignment.User__c != null) {
                    deleteUserRateTiersForAssignment(assignment.User__c, assignment.Fiscal_Year__c);
                }
            }
        }
    }

    /**
     * Generate User Rate Tiers from a Rate Template
     * Deletes existing tiers for the user/template fiscal year and creates new ones
     */
    public static void generateUserRateTiers(Id userId, Id templateId) {
        // Query the template with its tiers
        Rate_Template__c template = queryRateTemplate(templateId);

        if (template == null || template.Rate_Template_Tiers__r.isEmpty()) {
            return;
        }

        // Delete existing User Rate Tiers for this user/fiscal year
        deleteExistingTiers(userId, template.Fiscal_Year__c);

        // Create new User Rate Tiers from template
        List<User_Rate_Tier__c> userTiers = new List<User_Rate_Tier__c>();
        Decimal previousRecurringRate = 0;
        Decimal previousNonRecurringRate = 0;

        for (Rate_Template_Tier__c tier : template.Rate_Template_Tiers__r) {
            User_Rate_Tier__c userTier = new User_Rate_Tier__c(
                User__c = userId,
                Tier_Number__c = tier.Tier_Number__c,
                Threshold_Min__c = tier.Threshold_Min__c,
                Threshold_Max__c = tier.Threshold_Max__c,
                Recurring_Rate__c = tier.Recurring_Rate__c,
                Non_Recurring_Rate__c = tier.Non_Recurring_Rate__c,
                Fiscal_Year__c = template.Fiscal_Year__c,
                Source_Template__c = templateId,
                Unique_Key__c = generateUniqueKey(userId, tier.Tier_Number__c, template.Fiscal_Year__c)
            );

            // Calculate rate differences from previous tier
            userTier.Recurring_Rate_Diff_From_Previous__c = tier.Recurring_Rate__c - previousRecurringRate;
            userTier.Non_Recurring_Rate_Diff_From_Previous__c = tier.Non_Recurring_Rate__c - previousNonRecurringRate;

            previousRecurringRate = tier.Recurring_Rate__c;
            previousNonRecurringRate = tier.Non_Recurring_Rate__c;

            userTiers.add(userTier);
        }

        // Insert new tiers
        if (!userTiers.isEmpty()) {
            insert userTiers;
        }
    }

    /**
     * Delete all User Rate Tiers for a specific user
     */
    @TestVisible
    private static void deleteUserRateTiers(Id userId) {
        List<User_Rate_Tier__c> tiersToDelete = [
            SELECT Id
            FROM User_Rate_Tier__c
            WHERE User__c = :userId
        ];

        if (!tiersToDelete.isEmpty()) {
            delete tiersToDelete;
        }
    }

    /**
     * Delete User Rate Tiers for a user/fiscal year combination
     */
    @TestVisible
    private static void deleteUserRateTiersForAssignment(Id userId, String fiscalYear) {
        if (userId == null) {
            return;
        }

        List<User_Rate_Tier__c> tiersToDelete;
        if (String.isNotBlank(fiscalYear)) {
            tiersToDelete = [
                SELECT Id
                FROM User_Rate_Tier__c
                WHERE User__c = :userId
                AND Fiscal_Year__c = :fiscalYear
            ];
        } else {
            tiersToDelete = [
                SELECT Id
                FROM User_Rate_Tier__c
                WHERE User__c = :userId
            ];
        }

        if (!tiersToDelete.isEmpty()) {
            delete tiersToDelete;
        }
    }

    /**
     * Delete existing User Rate Tiers for a user/fiscal year combination
     */
    public static void deleteExistingTiers(Id userId, String fiscalYear) {
        List<User_Rate_Tier__c> tiersToDelete = [
            SELECT Id
            FROM User_Rate_Tier__c
            WHERE User__c = :userId
            AND Fiscal_Year__c = :fiscalYear
        ];

        if (!tiersToDelete.isEmpty()) {
            delete tiersToDelete;
        }
    }

    /**
     * Query Rate Template with tiers
     */
    @TestVisible
    private static Rate_Template__c queryRateTemplate(Id templateId) {
        List<Rate_Template__c> templates = [
            SELECT Id, Name, Fiscal_Year__c, Active__c,
                   (SELECT Id, Tier_Number__c, Threshold_Min__c, Threshold_Max__c,
                           Recurring_Rate__c, Non_Recurring_Rate__c
                    FROM Rate_Template_Tiers__r
                    ORDER BY Tier_Number__c ASC)
            FROM Rate_Template__c
            WHERE Id = :templateId
            AND Active__c = true
            LIMIT 1
        ];

        return templates.isEmpty() ? null : templates[0];
    }

    /**
     * Generate unique key for User Rate Tier
     * Format: userId_tierNumber_fiscalYear
     */
    @TestVisible
    private static String generateUniqueKey(Id userId, Decimal tierNumber, String fiscalYear) {
        return userId + '_' + String.valueOf(tierNumber.intValue()) + '_' + fiscalYear;
    }
}