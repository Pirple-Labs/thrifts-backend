# PowerShell script to clean up old scattered documentation files
# Keep only the consolidated documentation

Write-Host "🧹 Cleaning up old documentation files..." -ForegroundColor Yellow

# Files to KEEP (consolidated documentation)
$keepFiles = @(
    "README.md",
    "PROJECT_OVERVIEW.md", 
    "GETTING_STARTED.md",
    "ARCHITECTURE.md",
    "API_REFERENCE.md",
    "DEVELOPMENT_SETUP.md",
    "TECHNICAL_IMPLEMENTATION_SUMMARY.md",
    "FEATURES_IMPLEMENTED.md",
    "TECHNOLOGY_STACK.md",
    "FRONTEND_INTEGRATION_COMPLETE.md",
    "AI_ML_PERSONALIZATION_COMPLETE.md",
    "OPERATIONS_DEPLOYMENT_COMPLETE.md"
)

# Files to REMOVE (old scattered documentation)
$removeFiles = @(
    "ai_team_implementation_guide.md",
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

# Create backup directory
$backupDir = "docs_backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Path $backupDir -Force | Out-Null

Write-Host "📁 Created backup directory: $backupDir" -ForegroundColor Green

# Move files to backup before removing
$movedCount = 0
foreach ($file in $removeFiles) {
    if (Test-Path "docs/$file") {
        Move-Item "docs/$file" "$backupDir/$file"
        Write-Host "📦 Backed up: $file" -ForegroundColor Cyan
        $movedCount++
    }
}

# Count remaining files
$remainingFiles = Get-ChildItem docs/ -Name
$remainingCount = $remainingFiles.Count

Write-Host "✅ Cleanup complete!" -ForegroundColor Green
Write-Host "📊 Files remaining: $remainingCount" -ForegroundColor Blue
Write-Host "📦 Files backed up: $movedCount" -ForegroundColor Blue
Write-Host "🗂️ Backup location: $backupDir" -ForegroundColor Yellow

Write-Host "`n📚 Remaining documentation files:" -ForegroundColor Magenta
foreach ($file in $remainingFiles) {
    Write-Host "  - $file" -ForegroundColor White
}

Write-Host "`n🎉 Documentation consolidation complete!" -ForegroundColor Green
Write-Host "📖 All information has been consolidated into comprehensive guides:" -ForegroundColor Cyan
Write-Host "  - FRONTEND_INTEGRATION_COMPLETE.md" -ForegroundColor White
Write-Host "  - AI_ML_PERSONALIZATION_COMPLETE.md" -ForegroundColor White
Write-Host "  - OPERATIONS_DEPLOYMENT_COMPLETE.md" -ForegroundColor White
Write-Host "  - README.md (master index)" -ForegroundColor White