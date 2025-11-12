/**
 * Base class for trigger handlers
 * Provides a standard interface for trigger execution
 */
public virtual class TriggerHandler {

    // Static map to prevent recursive trigger calls
    private static Map<String, Boolean> bypassMap = new Map<String, Boolean>();

    // Instance properties
    protected String triggerName;

    /**
     * Constructor
     */
    public TriggerHandler() {
        this.triggerName = String.valueOf(this).substring(0, String.valueOf(this).indexOf(':'));
    }

    /**
     * Main execution method - called from trigger
     */
    public void execute() {
        // Check if this trigger is bypassed
        if (isBypassed()) {
            return;
        }

        // Execute before insert logic
        if (Trigger.isBefore && Trigger.isInsert) {
            beforeInsert();
        }

        // Execute before update logic
        else if (Trigger.isBefore && Trigger.isUpdate) {
            beforeUpdate();
        }

        // Execute before delete logic
        else if (Trigger.isBefore && Trigger.isDelete) {
            beforeDelete();
        }

        // Execute after insert logic
        else if (Trigger.isAfter && Trigger.isInsert) {
            afterInsert();
        }

        // Execute after update logic
        else if (Trigger.isAfter && Trigger.isUpdate) {
            afterUpdate();
        }

        // Execute after delete logic
        else if (Trigger.isAfter && Trigger.isDelete) {
            afterDelete();
        }

        // Execute after undelete logic
        else if (Trigger.isAfter && Trigger.isUndelete) {
            afterUndelete();
        }
    }

    /**
     * Virtual methods to be overridden in child classes
     */
    protected virtual void beforeInsert() {}
    protected virtual void beforeUpdate() {}
    protected virtual void beforeDelete() {}
    protected virtual void afterInsert() {}
    protected virtual void afterUpdate() {}
    protected virtual void afterDelete() {}
    protected virtual void afterUndelete() {}

    /**
     * Check if this trigger handler is bypassed
     */
    public Boolean isBypassed() {
        return bypassMap.containsKey(triggerName) && bypassMap.get(triggerName);
    }

    /**
     * Bypass this trigger handler
     */
    public static void bypass(String handlerName) {
        bypassMap.put(handlerName, true);
    }

    /**
     * Clear bypass for this trigger handler
     */
    public static void clearBypass(String handlerName) {
        bypassMap.put(handlerName, false);
    }

    /**
     * Check if a specific handler is bypassed
     */
    public static Boolean isBypassed(String handlerName) {
        return bypassMap.containsKey(handlerName) && bypassMap.get(handlerName);
    }
}