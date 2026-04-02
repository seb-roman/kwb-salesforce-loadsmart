# CI/CD Pipeline Setup — GitHub Actions

**Status:** Ready to configure  
**Platform:** GitHub Actions  
**Automated:** Test on push, deploy sandbox on pass, production with manual approval

---

## Overview

This GitHub Actions pipeline automates:

1. **On every push to `master`:**
   - Run all 122+ Apex tests
   - Check code coverage (>80% required)
   - Scan for hardcoded credentials
   - If all pass → auto-deploy to sandbox
   - If all pass → run sandbox smoke tests
   - Notify "Ready for Production"

2. **Production deployment (requires manual approval):**
   - Deploy to production
   - Run health checks
   - If health checks fail → auto-rollback
   - Notify production status

---

## Configuration (3 Steps)

### Step 1: Create GitHub Secrets

In your repository settings (GitHub → Settings → Secrets and Variables → Actions), add:

**For Sandbox:**
```
SFDX_AUTH_URL_SANDBOX
```
Value: Salesforce DX auth URL for sandbox org
- Generate: `sfdx force:org:display -u kwb-sandbox --json`
- Copy the `sfdxAuthUrl` value

**For Production:**
```
SFDX_AUTH_URL_PRODUCTION
```
Value: Salesforce DX auth URL for production org
- Generate: `sfdx force:org:display -u kwb-prod --json`
- Copy the `sfdxAuthUrl` value

### Step 2: Create Workflow File

The workflow file is already created at `.github/workflows/deploy.yml`

### Step 3: Enable Environments (Optional but Recommended)

Create a "production" environment for manual approval gate:

1. GitHub → Settings → Environments
2. Click "New environment"
3. Name: `production`
4. Add deployment branch rules:
   - Include: `master`
5. Add required reviewers (optional):
   - Add Seb Roman or Joshua Anderson as required reviewers
   - This requires approval before production deploy

---

## How It Works

### On Push to Master

```
Developer pushes code to master
    ↓
GitHub Actions triggers
    ↓
Test Job: Run 122+ tests
    ↓ (if pass)
Credentials Job: Scan for hardcoded secrets
    ↓ (if pass)
Sandbox Deploy Job: Auto-deploy to sandbox
    ↓ (if pass)
Notify Team: "Ready for Production"
    ↓
Manual Approval (if deploying to production)
    ↓
Production Deploy Job
    ↓ (if health checks pass)
Notify Team: "Production deployment complete"
    ↓ (if health checks fail)
Auto-Rollback: Revert previous version
```

### On Production Approval

```
Approver clicks "Approve" in GitHub UI
    ↓
Production Deploy Job starts
    ↓
Deploy to production
    ↓
Run health checks (polling, API, logs)
    ↓ (if pass)
Mark deployment complete
    ↓ (if fail)
Trigger rollback
```

---

## Manual Trigger (If Needed)

If you need to manually deploy without pushing code:

1. Go to GitHub → Actions
2. Select "Test & Deploy" workflow
3. Click "Run workflow"
4. Select branch: `master`
5. Click "Run workflow"

The pipeline will execute from step 1.

---

## Viewing Logs

### Real-Time During Execution

1. GitHub → Actions
2. Click the most recent run
3. Click the job you want to view
4. Scroll through logs in real-time

### After Completion

1. GitHub → Actions
2. Click the completed run
3. View job summaries + logs
4. Download logs as artifact (optional)

### Debugging Failed Runs

If a run fails:

1. Check the specific job that failed
2. Scroll to the failed step
3. Look for error messages
4. Common issues:
   - Test coverage <80%: Fix code, push again
   - Hardcoded credentials: Remove, push again
   - Sandbox deploy failed: Check Salesforce logs
   - Prod deploy failed: Review health checks

---

## Test Results Interpretation

### All Green ✅

```
✓ 122 tests passed
✓ Code coverage: 85%
✓ No hardcoded credentials
✓ Sandbox deployment successful
✓ Ready for production
```

Next: Approve production deployment (if desired)

### Test Failures ❌

```
✗ 3 tests failed
  - ShipperLoadListControllerTest::testRLSEnforcement
  - ExceptionDetectionEngineTest::testDuplicateDedup
  - etc.

→ Action: Fix tests locally, push corrected code
```

### Coverage Below 80% ⚠️

```
✗ Code coverage: 78%
→ Action: Add more test cases, push updated tests
```

### Credentials Found ❌

```
✗ Hardcoded credentials detected
  - Found: "api_key" in SettlementBatch.cls
→ Action: Move to custom settings, push updated code
```

---

## Production Approval Flow

### When Sandbox Tests Pass

GitHub will show:

