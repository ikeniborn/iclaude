# Task: Test Retry Logic

## Description
Create a test script that will fail initially but succeed after retry.
This tests the exponential backoff retry mechanism.

The script should:
1. Check if a marker file exists
2. If not, create it and exit with error
3. If yes, create the output file and exit successfully

## Completion Promise
All tests passed

## Validation Command
bash test-retry-validation.sh

## Max Iterations
5

## Git Config
Branch: test/loop-retry
Commit message: test: verify retry logic with exponential backoff
Auto-push: false
