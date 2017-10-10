@echo off
call coffee -cb .

git add . -A
git add . -u

call npm run precompile
call npm version %1 --force
call npm run oncompile
call npm publish

git push