```
Deployment Status: Ready for Production

This run requires approval to proceed.

[Approve] [Deny]
```

**Approvers:** (configured in environment settings)

Click "Approve" to proceed with production deployment.

### What Happens After Approval

```
Deployment to production starts
  ↓
Deploy metadata + code
  ↓
Run health checks:
  - Polling active?
  - API endpoints responding?
  - No errors in logs?
  ↓ (if pass)
Deployment complete ✅
  ↓ (if fail)
Auto-rollback to previous version
```

---

## Health Checks (Post-Deploy)

The `HealthCheckTest` (optional) validates:

```apex
✓ Motive webhook endpoint is reachable
✓ LoadsmartPoller can authenticate
✓ Loadsmart API is responding
✓ Salesforce APIs are working
✓ No critical errors in logs
```

If any health check fails, deployment is marked as failed and rollback is triggered.

---

## Rollback Procedure

If production deployment fails:

**Automatic (via GitHub):**
1. Previous commit is re-deployed
2. Tests run on rollback version
3. If tests pass, rollback is complete
4. Team is notified

**Manual Rollback:**

```bash
# If automatic rollback fails, do this manually:
sfdx force:source:deploy -u kwb-prod \
  -d force-app/main/default \
  --metadata LoadsmartPoller,SamsaraWebhookReceiver \
  --wait 30

# Restore from backup (if needed)
# Contact Salesforce support for org backup restore
```

---

## Monitoring & Alerts

### GitHub Notifications

You receive notifications for:
- ✅ Deployment successful
- ❌ Deployment failed
- ⚠️ Requires approval

Configure in GitHub → Settings → Notifications

### Slack Integration (Optional)

To send notifications to Slack:

1. Create a Slack webhook: https://api.slack.com/messaging/webhooks
2. Add secret: `SLACK_WEBHOOK_URL`
3. Add step to workflow:

```yaml
- name: Notify Slack
  if: always()
  run: |
    curl -X POST ${{ secrets.SLACK_WEBHOOK_URL }} \
      -d '{"text":"Deployment complete: ${{ job.status }}"}'
```

---

## Best Practices

### For Developers

1. **Run tests locally before pushing:**
   ```bash
   sfdx force:apex:test:run -u kwb-sandbox -l RunAllTests
   ```

2. **Check code coverage locally:**
   ```bash
   sfdx force:apex:test:report -u kwb-sandbox -c
   ```

3. **Never hardcode credentials** — use custom settings or environment variables

4. **Write tests as you code** — aim for >80% coverage from the start

### For Deployment

1. **Always review sandbox test results before approving production**

2. **Check GitHub Actions logs for any warnings**

3. **Monitor production for 1 hour after deployment**

4. **Have rollback plan ready** (contact Seb or Salesforce support)

### For CI/CD Maintenance

1. **Review workflow quarterly** — update SFDX CLI versions, Node versions
2. **Update secrets annually** — rotate Salesforce auth URLs
3. **Monitor cost** — GitHub Actions is free for public repos, paid for private
4. **Keep documentation current** — update this guide when workflow changes

---

## Troubleshooting

### "SFDX_AUTH_URL not found"

**Issue:** Secret not configured in GitHub

**Fix:** 
1. Go to Secrets in GitHub settings
2. Add `SFDX_AUTH_URL_SANDBOX` and `SFDX_AUTH_URL_PRODUCTION`
3. Re-run workflow

### "Test coverage below 80%"

**Issue:** New code doesn't have enough tests

**Fix:**
1. Add unit tests locally
2. Ensure coverage >80%
3. Push updated code

### "Deployment to sandbox failed"

**Issue:** Metadata deployment error in Salesforce

**Fix:**
1. Check Salesforce logs in GitHub Actions
2. Fix the error locally
3. Push corrected code

### "Production deployment auto-rolled back"

**Issue:** Health checks failed in production

**Fix:**
1. Review health check logs
2. Determine root cause
3. Fix the issue
4. Manually re-deploy after fix

---

## Cost

**GitHub Actions Pricing:**
- Free for public repositories (unlimited)
- Paid for private repositories ($0.008 per minute)
- Estimate: ~$10-20/month for typical usage (10-20 deployments/month × 5 min each)

---

## Support

For CI/CD issues:
- **GitHub Actions Docs:** https://docs.github.com/en/actions
- **Salesforce CLI Docs:** https://developer.salesforce.com/docs/atlas.en-us.sfdx_setup.meta/sfdx_setup/
- **Seb Roman:** seb.roman316@gmail.com (architecture + workflow help)

---

**Workflow Status:** ✅ Ready to configure  
**Next:** Add GitHub secrets, push code, watch first run
