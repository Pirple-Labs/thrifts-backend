# Simple script to move old documentation files to backup

$backupDir = "docs_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

$oldFiles = @(
    "ai_team_implementation_plan.md",
    "ai_team_issue_report.md",
    "ai_team_response_requirements.md",
    "API_EXAMPLES_AND_OUTPUTS.md",
    "audit_implementation_review.md",
    "backup_restore_runbook.md",
    "BUSINESS_SUMMARY.md",
    "closure_go_live_plan.md",
    "COORDINATION_SYSTEM_DOCUMENTATION.md",
    "database_schema_reference.md",
    "enhanced_product_form_structure.md",
    "enhanced_product_form_summary.md",
    "FRONTEND_API_INTEGRATION.md",
    "FRONTEND_BUG_FIXES.md",
    "FRONTEND_DYNAMIC_PRODUCT_DELIVERY.md",
    "frontend_engineer_requirements.md",
    "frontend_integration_example.md",
    "FRONTEND_INTEGRATION_GUIDE.md",
    "FRONTEND_QUICK_REFERENCE.md",
    "FRONTEND_SEARCH_INTEGRATION.md",
    "IMMEDIATE_BUG_FIX.md",
    "implementation_checklist.md",
    "intelligent_shopping_assistant_implementation.md",
    "jwt_authentication_plan.md",
    "personalization_api_reference.md",
    "personalized_feeds_demo_guide.md",
    "plan_dsl_implementation_guide.md",
    "plan_dsl_implementation_summary.md",
    "production_deployment_checklist.md",
    "production_runbook.md",
    "rails_operator_communications.md",
    "rails_operator_implementation_summary.md",
    "RAILS_TROUBLESHOOTING_GUIDE.md",
    "REDUX_COORDINATION_FIX.md",
    "SEARCH_QUICK_REFERENCE.md",
    "SEARCH_SYSTEM_INTEGRATION.md",
    "security_configuration.md",
    "testing_guide.md"
)

$movedCount = 0
foreach ($file in $oldFiles) {
    if (Test-Path $file) {
        Move-Item $file $backupDir
        Write-Host "Moved: $file"
        $movedCount++
    }
}

Write-Host "Moved $movedCount files to $backupDir"
