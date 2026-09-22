
============================================================================================================================

The default directory for keeping the inventory checks eg 

    AWS Resource Explorer

        1. SH
            ./aws-inventory-check.sh > path/to/reports_and_outputs/status-before-apply-$(date +%d%m%Y%H%M).txt
            ./aws-inventory-check.sh > path/to/reports_and_outputs/status-after-apply-$(date +%d%m%Y%H%M).txt

            ./aws-inventory-check.sh > path/to/reports_and_outputs/status-before-destroy-$(date +%d%m%Y%H%M).txt
            ./aws-inventory-check.sh > path/to/reports_and_outputs/status-after-destroy-$(date +%d%m%Y%H%M).txt

        2. PY

            python3 -m venv .venv
            source .venv/bin/activate
            python -m pip install -r aws-provisions/scripts/requirements.txt    
            
            python3 ./aws-inventory-check.sh > path/to/reports_and_outputs/status-current-py-$(date +%d%m%Y%H%M).txt
            python3 ./aws-inventory-check.sh > path/to/reports_and_outputs/status-after-destroy-py-$(date +%d%m%Y%H%M).txt

=============================================================================================================================

Gitleaks

        # Verify installed Gitleaks version
        gitleaks version

        # Directly scan a file or directory for secrets
        gitleaks dir <file path> --redact

        # Generate a detailed JSON report without exposing the secret
        gitleaks dir <file path> --redact --report-format json --report-path /path/to/reports_and_outputs/gitleaks_local_report_$(date +%d%m%Y%H%M).json

        # Force-stage the ignored test fixture for the controlled test
        git add -f <file path>

        # Verify the local pre-commit Gitleaks hook blocks the secret
        git commit -m "test: verify local secret detection"

        # Deliberately bypass local hooks so CI can detect the secret
        git commit --no-verify -m "test: verify CI secret detection"

        # Push the disposable test commit so CI can detect the secret
        git push

        # Remove the test fixture from Git tracking while keeping it locally
        git rm --cached <file path>

        # Commit the removal from Git tracking
        git commit -m "test: remove intentional secret from tracking"

        # Verify Gitleaks detects secrets that remain in Git history
        gitleaks git --redact -v

        # Identify the bad disposable test commit
        git log --oneline -5

        # Rewrite history starting immediately before the bad commit
        git rebase -i <commit-before-bad-commit>

        # Change the bad commit from pick to drop in the interactive rebase
        drop <bad-commit>

        # Skip an empty cleanup commit if the dropped commit already removed its changes
        git rebase --skip

        # Verify the bad commit is no longer on the branch
        git log --oneline -5

        # Verify the test file/commit is no longer reachable in Git history
        git log --oneline --all -- <file path>

        # Update the remote disposable branch with the rewritten history
        git push --force-with-lease origin <branch-name>

=============================================================================================================================

Semgrep

        # Verify installed Semgrep version
        semgrep --version

        # Directly scan an intentionally vulnerable file
        semgrep scan --config p/default <file path> --error

        # Generate a detailed JSON report without modifying the source file
        semgrep scan --config p/default <file path> --json --output /path/to/reports_and_outputs/semgrep_local_report_$(date +%d%m%Y%H%M).json

        # Force-stage the ignored vulnerable test fixture for the controlled test
        git add -f <file path>

        # Verify the local pre-commit Semgrep hook blocks the vulnerable file
        git commit -m "test: verify local semgrep detection"

        # Deliberately bypass local hooks so CI can detect the vulnerability
        git commit --no-verify -m "test: verify CI semgrep detection"

        # Push the disposable test commit so CI can detect the vulnerability
        git push

        # Remove the test fixture from Git tracking while keeping it locally
        git rm --cached <file path>

        # Commit the removal from Git tracking
        git commit -m "test: remove intentional semgrep test fixture from tracking"

        # Verify Semgrep scans all Git-tracked files even when Git ignores them
        git ls-files -z | xargs -0 semgrep scan --config p/default --no-git-ignore --error

        # Identify the bad disposable test commit
        git log --oneline -5

        # Rewrite history starting immediately before the bad commit
        git rebase -i <commit-before-bad-commit>

        # Change the bad commit from pick to drop in the interactive rebase
        drop <bad-commit>

        # Skip an empty cleanup commit if the dropped commit already removed its changes
        git rebase --skip

        # Verify the bad commit is no longer on the branch
        git log --oneline -5

        # Verify the test file/commit is no longer reachable in Git history
        git log --oneline --all -- <file path>

        # Update the remote disposable branch with the rewritten history
        git push --force-with-lease origin <branch-name>


=============================================================================================================================

    Remove bad commit from Github

    a. If the commit introduced a file

        git rm --cached aws-provisions/test-files/vpc-lab/sast-ci-test.tf

        update the git ignore

    b. To completely remove a bad commit from history

        git log --oneline -5
                ↓
        identify bad commit
                ↓
        git rebase -i <commit-before-bad-commit>
                ↓
        drop bad commit
                ↓
        git log --oneline -5
                ↓
        verify
                ↓
        git push --force-with-lease origin feature/sast