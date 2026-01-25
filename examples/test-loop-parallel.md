# Task: Test Parallel Task 1

## Description
First parallel task - create file parallel-task-1.txt

## Completion Promise
parallel-task-1.txt

## Validation Command
ls parallel-task-1.txt

## Max Iterations
3

## Parallel Group
Group: 1

## Git Config
Branch: test/parallel-1
Commit message: test: parallel task 1
Auto-push: false

---

# Task: Test Parallel Task 2

## Description
Second parallel task - create file parallel-task-2.txt

## Completion Promise
parallel-task-2.txt

## Validation Command
ls parallel-task-2.txt

## Max Iterations
3

## Parallel Group
Group: 1

## Git Config
Branch: test/parallel-2
Commit message: test: parallel task 2
Auto-push: false

---

# Task: Test Sequential Task

## Description
Sequential task after parallel - create file sequential-task.txt

## Completion Promise
sequential-task.txt

## Validation Command
ls sequential-task.txt

## Max Iterations
3

## Parallel Group
Group: 0

## Git Config
Branch: test/sequential
Commit message: test: sequential task after parallel
Auto-push: false
