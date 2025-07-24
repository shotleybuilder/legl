# Refactor Git Workflow


### Switch to main branch
`git checkout main`

### Pull latest changes from main branch
git pull origin main

### Create a new branch for refactoring
git checkout -b refactor/[description]

### Switch back to main branch
git checkout main

### Merge changes from refactoring branch
git merge refactor/[description]

### Push merged changes to remote repository
git push origin main

### Delete refactoring branch
git branch -d refactor/[description]

### Push branch deletion to remote repository
git push origin --delete refactor/[description]

### List local branches
git branch

### Push your refactoring branch to GitHub
git push origin refactor/cleanup-architecture

### If it's the first time pushing this branch, Git might suggest:
git push --set-upstream origin refactor/cleanup-architecture
