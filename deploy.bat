git add *
git commit -m "deploy"
git push

hexo g & hexo deploy

rem xcopy public webpage /s /e /y
rem cd webpage
rem git add *
rem git commit -m "deploy"
rem git push
rem cd ..
