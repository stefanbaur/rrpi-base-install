#!/bin/bash -e

SELECTEDBRANCH=$(git branch | grep '^\*' | tr -d ' *')

if [ "$SELECTEDBRANCH" != "main" ] ; then
	echo "This script should only be run from the main branch."
	echo "Try 'git checkout main'."
	echo "Exiting."
	exit 1
fi

# push local main branch to remote 
git push

# now take care of the others
FULLBRANCHLIST=$(git branch -a | tr -d ' *' | grep -v '^main$' | grep -v '/main$')
LOCALBRANCHLIST=$(echo "$FULLBRANCHLIST" | grep -v '^remotes/origin/' | sort )
REMOTEBRANCHLIST=$(echo "$FULLBRANCHLIST" | grep '^remotes/origin/' | awk -F '/' '{ print $3 }')

for BRANCH in $LOCALBRANCHLIST ; do
	git checkout "$BRANCH"
	git merge main -m "pull updates from main via merge"
	if echo "$REMOTEBRANCHLIST" | grep -q "^${BRANCH}$"; then
		git push
	fi
done
git checkout main
