xcopy public webpage /s /e /y
cd webpage
git add *
git commit -m "deploy"
git push
cd ..