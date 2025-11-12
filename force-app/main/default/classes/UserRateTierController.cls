/**
 * Controller for User Rate Tier Lightning Web Component
 * Provides data for displaying user rate tiers
 */
public with sharing class UserRateTierController {

    /**
     * Get all User Rate Tiers for a specific user
     * @param userId The User Id
     * @return List of User Rate Tiers ordered by Tier Number
     */
    @AuraEnabled(cacheable=true)
    public static List<User_Rate_Tier__c> getUserRateTiers(Id userId) {
        try {
            return [
                SELECT Id,
                       Tier_Number__c,
                       Threshold_Min__c,
                       Threshold_Max__c,
                       Recurring_Rate__c,
                       Non_Recurring_Rate__c,
                       Recurring_Rate_Diff_From_Previous__c,
                       Non_Recurring_Rate_Diff_From_Previous__c,
                       Fiscal_Year__c,
                       Source_Template__c,
                       Source_Template__r.Name,
                       User__c,
                       User__r.Name
                FROM User_Rate_Tier__c
                WHERE User__c = :userId
                ORDER BY Fiscal_Year__c DESC, Tier_Number__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user rate tiers: ' + e.getMessage());
        }
    }

    /**
     * Get User Rate Tiers grouped by Fiscal Year
     * @param userId The User Id
     * @return Map of Fiscal Year to List of Tiers
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserRateTiersByFiscalYear(Id userId) {
        try {
            List<User_Rate_Tier__c> tiers = getUserRateTiers(userId);

            Map<String, List<User_Rate_Tier__c>> tiersByYear = new Map<String, List<User_Rate_Tier__c>>();

            for (User_Rate_Tier__c tier : tiers) {
                String fiscalYear = tier.Fiscal_Year__c != null ? tier.Fiscal_Year__c : 'Unknown';
                if (!tiersByYear.containsKey(fiscalYear)) {
                    tiersByYear.put(fiscalYear, new List<User_Rate_Tier__c>());
                }
                tiersByYear.get(fiscalYear).add(tier);
            }

            return new Map<String, Object>{
                'tiersByYear' => tiersByYear,
                'fiscalYears' => new List<String>(tiersByYear.keySet())
            };
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user rate tiers by fiscal year: ' + e.getMessage());
        }
    }

    /**
     * Get summary information for a user's rate tiers
     * @param userId The User Id
     * @return Summary information
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getUserRateTierSummary(Id userId) {
        try {
            List<User_Rate_Tier__c> tiers = getUserRateTiers(userId);

            Integer tierCount = tiers.size();
            Decimal highestRecurringRate = 0;
            Decimal highestNonRecurringRate = 0;
            String sourceTemplateName = '';
            String fiscalYear = '';

            for (User_Rate_Tier__c tier : tiers) {
                if (tier.Recurring_Rate__c > highestRecurringRate) {
                    highestRecurringRate = tier.Recurring_Rate__c;
                }
                if (tier.Non_Recurring_Rate__c > highestNonRecurringRate) {
                    highestNonRecurringRate = tier.Non_Recurring_Rate__c;
                }
                if (String.isBlank(sourceTemplateName) && tier.Source_Template__r != null) {
                    sourceTemplateName = tier.Source_Template__r.Name;
                }
                if (String.isBlank(fiscalYear)) {
                    fiscalYear = tier.Fiscal_Year__c;
                }
            }

            return new Map<String, Object>{
                'tierCount' => tierCount,
                'highestRecurringRate' => highestRecurringRate,
                'highestNonRecurringRate' => highestNonRecurringRate,
                'sourceTemplateName' => sourceTemplateName,
                'fiscalYear' => fiscalYear,
                'hasTiers' => tierCount > 0
            };
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user rate tier summary: ' + e.getMessage());
        }
    }
}